//
//  Node.m
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "Node.h"
#import "ZeroTierDataStore.h"
#import "VirtualNetworkConfig.h"
#import "NodeStatus.h"
#import "Peer.h"

#import <CocoaLumberjack/CocoaLumberjack.h>

#if DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#endif

long DataStoreGetFunction(ZT_Node *native_node, void *userData, void *threadPtr, const char* objectName,
                          void *buffer, unsigned long bufferLength, unsigned long startIndex,
                          unsigned long *outObjectSize)
{
    Node *node = (__bridge Node*)userData;
    ZeroTierDataStore *dataStore = [node dataStore];

    NSString *name = [NSString stringWithUTF8String:objectName];
    UInt64 totalSize = 0;
    NSData *data = [dataStore getObjectWithName:name atStartIndex:startIndex totalSize:&totalSize];

    long bytesRead = [data length];

    if(data != nil && totalSize > 0) {
        *outObjectSize = (unsigned long)totalSize;
        
        if (bufferLength < bytesRead) {
            bytesRead = bufferLength;
        }
        
        memcpy(buffer, &[data bytes][startIndex], bytesRead);
    }

    return bytesRead;
}

int DataStorePutFunction(ZT_Node *native_node, void *userData, void *threadPtr, const char *objectName,
                         const void* buffer, unsigned long bufferLength, int secure) {

    Node *node = (__bridge Node*)userData;
    ZeroTierDataStore *dataStore = [node dataStore];
    NSString *name = [NSString stringWithUTF8String:objectName];

    if(buffer == nil) {
        [dataStore deleteObjectWithName:name];
        return 0;
    }
    else {
        NSData *data = [NSData dataWithBytes:buffer length:bufferLength];
        return [dataStore putObjectWithName:name buffer:data secure:NO];
    }
}

int VirtualNetworkConfigFunction(ZT_Node *native_node, void *userData, void *threadPtr, UInt64 networkId,
                                 void **modifiableNetworkUserPtr,
                                 enum ZT_VirtualNetworkConfigOperation op,
                                 const ZT_VirtualNetworkConfig *config) {

    Node *node = (__bridge Node*)userData;
    VirtualNetworkConfig *cfg = [[VirtualNetworkConfig alloc] initWithNetworkConfig:*config];
    return [[node networkConfigHandler] onConfigChangedForNetwork:networkId
                                                        operation:op
                                                           config:cfg];
}

void VirtualNetworkFrameFunction(ZT_Node *native_node, void *userData, void *threadPtr, uint64_t networkId,
                                 void **modifiableNetworkUserPtr,
                                 UInt64 sourceMac, UInt64 destMac, unsigned int etherType,
                                 unsigned int vlanID, const void *frameData,
                                 unsigned int frameLength) {
    Node *node = (__bridge Node*)userData;
    NSData *data = [NSData dataWithBytes:frameData length:frameLength];
    [[node networkFrameHandler] onVirtualNetworkFrameFromNetwork:networkId sourceMac:sourceMac destMac:destMac etherType:etherType vlanId:vlanID data:data];
}

void EventCallback(ZT_Node *nativeNode, void* userData, void *threadPtr, enum ZT_Event event, const void *metadata) {

    Node *node = (__bridge Node*)userData;

    switch(event) {
        case ZT_EVENT_TRACE:
        {
            NSString *str = [NSString stringWithUTF8String:(const char*)metadata];
            [[node eventHandler] onTrace:str];
            break;
        }
        default:
            [[node eventHandler] onEvent:event];
            break;
    }
}

int WirePacketSendFunction(ZT_Node *native_node, void *userData, void *threadPtr,
                           const struct sockaddr_storage* localAddress,
                           const struct sockaddr_storage* remoteAddress,
                           const void *packetData, unsigned int packetLength,
                           unsigned int ttl) {

    if(remoteAddress == NULL || memcmp(remoteAddress, &ZT_SOCKADDR_NULL, sizeof(struct sockaddr_storage)) == 0) {
        DDLogError(@"Attempt to send to a null address");
        return 0;
    }

    Node *node = (__bridge Node*)userData;
    id<PacketSender> packetSender = [node packetSender];

    NSData *data = [NSData dataWithBytes:packetData length:packetLength];

    return [packetSender sendDataWithLocalAddress:localAddress
                                  toRemoteAddress:remoteAddress
                                             data:data
                                              ttl:ttl];
}

UInt64 now() {
    return [NSDate timeIntervalSinceReferenceDate] * 1000.0;
}

@implementation Node

