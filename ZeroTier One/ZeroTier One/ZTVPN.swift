//
//  ZTVPN.swift
//  ZeroTier One
//
//  Created by Grant Limberg on 4/30/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

import Foundation
import NetworkExtension
import CocoaLumberjackSwift

class ZTVPN : NSObject {
    func save() {}
    func saveWithCompletionHandler(_ completionHandler: ((Error?) -> Void)?) {}
    func remove(_ completionHandler: ((Error?) -> Void)?) {}

    func startVpn() throws {}
    func stopVpn() {}

    func getNetworkID() -> NSNumber { return NSNumber() }
    func getNetworkName() -> String? { return nil }
    func status() -> NEVPNStatus { return .disconnected }

    func addStatusObserver(_ observer: AnyObject, selector: Selector) {}
    func removeStatusOserver(_ observer: AnyObject) {}

    func addConfigObserver(_ observer: AnyObject, selector: Selector) {}
    func removeConfigObserver(_ observer: AnyObject) {}

    func setEnabled(_ enabled: Bool) {}
}

class ZTVPN_Device : ZTVPN {
    let mgr: NETunnelProviderManager

    init(manager: NETunnelProviderManager) {
        mgr = manager
        super.init()
    }

    override func getNetworkID() -> NSNumber {
        let proto = mgr.protocolConfiguration as! NETunnelProviderProtocol
        return proto.providerConfiguration!["networkid"] as! NSNumber
    }

    override func getNetworkName() -> String? {
        return mgr.localizedDescription
    }

    override func status() -> NEVPNStatus {
        return mgr.connection.status
    }

    override func remove(_ completionHandler: ((Error?) -> Void)?) {
        mgr.removeFromPreferences(completionHandler: completionHandler)
    }

    override func save() {
        saveWithCompletionHandler() { (error) -> Void in
            if let e = error {
                DDLogError("\(e)")
                return
            }
        }
    }

    override func saveWithCompletionHandler(_ completionHandler: ((Error?) -> Void)?) {
        mgr.saveToPreferences(completionHandler: completionHandler)
    }

    override func setEnabled(_ enabled: Bool) {
        mgr.isEnabled = true
    }

    override func startVpn() throws {
        do {
            try mgr.connection.startVPNTunnel()
        }
        catch let error {
            throw error
        }
    }

    override func stopVpn() {
        mgr.connection.stopVPNTunnel()
    }


    override func addStatusObserver(_ observer: AnyObject, selector: Selector) {
        NotificationCenter.default.addObserver(observer, selector: selector, name: NSNotification.Name.NEVPNStatusDidChange, object: mgr.connection)
    }

    override func removeStatusOserver(_ observer: AnyObject) {
        NotificationCenter.default.removeObserver(observer, name: NSNotification.Name.NEVPNStatusDidChange, object: mgr.connection)
    }

    override func addConfigObserver(_ observer: AnyObject, selector: Selector) {
        NotificationCenter.default.addObserver(observer, selector: selector, name: NSNotification.Name.NEVPNConfigurationChange, object: mgr)
    }

    override func removeConfigObserver(_ observer: AnyObject) {
        NotificationCenter.default.removeObserver(observer, name: NSNotification.Name.NEVPNConfigurationChange, object: mgr)
    }
}

class ZTVPN_Simulator : ZTVPN {
    var _status: NEVPNStatus = .disconnected
    var name: String
    var id: UInt64

    init(name: String, networkId: UInt64) {
        self.name = name
        self.id = networkId
    }

    override func getNetworkID() -> NSNumber {
        return NSNumber(value: self.id as UInt64)
    }

    override func getNetworkName() -> String? {
        return name
    }

    override func status() -> NEVPNStatus {
        return _status
    }

    override func remove(_ completionHandler: ((Error?) -> Void)?) {

    }

    override func startVpn() throws {
        _status = .connected
    }

    override func stopVpn() {
        _status = .disconnected
    }

    override func saveWithCompletionHandler(_ completionHandler: ((Error?) -> Void)?) {
        if let handler = completionHandler {
            handler(nil)
        }
    }
}

func createZTVPN(_ mgr: NETunnelProviderManager) -> ZTVPN {
    return ZTVPN_Device(manager: mgr)
}

func createZTVPN(_ name: String, networkId: UInt64) -> ZTVPN {
    return ZTVPN_Simulator(name: name, networkId: networkId)
}
