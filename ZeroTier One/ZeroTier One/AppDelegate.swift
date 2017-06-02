//
//  AppDelegate.swift
//  ZeroTier One
//
//  Created by Grant Limberg on 8/27/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

import UIKit
import NetworkExtension
import CocoaLumberjackSwift


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        //DDLog.add(DDTTYLogger.sharedInstance)
        DDLog.add(DDASLLogger.sharedInstance)
        #if DEBUG
        CocoaLumberjackSwift.defaultDebugLevel = .all
        #else
        CocoaLumberjackSwift.defaultDebugLevel = .info
        #endif


        let settingsKey = "com.zerotier.ZeroTier-One.uuid"
        var uuid = UUID().uuidString
        let defaults = UserDefaults.standard
        let tmpUuid = defaults.string(forKey: settingsKey)
        if let u = tmpUuid {
            uuid = u
        }
        else {
            defaults.set(uuid, forKey: settingsKey)
        }

        PiwikTracker.sharedInstance(withSiteID: "4", baseURL: URL.init(string: "https://piwik.zerotier.com/piwik.php"))
        PiwikTracker.sharedInstance().userID = uuid
        PiwikTracker.sharedInstance().appName = "ZeroTier One iOS"
        PiwikTracker.sharedInstance().appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        PiwikTracker.sharedInstance().dispatchInterval = 0
        #if DEBUG
        PiwikTracker.sharedInstance().debug = true
        #endif
        
        loadVpnManagers()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        loadVpnManagers()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

    }

    func loadVpnManagers() {
        // Load the tunnel data from iOS and set it on the network list view controller

        let navController = window!.rootViewController as! UINavigationController


        if let networkController = navController.viewControllers.first as? NetworkListViewController {

            ZTVPNManager.sharedManager().loadVpnSettings { newManagers, error in

                if error != nil {
                    //DDLogError("\(String(describing: error))")
                    return
                }

                if let mgrs = newManagers {
                    OperationQueue.main.addOperation() {
                        networkController.vpnManagers = mgrs
                    }
                }
            }
        }
    }


}