- (id) initWithDataStore:(ZeroTierDataStore*)dataStore
           configHandler:(id<NetworkConfigHandler>)configHandler
            eventHandler:(id<EventHandler>)eventHandler
            frameHandler:(id<NetworkFrameHandler>)frameHandler
            packetSender:(id<PacketSender>)packetSender {

    self = [super init];

    if(self) {
        _dataStore = dataStore;
        _configHandler = configHandler;
        _eventHandler = eventHandler;
        _frameHandler = frameHandler;
        _packetSender = packetSender;

        _callbacks = (struct ZT_Node_Callbacks*)malloc(sizeof(struct ZT_Node_Callbacks));
        memset(_callbacks, 0, sizeof(struct ZT_Node_Callbacks));
        _callbacks->dataStoreGetFunction = DataStoreGetFunction;
        _callbacks->dataStorePutFunction = DataStorePutFunction;
        _callbacks->wirePacketSendFunction = WirePacketSendFunction;
        _callbacks->virtualNetworkFrameFunction = VirtualNetworkFrameFunction;
        _callbacks->virtualNetworkConfigFunction = VirtualNetworkConfigFunction;
        _callbacks->eventCallback = EventCallback;

        enum ZT_ResultCode rc = ZT_Node_new(&_node,
                                            (__bridge void *)(self),
                                            NULL,
                                            _callbacks,
                                            now());
        
        if (rc != ZT_RESULT_OK) {
            DDLogError(@"Error initializing node");
            return nil;
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onMemoryWarning:) name:@"ZT_MEMORY_WARNING"
                                                   object:nil];

        _onceToken = 0;

        dispatch_once(&_onceToken, ^{
            dispatch_source_t source =
                dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0,
                                       DISPATCH_MEMORYPRESSURE_WARN|DISPATCH_MEMORYPRESSURE_CRITICAL,
                                       dispatch_get_main_queue());

            dispatch_source_set_event_handler(source,^{
                unsigned long pressureLevel = dispatch_source_get_data(source);

                NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:pressureLevel] forKey:@"pressure"];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ZT_MEMORY_WARNING"
                                                                    object:nil
                                                                  userInfo:dict];
            });
            dispatch_resume(source);
        });

        _nextDeadline = 0;
        _deadlineMutex = [[NSObject alloc] init];

        DDLogError(@"Node ID: 0x%llx", ZT_Node_address(_node));
    }

    return self;
}

- (void)dealloc {
    [self shutdown];
}

- (void)shutdown {
    if(_node) {
        ZT_Node_delete(_node);
        _node = nil;
        free(_callbacks);
        _callbacks = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (ZeroTierDataStore*)dataStore {
    return _dataStore;
}

- (id<NetworkConfigHandler>)networkConfigHandler {
    return _configHandler;
}

- (id<NetworkFrameHandler>)networkFrameHandler {
    return _frameHandler;
}

- (id<EventHandler>)eventHandler {
    return _eventHandler;
}

- (id<PacketSender>)packetSender {
    return _packetSender;
}

- (void)onMemoryWarning:(NSNotification*)note {
    DDLogError(@"Received memory warning");
}

- (UInt64)nextDeadline {
    @synchronized(_deadlineMutex) {
        return _nextDeadline;
    }
}

- (void)setNextDeadline:(UInt64)deadline {
    @synchronized(_deadlineMutex) {
        _nextDeadline = deadline;
    }
}

- (void)processWirePacket:(const struct sockaddr_storage*)localAddress
            remoteAddress:(const struct sockaddr_storage*)remoteAddress
               packetData:(NSData*)packetData {

    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return;
    }
    
    UInt64 deadline = [self nextDeadline];

    enum ZT_ResultCode rc = ZT_Node_processWirePacket(_node,
                                                      NULL,
                                                      now(),
                                                      localAddress,
                                                      remoteAddress,
                                                      [packetData bytes],
                                                      (uint32_t)[packetData length],
                                                      &deadline);

    if(rc != ZT_RESULT_OK) {
        DDLogError(@"Error calling processWirePacket: %d", rc);
        return;
    }

    [self setNextDeadline:deadline];
}

- (void)processWirePacket:(const struct sockaddr_storage*)remoteAddress
               packetData:(NSData*)packetData {
    [self processWirePacket:&ZT_SOCKADDR_NULL
              remoteAddress:remoteAddress
                 packetData:packetData];
}

- (void)processBackgroundTasks {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return;
    }
    
    UInt64 deadline = [self nextDeadline];
    enum ZT_ResultCode rc = ZT_Node_processBackgroundTasks(_node, NULL, now(), &deadline);

    if(rc != ZT_RESULT_OK) {
        DDLogError(@"Error calling processBackgroundTasks: %d", rc);
        return;
    }

    [self setNextDeadline:deadline];
}

