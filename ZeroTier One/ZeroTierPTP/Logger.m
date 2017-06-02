//
//  Logger.m
//  ZeroTier One
//
//  Created by Grant Limberg on 10/28/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "Logger.h"

#if DEBUG
const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
