//
//  ArpWrapper.c
//  ZeroTier One
//
//  Created by Grant Limberg on 10/7/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

#include "ArpWrapper.h"
#include <stdio.h>
#include "Arp.hpp"
#include "MAC.hpp"

#ifdef __cplusplus
extern "C" {
#endif

    void ARP_new(ARP **arp)
    {
        *arp = reinterpret_cast<ARP*>(new ZeroTier::Arp());
    }

    void ARP_delete(ARP *arp)
    {
        delete (reinterpret_cast<ZeroTier::Arp*>(arp));
    }

    void ARP_addLocal(ARP* arp, uint32_t ip, uint64_t mac)
    {
        reinterpret_cast<ZeroTier::Arp*>(arp)->addLocal(ip, mac);
    }

    void ARP_remove(ARP *arp, uint32_t ip)
    {
        reinterpret_cast<ZeroTier::Arp*>(arp)->remove(ip);
    }

    uint32_t ARP_processIncomingArp(ARP *arp, const void *arpFrame, unsigned int len, void *response, unsigned int *responseLen, uint64_t *responseDest)
    {
        ZeroTier::MAC dest;

        uint32_t ret = reinterpret_cast<ZeroTier::Arp*>(arp)->processIncomingArp(arpFrame, len, response, *responseLen, dest);

        *responseDest = dest.toInt();

        return ret;
    }

    uint64_t ARP_query(ARP *arp, uint64_t localMac, uint32_t localIp, uint32_t targetIp, void *query, unsigned int *queryLen, uint64_t *queryDest)
    {
        ZeroTier::MAC local(localMac);
        ZeroTier::MAC dest;

        ZeroTier::MAC ret = reinterpret_cast<ZeroTier::Arp*>(arp)->query(local, localIp, targetIp, query, *queryLen, dest);

        *queryDest = dest.toInt();

        return ret.toInt();
    }
    
#ifdef __cplusplus
}
#endif