- (void)joinNetwork:(UInt64)networkId {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return;
    }
    
    ZT_Node_join(_node, networkId, NULL, NULL);
}

- (void)leaveNetwork:(UInt64)networkId {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return;
    }
    
    ZT_Node_leave(_node, networkId, NULL, NULL);
}

- (void)processVirtualNetworkFrameForNetwork:(UInt64)networkId
                                   sourceMac:(UInt64)sourceMac
                                     destMac:(UInt64)destMac
                                   etherType:(UInt32)etherType
                                      vlanId:(UInt32)vlanId
                                   frameData:(NSData*)frameData {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return;
    }
    
    UInt64 deadline = [self nextDeadline];

    enum ZT_ResultCode rc = ZT_Node_processVirtualNetworkFrame(_node,
                                                               NULL,
                                                               now(),
                                                               networkId,
                                                               sourceMac,
                                                               destMac,
                                                               etherType,
                                                               vlanId,
                                                               [frameData bytes],
                                                               (uint32_t)[frameData length],
                                                               &deadline);

    if(rc != ZT_RESULT_OK) {
        DDLogError(@"Error on processVirtualNetworkFrame: %d", rc);
        return;
    }

    [self setNextDeadline:deadline];
}

- (void)multicastSubscribe:(UInt64)networkId
            multicastGroup:(UInt64)multicastGroup
              multicastAdi:(UInt32)adi {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return;
    }
    
    enum ZT_ResultCode rc = ZT_Node_multicastSubscribe(_node, NULL, networkId,
                                                       multicastGroup, adi);

    if(rc != ZT_RESULT_OK) {
        DDLogError(@"Error joining multicast group: %d", rc);
    }
}

- (void)multicastUnsubscribe:(UInt64)networkId
              multicastGroup:(UInt64)multicastGroup
                multicastAdi:(UInt32)adi {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return;
    }
    
    enum ZT_ResultCode rc = ZT_Node_multicastUnsubscribe(_node, networkId,
                                                         multicastGroup, adi);

    if(rc != ZT_RESULT_OK) {
        DDLogError(@"Error leaving multicast group: %d", rc);
    }
}

- (UInt64)address {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return 0;
    }
    
    return ZT_Node_address(_node);
}

- (NodeStatus*)status {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return nil;
    }
    
    ZT_NodeStatus ns;
    ZT_Node_status(_node, &ns);
    NodeStatus *status = [[NodeStatus alloc] initWithStatus:ns];
    return status;
}

- (VirtualNetworkConfig*)networkConfig:(UInt64)networkId {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return nil;
    }
    
    ZT_VirtualNetworkConfig *cfg = ZT_Node_networkConfig(_node, networkId);
    if(cfg != NULL) {
        VirtualNetworkConfig *config = [[VirtualNetworkConfig alloc] initWithNetworkConfig:*cfg];
        ZT_Node_freeQueryResult(_node, cfg);
        return config;
    }
    return nil;
}

- (NSArray<Peer*>*)peers {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return [NSArray array];
    }
    
    ZT_PeerList *pl = ZT_Node_peers(_node);

    NSMutableArray<Peer*> *peers = [NSMutableArray array];

    for(unsigned int i = 0; i < pl->peerCount; ++i) {
        ZT_Peer peer = pl->peers[i];
        Peer *p = [[Peer alloc] initWithPeer:peer];
        [peers addObject:p];
    }
    ZT_Node_freeQueryResult(_node, pl);

    return peers;
}

- (NSArray<VirtualNetworkConfig*>*)networks {
    if(_node == NULL) {
        DDLogError(@"Error: node is null");
        return [NSArray array];
    }
    
    ZT_VirtualNetworkList *netList = ZT_Node_networks(_node);

    NSMutableArray<VirtualNetworkConfig*> *list = [NSMutableArray array];

    for(unsigned int i = 0; i < netList->networkCount; ++i) {
        ZT_VirtualNetworkConfig ztn = netList->networks[i];

        VirtualNetworkConfig *cfg = [[VirtualNetworkConfig alloc] initWithNetworkConfig:ztn];

        [list addObject:cfg];
    }

    ZT_Node_freeQueryResult(_node, netList);

    return list;
}

@end
