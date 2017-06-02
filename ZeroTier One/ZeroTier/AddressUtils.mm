//
//  AddressUtils.m
//  ZeroTier One
//
//  Created by Grant Limberg on 9/4/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "AddressUtils.h"
#import "InetAddress.hpp"
#import "MulticastGroup.hpp"
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <resolv.h>
#include <dns.h>

using namespace ZeroTier;


@implementation NetInfo

- (id)initWithNetwork:(NSString *)network andNetmask:(NSString *)netmask
{
    self = [super init];

    if(self) {
        _network = network;
        _netmask = netmask;
        _prefix = nil;
        _family = AF_INET;
    }

    return self;
}

- (id)initWithNetwork:(NSString *)network andPrefix:(NSNumber *)prefix
{
    self = [super init];

    if (self) {
        _network = network;
        _netmask = nil;
        _prefix = prefix;
        _family = AF_INET6;
    }

    return self;
}

- (NSString*)description {
    if (_family == AF_INET) {
        return [NSString stringWithFormat:@"%@/%@", _network, _netmask, nil];
    }
    else {
        return [NSString stringWithFormat:@"%@/%lu", _network, [_prefix unsignedLongValue]];
    }
}

@end

#ifdef __cplusplus
extern "C" {
#endif

UInt32 sockaddrToInt(const struct sockaddr_storage addr) {
    if (addr.ss_family == AF_INET) {
        const sockaddr_in *ipv4 = (sockaddr_in*)&addr;
        UInt32 a = 0;
        memcpy(&a, &ipv4->sin_addr, sizeof(UInt32));
        return a;
    }
    return 0;
}

NSString* sockaddr_getString(const struct sockaddr_storage addr) {
    InetAddress address(addr);
    std::string addrStr = address.toIpString();
    NSString *ret = [NSString stringWithUTF8String:addrStr.c_str()];
    return ret;
}

unsigned int sockaddr_getPort(const struct sockaddr_storage addr) {
    InetAddress address(addr);
    return address.port();
}

NSString* sockaddr_getNetmaskString(const struct sockaddr_storage addr) {
    InetAddress address(addr);
    InetAddress netmask = address.netmask();
    return [NSString stringWithUTF8String:netmask.toIpString().c_str()];
}

NSString* sockaddr_getBroadcastString(const struct sockaddr_storage addr) {
    InetAddress address(addr);
    InetAddress broadcast = address.broadcast();
    return [NSString stringWithUTF8String:broadcast.toIpString().c_str()];
}

NSString* sockaddr_getNetworkString(const struct sockaddr_storage addr) {
    InetAddress address(addr);
    InetAddress network = address.network();
    return [NSString stringWithUTF8String:network.toIpString().c_str()];
}

struct sockaddr_storage sockaddr_getNetwork(const struct sockaddr_storage addr)
{
    InetAddress address(addr);
    return address.network();
}

UInt64 sockaddr_getMulticastGroup(const struct sockaddr_storage addr) {
    MulticastGroup mg = MulticastGroup::deriveMulticastGroupForAddressResolution(addr);
    return mg.mac().toInt();
}

UInt32 sockaddr_getMulticastAdi(const struct sockaddr_storage addr) {
    MulticastGroup mg = MulticastGroup::deriveMulticastGroupForAddressResolution(addr);

    return mg.adi();
}

struct sockaddr_storage sockaddrFromInt32(uint32_t address) {
    InetAddress addr(address, 0);
    return addr;
}

BOOL sockaddr_isV4(const struct sockaddr_storage addr) {
    InetAddress address(addr);
    return address.isV4();
}

BOOL sockaddr_isV6(const struct sockaddr_storage addr) {
    InetAddress address(addr);
    return address.isV6();
}

NSArray<NSString*>* getDNSServers() {
    NSMutableArray *servers = [NSMutableArray array];

    res_state res = (res_state)malloc(sizeof(struct __res_state));

    int result = res_ninit(res);

    if (result == 0) {
        for (int i = 0; i < res->nscount; ++i) {
            NSString *svr = [NSString stringWithUTF8String:inet_ntoa(res->nsaddr_list[i].sin_addr)];
            [servers addObject:svr];
        }
    }

    return servers;
}

bool startswith(const char *pre, const char *str) {
    return strncmp(pre, str, strlen(pre)) == 0;
}

NSArray<NetInfo*>* getLocalNetworks() {
    NSMutableArray *networks = [NSMutableArray array];

    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *tmp_addr = NULL;
    int success = 0;

    success = getifaddrs(&interfaces);

    if (success == 0) {
        tmp_addr = interfaces;

        while (tmp_addr != NULL) {

            if (startswith("en", tmp_addr->ifa_name) || startswith("pdp_ip", tmp_addr->ifa_name)) {
                if(tmp_addr->ifa_addr->sa_family == AF_INET) {
                    struct sockaddr_in *address = (sockaddr_in*)tmp_addr->ifa_addr;
                    struct sockaddr_in *netmask = (sockaddr_in*)tmp_addr->ifa_netmask;

                    if (address == NULL || netmask == NULL) {
                        tmp_addr = tmp_addr->ifa_next;
                        continue;
                    }

                    struct in_addr network;
                    network.s_addr = address->sin_addr.s_addr & netmask->sin_addr.s_addr;

                    NSString *networkStr = [NSString stringWithUTF8String:inet_ntoa(network)];
                    NSString *netmaskStr = [NSString stringWithUTF8String:inet_ntoa(netmask->sin_addr)];

                    if ([networkStr hasPrefix:@"127"]) {
                        tmp_addr = tmp_addr->ifa_next;
                        continue;
                    }

                    NetInfo *info = [[NetInfo alloc] initWithNetwork:networkStr andNetmask:netmaskStr];
                    [networks addObject:info];
                }
                else if (tmp_addr->ifa_addr->sa_family == AF_INET6) {
                    struct sockaddr_in6 *address = (sockaddr_in6*)tmp_addr->ifa_addr;
                    struct sockaddr_in6 *netmask = (sockaddr_in6*)tmp_addr->ifa_netmask;

                    if (address == NULL || netmask == NULL) {
                        tmp_addr = tmp_addr->ifa_next;
                        continue;
                    }

                    struct in6_addr network;
                    for(int i = 0; i < 4; ++i) {
                        network.__u6_addr.__u6_addr32[i] = address->sin6_addr.__u6_addr.__u6_addr32[i] & netmask->sin6_addr.__u6_addr.__u6_addr32[i];
                    }

                    int prefix = 0;
                    for(int i = 0; i < 4; ++i) {
                        uint32_t section = netmask->sin6_addr.__u6_addr.__u6_addr32[i];
                        while(section!=0) {
                            section = section&(section-1);
                            ++prefix;
                        }
                    }

                    char straddr[INET6_ADDRSTRLEN];
                    memset(straddr, 0, sizeof(straddr));
                    inet_ntop(AF_INET6, &network, straddr, sizeof(straddr));

                    NSString *networkStr = [NSString stringWithUTF8String:straddr];
                    if ([networkStr hasPrefix:@"fe80"] || [networkStr hasPrefix:@"FE80"]) {
                        tmp_addr = tmp_addr->ifa_next;
                        continue;
                    }

                    NetInfo *info = [[NetInfo alloc] initWithNetwork:networkStr andPrefix:[NSNumber numberWithUnsignedLong:prefix]];
                    [networks addObject:info];
                }
            }
            tmp_addr = tmp_addr->ifa_next;
        }
    }

    freeifaddrs(interfaces);

    return networks;
}

struct sockaddr_storage getV4SourceAddressFromPacket(NSData *packet) {
    uint8_t bytes[4];
    [packet getBytes:bytes range:NSMakeRange(12, 4)];
    InetAddress addr(bytes, 4, 0);
    addr.ss_family = AF_INET;
    addr.setPort(0);
    return addr;
}

struct sockaddr_storage getV4DestAddressFromPacket(NSData *packet) {
    uint8_t bytes[4];
    [packet getBytes:bytes range:NSMakeRange(16, 4)];
    InetAddress addr(bytes, 4, 0);
    addr.ss_family = AF_INET;
    addr.setPort(0);
    return addr;
}

struct sockaddr_storage getV6SourceAddressFromPacket(NSData *packet) {
    uint8_t bytes[16];
    [packet getBytes:bytes range:NSMakeRange(8, 16)];
    InetAddress addr(bytes, 16, 0);
    addr.ss_family = AF_INET6;
    addr.setPort(0);
    return addr;
}

struct sockaddr_storage getV6DestAddressFromPacket(NSData *packet) {
    uint8_t bytes[16];
    [packet getBytes:bytes range:NSMakeRange(24, 16)];
    InetAddress addr(bytes, 16, 0);
    addr.ss_family = AF_INET6;
    addr.setPort(0);
    return addr;
}

BOOL sockaddrs_equal(struct sockaddr_storage lhs, struct sockaddr_storage rhs) {
    InetAddress left(lhs);
    InetAddress right(rhs);
    return left == right;
}

struct sockaddr_storage sockaddr_setPort(struct sockaddr_storage in, unsigned int port) {
    InetAddress addr(in);
    addr.setPort(port);
    return addr;
}

BOOL sockaddr_isNullAddress(struct sockaddr_storage in) {
    return InetAddress(in) == InetAddress(ZT_SOCKADDR_NULL);
}

UInt64 ipv6ToMulticastMac(struct sockaddr_storage in) {
    if (in.ss_family == AF_INET6) {
        struct sockaddr_in6 *addr = (struct sockaddr_in6*)&in;

        uint8_t macArray[8] = { addr->sin6_addr.__u6_addr.__u6_addr8[15], addr->sin6_addr.__u6_addr.__u6_addr8[14], addr->sin6_addr.__u6_addr.__u6_addr8[13], 0xff, 0x33, 0x33, 0x00, 0x00 };
        //uint8_t macArray[8] = { 0x00, 0x00, 0x33, 0x33, 0xff, addr->sin6_addr.__u6_addr.__u6_addr8[13], addr->sin6_addr.__u6_addr.__u6_addr8[14], addr->sin6_addr.__u6_addr.__u6_addr8[15] };

        UInt64 mac = 0;
        memcpy(&mac, macArray, 8);
        return mac;
    }

    return 0;
}


#ifdef __cplusplus
} // extern "C"
#endif
