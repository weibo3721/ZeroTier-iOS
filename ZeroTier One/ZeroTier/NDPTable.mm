//
//  NDPTable.mm
//  ZeroTier One
//
//  Created by Grant Limberg on 10/6/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "NDPTable.h"
#import <sys/socket.h>

#import "InetAddress.hpp"
#import "Hashtable.hpp"
#import "AddressUtils.h"
#import "OSUtils.hpp"

#import <CocoaLumberjack/CocoaLumberjack.h>

#if DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif


using namespace ZeroTier;

uint16_t calc_checksum (uint16_t *addr, int len)
{
    int count = len;
    uint32_t sum = 0;
    uint16_t answer = 0;

    // Sum up 2-byte values until none or only one byte left.
    while (count > 1) {
        sum += *(addr++);
        count -= 2;
    }

    // Add left-over byte, if any.
    if (count > 0) {
        sum += *(uint8_t *) addr;
    }

    // Fold 32-bit sum into 16 bits; we lose information by doing this,
    // increasing the chances of a collision.
    // sum = (lower 16 bits) + (upper 16 bits shifted right 16 bits)
    while (sum >> 16) {
        sum = (sum & 0xffff) + (sum >> 16);
    }

    // Checksum is one's compliment of sum.
    answer = ~sum;

    return (answer);
}

struct _ipv6_header {
    uint8_t versionClassFlow[4];
    uint16_t length;
    uint8_t nextHeader;
    uint8_t hopLimit;
    uint8_t sourceAddress[16];
    uint8_t destAddress[16];
};


struct _pseudo_header {
    uint8_t sourceAddr[16];
    uint8_t targetAddr[16];
    uint32_t length;
    uint8_t zeros[3];
    uint8_t next;  // 58
};

struct _option {
    _option(int optionType)
    : type(optionType)
    , length(1)
    {
        memset(mac, 0, sizeof(mac));
    }

    uint8_t type;
    uint8_t length;
    uint8_t mac[6];
};

struct _neighbor_solicitation {
    _neighbor_solicitation()
    : type(135)
    , code(0)
    , checksum(0)
    , option(1)
    {
        memset(&reserved, 0, sizeof(reserved));
        memset(target, 0, sizeof(target));
    }

    void calculateChecksum(const sockaddr_storage &sourceIp, const sockaddr_storage &destIp) {
        _pseudo_header ph;
        memset(&ph, 0, sizeof(_pseudo_header));
        const sockaddr_in6 *src = (const sockaddr_in6*)&sourceIp;
        const sockaddr_in6 *dest = (const sockaddr_in6*)&destIp;

        memcpy(ph.sourceAddr, &src->sin6_addr, sizeof(struct in6_addr));
        memcpy(ph.targetAddr, &dest->sin6_addr, sizeof(struct in6_addr));
        ph.next = 58;
        ph.length = htonl(sizeof(_neighbor_solicitation));

        size_t len = sizeof(_pseudo_header) + sizeof(_neighbor_solicitation);
        uint8_t *tmp = (uint8_t*)malloc(len);
        memcpy(tmp, &ph, sizeof(_pseudo_header));
        memcpy(tmp+sizeof(_pseudo_header), this, sizeof(_neighbor_solicitation));

        checksum = calc_checksum((uint16_t*)tmp, (int)len);
        
        free(tmp);
        tmp = NULL;
    }

    uint8_t type; // 135
    uint8_t code; // 0
    uint16_t checksum;
    uint32_t reserved;
    uint8_t target[16];
    _option option;
};

struct _neighbor_advertisement {
    _neighbor_advertisement()
    : type(136)
    , code(0)
    , checksum(0)
    , rso(0x40)
    , option(2)
    {
        memset(padding, 0, sizeof(padding));
        memset(target, 0, sizeof(target));
    }

