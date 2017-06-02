//
//  ConnectedNetworkMonitor.swift
//  ZeroTier One
//
//  Created by Grant Limberg on 4/5/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

import Foundation
import UIKit
import NetworkExtension
import CocoaLumberjackSwift

struct NetworkInfo {
    var networkId: String
    var networkName: String?
    var status: String?
    var type: String?
    var macAddress: String?
    var mtu: String?
    var broadcast: String?
    var bridging: String?
    var managedIPs: [String]?
}

protocol ConnectedNetworkMonitorDelegate {
    func onNetworkStatusReceived(_ networkInfo: NetworkInfo)
}

class ConnectedNetworkMonitor: NSObject {

    var delegate: ConnectedNetworkMonitorDelegate
    var refreshRunning = false

    init(delegate: ConnectedNetworkMonitorDelegate) {
        self.delegate = delegate
        super.init()
    }

    //func startMonitor(proto: NETunnelProviderProtocol, connection: NETunnelProviderSession) {
    func startMonitor(_ network: ZTVPN) {

        if let nw = network as? ZTVPN_Device {
            // device implementation 

            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
                self.refreshRunning = true
                while self.refreshRunning {
                    // get the network ID from the NEVPNManager
                    let nwid = nw.getNetworkID()

                    // Do any additional setup after loading the view.
                    let requestDict = ["request": "networkinfo", "networkid": nwid] as [String : Any]
                    TunnelCommunication.sendRequest(nw.mgr.connection as! NETunnelProviderSession, message: requestDict as NSDictionary) {
                        (responseDict) -> Void in

                        if let dict = responseDict {
                            OperationQueue.main.addOperation() {
                                var macAddr = ""
                                if let mac = dict["mac"] as? NSNumber {
                                    var macStr = String(mac.uint64Value, radix: 16)
                                    while macStr.lengthOfBytes(using: String.Encoding.utf8) < 12 {
                                        macStr = "0\(macStr)"
                                    }

                                    var displayStr = ""
                                    for i in 0 ..< macStr.characters.count {
                                        displayStr += "\(macStr[macStr.characters.index(macStr.startIndex, offsetBy: i)])"

                                        if i > 0 && i < 11 {
                                            if i % 2 == 1 {
                                                displayStr += ":"
                                            }
                                        }
                                    }
                                    macAddr = displayStr
                                }

                                var mtuStr = ""
                                if let mtu = dict["mtu"] as? NSNumber {
                                    mtuStr = mtu.stringValue
                                }

                                let netInfo = NetworkInfo(
                                    networkId: String(nwid.uint64Value, radix: 16),
                                    networkName: dict["name"] as? String,
                                    status: dict["status"] as? String,
                                    type: dict["type"] as? String,
                                    macAddress: macAddr,
                                    mtu: mtuStr,
                                    broadcast: dict["broadcast"] as? String,
                                    bridging: dict["bridge"] as? String,
                                    managedIPs: dict["addresses"] as? [String])

                                self.delegate.onNetworkStatusReceived(netInfo)
                            }
                        }
                    }
                    
                    sleep(2)
                }
            }
        }
        else {
            // Simulator implementation
            let netInfo = NetworkInfo(networkId: "8056c2e21c000001",
                                      networkName: "earth",
                                      status: "OK",
                                      type: "Public",
                                      macAddress: "02:1e:67:7d:1b:ba",
                                      mtu: "2800",
                                      broadcast: "YES",
                                      bridging: "NO",
                                      managedIPs: ["29.97.251.21/7"])
            self.delegate.onNetworkStatusReceived(netInfo)
        }
    }

    func stopMonitor() {
        self.refreshRunning = false
    }
}
