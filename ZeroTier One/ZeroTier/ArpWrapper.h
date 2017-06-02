//
//  ArpWrapper.h
//  ZeroTier One
//
//  Created by Grant Limberg on 10/7/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

#ifndef ArpWrapper_h
#define ArpWrapper_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void ARP;

void ARP_new(ARP **arp);
void ARP_delete(ARP *arp);

void ARP_addLocal(ARP* arp, uint32_t ip, uint64_t mac);
void ARP_remove(ARP *arp, uint32_t ip);
uint32_t ARP_processIncomingArp(ARP *arp, const void *arpFrame, unsigned int len, void *response, unsigned int *responseLen, uint64_t *responseDest);
uint64_t ARP_query(ARP *arp, uint64_t localMac, uint32_t localIp, uint32_t targetIp, void *query, unsigned int *queryLen, uint64_t *queryDest);

#ifdef __cplusplus
}
#endif

#endif /* ArpWrapper_h */
