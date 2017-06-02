//
//  AddressUtils.h
//  ZeroTier One
//
//  Created by Grant Limberg on 9/4/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#ifndef AddressUtils_h
#define AddressUtils_h

#import <Foundation/Foundation.h>
#import "ZeroTierOne.h"

@interface NetInfo : NSObject

@property (readonly) sa_family_t family;
@property (readonly) NSString *network;
@property (readonly) NSString *netmask;
@property (readonly) NSNumber *prefix;

- (id)initWithNetwork:(NSString*)network andNetmask:(NSString*)netmask;
- (id)initWithNetwork:(NSString*)network andPrefix:(NSNumber*)prefix;

@end

#ifdef __cplusplus
extern "C" {
#endif
UInt32 sockaddrToInt(const struct sockaddr_storage addr);

NSString* sockaddr_getString(const struct sockaddr_storage addr);

unsigned int sockaddr_getPort(const struct sockaddr_storage addr);

NSString* sockaddr_getNetmaskString(const struct sockaddr_storage addr);

NSString* sockaddr_getBroadcastString(const struct sockaddr_storage addr);

NSString* sockaddr_getNetworkString(const struct sockaddr_storage addr);
struct sockaddr_storage sockaddr_getNetwork(const struct sockaddr_storage addr);

UInt64 sockaddr_getMulticastGroup(const struct sockaddr_storage addr);
UInt32 sockaddr_getMulticastAdi(const struct sockaddr_storage addr);


struct sockaddr_storage sockaddrFromInt32(uint32_t address);

BOOL sockaddr_isV4(const struct sockaddr_storage addr);

BOOL sockaddr_isV6(const struct sockaddr_storage addr);

NSArray<NSString*>* getDNSServers();

NSArray<NetInfo*>* getLocalNetworks();

struct sockaddr_storage getV4SourceAddressFromPacket(NSData *packet);
struct sockaddr_storage getV4DestAddressFromPacket(NSData *packet);
struct sockaddr_storage getV6SourceAddressFromPacket(NSData *packet);
struct sockaddr_storage getV6DestAddressFromPacket(NSData *packet);

BOOL sockaddrs_equal(struct sockaddr_storage lhs, struct sockaddr_storage rhs);

struct sockaddr_storage sockaddr_setPort(struct sockaddr_storage in, unsigned int port);

BOOL sockaddr_isNullAddress(struct sockaddr_storage in);

UInt64 ipv6ToMulticastMac(struct sockaddr_storage in);

#ifdef __cplusplus
} // extern "C"
#endif

#endif
