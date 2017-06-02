//
//  NetworkUtil.m
//  ZeroTier One
//
//  Created by Grant Limberg on 1/29/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "NetworkUtil.h"
#import <sys/socket.h>
#import <netdb.h>
#import <arpa/inet.h>
#import <err.h>

@implementation NetworkUtil

// Apple iOS magic to turn a IPv4 address into an IPv6 address on NAT64 networks.
//
// apparently getaddrinfo on iOS 9.2+ will turn an IPv4 address string into an IPv6 address in this case
//
// https://developer.apple.com/library/ios/documentation/NetworkingInternetWeb/Conceptual/NetworkingOverview/UnderstandingandPreparingfortheIPv6Transition/UnderstandingandPreparingfortheIPv6Transition.html#//apple_ref/doc/uid/TP40010220-CH213-DontLinkElementID_4
//
+ (struct sockaddr_storage)v6addressFromv4Address:(const struct sockaddr_storage*)v4_in
{
    struct sockaddr_storage v6;
    memset(&v6, 0, sizeof(struct sockaddr_storage));
    struct sockaddr_in *v4;

    if(v4_in->ss_family == AF_INET6)
    {
        return *v4_in;
    }

    v4 = (struct sockaddr_in*)v4_in;

    struct addrinfo hints, *res0;
    int error;

    char ipv4_str_buf[INET_ADDRSTRLEN] = { 0 };
    const char *ipv4_str = inet_ntop(AF_INET, &v4->sin_addr, ipv4_str_buf, sizeof(ipv4_str_buf));

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_INET6;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_flags = AI_DEFAULT;
    error = getaddrinfo(ipv4_str, "9993", &hints, &res0);
    if (error) {
        return *v4_in;
    }
    if (res0) {
        memcpy(&v6, res0->ai_addr, res0->ai_addrlen);
    }
    else {
        memcpy(&v6, v4_in, sizeof(struct sockaddr_storage));

    }
    freeaddrinfo(res0);

    if(v6.ss_len != sizeof(struct sockaddr_in6))
    {
        v6.ss_len = sizeof(struct sockaddr_in6);
    }
    
    return v6;
}

@end
