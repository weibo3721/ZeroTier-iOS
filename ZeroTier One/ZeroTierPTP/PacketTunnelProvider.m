//
//  PacketTunnelProvider.m
//  ZeroTier One
//
//  Created by Grant Limberg on 10/31/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "PacketTunnelProvider.h"
#import "Logger.h"
#import "UDPCom.h"
#import "Reachability.h"
#import "OneService.h"

@implementation PacketTunnelProvider

- (void)startTunnelWithOptions:(NSDictionary<NSString *,NSObject *> *)options completionHandler:(void (^)(NSError * _Nullable))completionHandler {

    (void)options;

    //DDLogDebug(@"PTP Loaded");

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
       // [DDLog addLogger:[DDTTYLogger sharedInstance]];
        //[DDLog addLogger:[DDASLLogger sharedInstance]];
    });

    if (_udpCom == nil) {
        _udpCom = [[UDPCom alloc] initWithPTP:self];
    }

    _reachability = [Reachability reachabilityWithHostName:@"www.zerotier.com"];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:_udpCom
           selector:@selector(reachabilityChanged:)
               name:kReachabilityChangedNotification
             object:_reachability];

    if ([_reachability startNotifier] != YES) {
        ////DDLogError(@"Couldn't start reachability task");
    }

    _service = [[OneService alloc] initWithPTP:self
                                        udpCom:_udpCom];

    pendingStartCompletion = completionHandler;

    [nc addObserver:self
           selector:@selector(onNodeStatusChanged:)
               name:statusNotificationKey
             object:_service];

    NETunnelProviderProtocol *config = (NETunnelProviderProtocol*)self.protocolConfiguration;
    NSDictionary *providerConfig = config.providerConfiguration;

    UInt64 networkId = 0;
    NSNumber *nwid = (NSNumber*)[providerConfig objectForKey:@"networkid"];
    if (nwid != nil) {
        networkId = nwid.unsignedLongLongValue;
    }
    else {
        NSError *error = [NSError errorWithDomain:@"com.zerotier.ZeroTier-One.ZeroTierPTP"
                                             code:-1
                                         userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to determine Netowrk ID", nil),
                                                    NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Network ID not present in provider configuration", nil),
                                                    NSLocalizedRecoveryOptionsErrorKey: NSLocalizedString(@"Delete the network and recreate it", nil)
                                                                 }];
        pendingStartCompletion(error);
    }

    BOOL allowDefault = false;
    NSNumber *def = (NSNumber*)[providerConfig objectForKey:@"allowDefault"];
    if (def) {
        allowDefault = def.boolValue;
    }

    [_service runService:allowDefault completionHandler:^{
       // DDLogDebug(@"runService completion handler");

        if (networkId != 0) {
            [_service joinNetwork:networkId];
        }
    }];
}

- (void)onNodeStatusChanged:(NSNotification*)note {
    if (note.userInfo) {
        NSDictionary *userInfo = note.userInfo;

        NSNumber *val = (NSNumber*)[userInfo objectForKey:@"status"];
        if (val) {
            unsigned int value = val.unsignedIntValue;
            switch(value) {
                case ZT_EVENT_ONLINE:
                {
                    if (pendingStartCompletion) {
                        pendingStartCompletion(nil);
                        pendingStartCompletion = nil;
                    }
                }
                default:
                    break;
            }
        }
    }
}

- (void)errorStartingNode:(NSString*)error {
    if (pendingStartCompletion) {
        pendingStartCompletion([NSError errorWithDomain:@"com.zerotier.ZeroTier-One.ZeroTierPTP"
                                                   code:-2
                                               userInfo:@{NSLocalizedDescriptionKey: error}]);
        pendingStartCompletion = nil;
    }
}

- (void)stopTunnelWithReason:(NEProviderStopReason)reason completionHandler:(void (^)(void))completionHandler {
    (void)reason;
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [_reachability stopNotifier];
    [nc removeObserver:_udpCom name:kReachabilityChangedNotification object:_reachability];
    [nc removeObserver:self name:statusNotificationKey object:_service];

    [_service stopService];
    _service = nil;

    completionHandler();
}