    void calculateChecksum(const sockaddr_storage &sourceIp, const sockaddr_storage &destIp) {
        _pseudo_header ph;
        memset(&ph, 0, sizeof(_pseudo_header));
        const sockaddr_in6 *src = (const sockaddr_in6*)&sourceIp;
        const sockaddr_in6 *dest = (const sockaddr_in6*)&destIp;

        memcpy(ph.sourceAddr, &src->sin6_addr, sizeof(struct in6_addr));
        memcpy(ph.targetAddr, &dest->sin6_addr, sizeof(struct in6_addr));
        ph.next = 58;
        ph.length = htonl(sizeof(_neighbor_advertisement));

        size_t len = sizeof(_pseudo_header) + sizeof(_neighbor_advertisement);
        uint8_t *tmp = (uint8_t*)malloc(len);
        memcpy(tmp, &ph, sizeof(_pseudo_header));
        memcpy(tmp+sizeof(_pseudo_header), this, sizeof(_neighbor_advertisement));

        checksum = calc_checksum((uint16_t*)tmp, (int)len);

        free(tmp);
        tmp = NULL;
    }

    uint8_t type; // 136
    uint8_t code; // 0
    uint16_t checksum;
    uint8_t rso;
    uint8_t padding[3];
    uint8_t target[16];
    _option option;
};

#define ZT_ND_QUERY_INTERVAL 2000

#define ZT_ND_QUERY_MAX_TTL 5000

#define ZT_ND_EXPIRE 600000

struct neighbor_entry {
    neighbor_entry() : lastAccessed(0), mac() {}
    uint64_t lastAccessed;
    MAC mac;
};

@interface NDPTable ()
{
    Hashtable<InetAddress, neighbor_entry> _cache;
    uint64_t _lastCleaned;
}

@end

@implementation NDPTable

- (id)init {
    self = [super init];
    if (self) {
        _cache = Hashtable<InetAddress, neighbor_entry>();
        _lastCleaned = OSUtils::now();
    }
    return self;
}

- (void)dealloc {
    _cache.clear();
}

- (BOOL)hasMacForAddress:(struct sockaddr_storage)addr {
    InetAddress tmp(addr);
    tmp.setPort(0);
    return _cache.contains(tmp);
}

- (UInt64)macForAddress:(struct sockaddr_storage)addr {
    uint64_t now = OSUtils::now();

    InetAddress tmp(addr);
    tmp.setPort(0);
    neighbor_entry *e = _cache.get(tmp);
    if(e) {
        e->lastAccessed = now;
        return e->mac.toInt();
    }

    if((now - _lastCleaned) >= ZT_ND_EXPIRE) {
        _lastCleaned = now;
        Hashtable<InetAddress, neighbor_entry>::Iterator i(_cache);
        InetAddress *k = NULL;
        neighbor_entry *v = NULL;
        while(i.next(k, v)) {
            if((now - v->lastAccessed) >= ZT_ND_EXPIRE) {
                DDLogDebug(@"Erasing MAC entry: %s", v->mac.toString().c_str());
                _cache.erase(*k);
            }
        }
    }

    return 0;
}

- (void)addMac:(UInt64)mac forAddress:(struct sockaddr_storage)addr {
    uint64_t now = OSUtils::now();

    InetAddress tmp(addr);
    tmp.setPort(0);

    neighbor_entry entry;
    entry.mac = MAC(mac);
    entry.lastAccessed = OSUtils::now();
    _cache[tmp] = entry;

    if((now - _lastCleaned) >= ZT_ND_EXPIRE) {
        _lastCleaned = now;
        Hashtable<InetAddress, neighbor_entry>::Iterator i(_cache);
        InetAddress *k = NULL;
        neighbor_entry *v = NULL;
        while(i.next(k, v)) {
            if((now - v->lastAccessed) >= ZT_ND_EXPIRE) {
                DDLogDebug(@"Erasing MAC entry: %s", v->mac.toString().c_str());
                _cache.erase(*k);
            }
        }
    }
}

