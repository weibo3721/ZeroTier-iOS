//
//  FilesystemUtils.m
//  ZeroTier One
//
//  Created by Grant Limberg on 1/8/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

#import "FilesystemUtils.h"

@implementation FilesystemUtils

+ (NSURL*) applicationDataDirectory {
    NSFileManager* sharedFM = [NSFileManager defaultManager];

    NSArray<NSString*> * appSupportDirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, true);

    NSURL *appSupportURL = nil;
    NSURL *appDirectory = nil;

    if([appSupportDirs count] > 0) {
        appSupportURL = [NSURL fileURLWithPath:appSupportDirs[0]];
    }

    if(appSupportURL != nil) {
        NSString *appBundleID = [[NSBundle mainBundle] bundleIdentifier];
        appDirectory = [appSupportURL URLByAppendingPathComponent:appBundleID];

        NSError *error = nil;
        [sharedFM createDirectoryAtURL:appDirectory
           withIntermediateDirectories:true
                            attributes:nil
                                 error:&error];

        if(error) {
            NSLog(@"Error creating app support directory");
            return nil;
        }
    }

    return appDirectory;
}

@end