- (void)handleAppMessage:(NSData *)messageData completionHandler:(void (^)(NSData * _Nullable))completionHandler {
    NSError *error = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:messageData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&error];
    NSLog(@"handleAppMessage");
    //DDLogError(@"Error deserializing JSON data: %@", error);
    if (error) {
        
        return;
    }

    NSString *request = [dict objectForKey:@"request"];
    if (!request) {
        ////DDLogError(@"No request in JSON data");
        return;
    }

    if ([request isEqualToString:@"networkinfo"]) {
        NSNumber *nwidtmp = (NSNumber*)[dict objectForKey:@"networkid"];
        if (nwidtmp != nil) {
            UInt64 nwid = nwidtmp.unsignedLongLongValue;

            NSDictionary *response = [self handleNetworkInfoRequest:nwid];

            NSData *responseJson = [NSJSONSerialization dataWithJSONObject:response
                                                                   options:0
                                                                     error:&error];

            if (error) {
                ////DDLogError(@"Error serializing response: %@", error);
                return;
            }

            if (completionHandler) {
                completionHandler(responseJson);
            }
        }
        else {
            ////DDLogError(@"Unable to find \"networkid\" element");
            return;
        }
    }
    else if ([request isEqualToString:@"deviceid"]) {
        if (_service != nil) {
            NSMutableDictionary *response = [NSMutableDictionary dictionary];
            NSNumber *deviceId = [NSNumber numberWithUnsignedLongLong:[_service getDeviceID]];

            if (deviceId == nil) {
                ////DDLogError(@"Unable to retrieve device ID from service");
                return;
            }

            [response setObject:deviceId forKey:@"deviceid"];

            NSData *responseJson = [NSJSONSerialization dataWithJSONObject:response
                                                                   options:0
                                                                     error:&error];

            if (error) {
                ////DDLogError(@"Error serializing device ID response: %@", error);
                return;
            }

            if(completionHandler) {
                completionHandler(responseJson);
            }
        }
        else {
            ////DDLogError(@"_service is nil!");
        }
    }
    else {
        ////DDLogError(@"Unknown command: %@", request);
    }
}

- (void)sleepWithCompletionHandler:(void (^)(void))completionHandler {
    completionHandler();
}

- (void)wake {

}

- (NSDictionary<NSString*, id>*)handleNetworkInfoRequest:(UInt64)networkId {
    NSMutableDictionary<NSString*, id> *response = [NSMutableDictionary dictionary];

    VirtualNetworkConfig *config = [_service.node networkConfig:networkId];

    [response setObject:[NSNumber numberWithUnsignedLongLong:config.nwid]
                 forKey:@"networkid"];
    [response setObject:config.name
                 forKey:@"name"];
    [response setObject:[NSNumber numberWithUnsignedLongLong:config.mac]
                 forKey:@"mac"];

    NSString *status = nil;
    switch (config.status) {
        case ZT_NETWORK_STATUS_REQUESTING_CONFIGURATION:
            status = @"Requesting Configuration";
            break;
        case ZT_NETWORK_STATUS_OK:
            status = @"OK";
            break;
        case ZT_NETWORK_STATUS_ACCESS_DENIED:
            status = @"Access Denied";
            break;
        case ZT_NETWORK_STATUS_NOT_FOUND:
            status = @"Network Not Found";
            break;
        case ZT_NETWORK_STATUS_PORT_ERROR:
            status = @"Port Error";
            break;
        case ZT_NETWORK_STATUS_CLIENT_TOO_OLD:
            status = @"Client Too Old";
            break;
        default:
            status = @"Unknown";
            break;
    }
    [response setObject:status
                 forKey:@"status"];

    NSString *networkType = nil;
    switch (config.type) {
        case ZT_NETWORK_TYPE_PRIVATE:
            networkType = @"Private";
            break;
        case ZT_NETWORK_TYPE_PUBLIC:
            networkType = @"Public";
            break;
        default:
            networkType = @"Unknown";
            break;
    }
    [response setObject:networkType
                 forKey:@"type"];

    [response setObject:[NSNumber numberWithUnsignedInt:config.mtu]
                 forKey:@"mtu"];
    [response setObject:(config.dhcp ? @"YES" : @"NO")
                 forKey:@"dhcp"];
    [response setObject:(config.broadcastEnabled ? @"YES" : @"NO")
                 forKey:@"broadcast"];
    [response setObject:(config.bridge ? @"YES" : @"NO")
                 forKey:@"bridge"];
    [response setObject:[NSNumber numberWithUnsignedInt:config.portError]
                 forKey:@"porterror"];

    NSMutableArray<NSString*> *addresses = [NSMutableArray array];
    for (NSData *addr in config.assignedAddresses) {
        struct sockaddr_storage address;
        [addr getBytes:&address
                 length:[addr length]];
        NSString *addressString = sockaddr_getString(address);
        if ([addressString length] > 0) {
            int port = sockaddr_getPort(address);

            NSString *displayString = [NSString stringWithFormat:@"%@/%d", addressString, port];
            [addresses addObject:displayString];
        }
    }
    [response setObject:addresses
                 forKey:@"addresses"];

    return response;
}


@end
