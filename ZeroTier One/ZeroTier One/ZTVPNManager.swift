//
//  ZTVPNManager.swift
//  ZeroTier One
//
//  Created by Grant Limberg on 4/30/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

import Foundation
import NetworkExtension

protocol VPNImpl {
    func loadVpnSettings(_ completionHandler: @escaping (([ZTVPN]?, Error?) -> Void))

    func saveVpn(_ vpn: ZTVPN, completionHandler: @escaping (Error?) -> Void)

    func deleteVpn(_ vpn: ZTVPN, completionHandler: @escaping (Error?) -> Void)
}

class VPNImpl_Simulator : VPNImpl {
    func loadVpnSettings(_ completionHandler: @escaping (([ZTVPN]?, Error?) -> Void)) {
        var vpns = [ZTVPN]()

        vpns.append(createZTVPN("earth", networkId: 0x8056c2e21c000001))

        completionHandler(vpns, nil)
    }

    func saveVpn(_ vpn: ZTVPN, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    func deleteVpn(_ vpn: ZTVPN, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
}

class VPNImpl_Concrete : VPNImpl {
    func loadVpnSettings(_ completionHandler: @escaping (([ZTVPN]?, Error?) -> Void)) {
        NETunnelProviderManager.loadAllFromPreferences() { newManagers, error in

            if error != nil {
                completionHandler(nil, error)
                return
            }

            if let managers = newManagers {
                var ztmgrs = [ZTVPN]()

                for m in managers {
                    ztmgrs.append(createZTVPN(m))
                }

                completionHandler(ztmgrs, error)
            }
            else {
                completionHandler([ZTVPN](), nil)
            }
        }
    }


    func saveVpn(_ vpn: ZTVPN, completionHandler: @escaping (Error?) -> Void) {
        vpn.saveWithCompletionHandler(completionHandler)
    }

    func deleteVpn(_ vpn: ZTVPN, completionHandler: @escaping (Error?) -> Void) {
        vpn.remove(completionHandler)
    }
}

class ZTVPNManager: NSObject {

    fileprivate static let _instance = ZTVPNManager()

    fileprivate let impl : VPNImpl

    fileprivate override init() {
#if (arch(i386) || arch(x86_64)) && os(iOS)
    impl = VPNImpl_Simulator()
#else
    impl = VPNImpl_Concrete()
#endif
        super.init()
    }

    static func sharedManager() -> ZTVPNManager {
        return ZTVPNManager._instance
    }

    func loadVpnSettings(_ completionHandler: @escaping (([ZTVPN]?, Error?) -> Void)) {
        impl.loadVpnSettings(completionHandler)
    }

    func saveVpn(_ vpn: ZTVPN, completionHandler: @escaping (Error?) -> Void) {
        impl.saveVpn(vpn, completionHandler: completionHandler)
    }
}