- (NSString*)description {
    NSString *desc = @"Table Contents:\n\n";

    InetAddress *key;
    neighbor_entry *value;

    Hashtable<InetAddress, neighbor_entry>::Iterator iter(_cache);
    while(iter.next(key, value)) {
        NSString *addrStr = sockaddr_getString(*key);

        NSString *tmp = [NSString stringWithFormat:@"%@ : %llu\n", addrStr, value->mac.toInt(), nil];
        desc = [desc stringByAppendingString:tmp];
    }

    return desc;
}

+ (NSData*)generateNeighborDiscoveryForAddress:(struct sockaddr_storage)to fromAddress:(struct sockaddr_storage)from fromMac:(UInt64)mac {

    size_t headerSize = sizeof(_ipv6_header);
    assert(headerSize == 40);

    _ipv6_header hdr;
    memset(&hdr, 0, sizeof(_ipv6_header));
    hdr.versionClassFlow[0] = 0b01100000;
    hdr.length = ntohs(sizeof(_neighbor_solicitation));
    hdr.nextHeader = 58;
    hdr.hopLimit = 255;

    NSString *srcAddress = sockaddr_getString(from);
    NSString *destAddress = sockaddr_getString(to);

    NSLog(@"From: %@ To: %@", srcAddress, destAddress);

    sockaddr_in6 *src = (sockaddr_in6*)&from;
    sockaddr_in6 *dest = (sockaddr_in6*)&to;
    memcpy(&hdr.sourceAddress[0], &src->sin6_addr, sizeof(in6_addr));
    memcpy(&hdr.destAddress[0], &dest->sin6_addr, sizeof(in6_addr));

    mac = CFSwapInt64BigToHost(mac);
    _neighbor_solicitation sol;
    memcpy(&sol.option.mac, ((uint8_t*)(&mac))+2, 6);
    memcpy(&sol.target[0], &dest->sin6_addr, sizeof(in6_addr));
    sol.calculateChecksum(from, to);

    NSMutableData *data = [NSMutableData dataWithLength:(sizeof(_ipv6_header)+sizeof(_neighbor_solicitation))];
    [data replaceBytesInRange:NSMakeRange(0, sizeof(_ipv6_header)) withBytes:&hdr length:sizeof(_ipv6_header)];
    [data replaceBytesInRange:NSMakeRange(sizeof(_ipv6_header), sizeof(_neighbor_solicitation)) withBytes:&sol length:sizeof(_neighbor_solicitation)];
    return data;
}

+ (NSData*)generateNeighborAdvertiesementForAddress:(struct sockaddr_storage)to fromAddress:(struct sockaddr_storage)from fromMac:(UInt64)mac {
    size_t headerSize = sizeof(_ipv6_header);
    assert(headerSize == 40);

    _ipv6_header hdr;
    memset(&hdr, 0, sizeof(_ipv6_header));
    hdr.versionClassFlow[0] = 0b01100000;
    hdr.length = ntohs(sizeof(_neighbor_advertisement));
    hdr.nextHeader = 58;
    hdr.hopLimit = 255;

    sockaddr_in6 *src = (sockaddr_in6*)&from;
    sockaddr_in6 *dest = (sockaddr_in6*)&to;
    memcpy(&hdr.sourceAddress[0], &src->sin6_addr, sizeof(in6_addr));
    memcpy(&hdr.destAddress[0], &dest->sin6_addr, sizeof(in6_addr));

    mac = CFSwapInt64BigToHost(mac);
    _neighbor_advertisement adv;
    memcpy(&adv.option.mac, ((uint8_t*)(&mac))+2, 6);
    memcpy(&adv.target[0], &src->sin6_addr, sizeof(in6_addr));
    adv.calculateChecksum(from, to);

    NSMutableData *data = [NSMutableData dataWithLength:(sizeof(_ipv6_header)+sizeof(_neighbor_advertisement))];
    [data replaceBytesInRange:NSMakeRange(0, sizeof(_ipv6_header)) withBytes:&hdr length:sizeof(_ipv6_header)];
    [data replaceBytesInRange:NSMakeRange(sizeof(_ipv6_header), sizeof(_neighbor_advertisement)) withBytes:&adv length:sizeof(_neighbor_advertisement)];
    return data;
}

@end
