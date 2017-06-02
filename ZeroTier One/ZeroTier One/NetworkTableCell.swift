//
//  NetworkTableCell.swift
//  ZeroTier One
//
//  Created by Grant Limberg on 12/19/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

import UIKit
import NetworkExtension
import CocoaLumberjackSwift

class NetworkTableCell: UITableViewCell {

    @IBOutlet var networkIdLabel: UILabel!
    @IBOutlet var networkNameLabel: UILabel!
    @IBOutlet var onOffSwitch: UISwitch!

    var vpnManager: ZTVPN! {
        willSet {
            if vpnManager != nil {
                vpnManager.removeStatusOserver(self)
            }
        }
        didSet {
            vpnManager.addStatusObserver(self, selector: #selector(NetworkTableCell.onManagerStateChanged(_:)))

            onOffSwitch.setOn(vpnManager.status() == .connected, animated: true)
        }
    }

    var tableViewController: NetworkListViewController!

    deinit {
        if vpnManager != nil {
            vpnManager.removeStatusOserver(self)
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func onManagerStateChanged(_ note: Notification) {
        if let session = note.object as? NETunnelProviderSession {
            switch(session.status) {
            case .connected:
                DDLogDebug("State: Connected, Network: \(String(describing: self.networkIdLabel.text))")
            case .connecting:
                DDLogDebug("State: Connecting, Network: \(String(describing: self.networkIdLabel.text))")
            case .disconnected:
                DDLogDebug("State: Disconnected, Network: \(String(describing: self.networkIdLabel.text))")
                onOffSwitch.setOn(false, animated: true)
            case .disconnecting:
                DDLogDebug("State: Disconnecting, Network: \(String(describing: self.networkIdLabel.text))")
                onOffSwitch.setOn(false, animated: true)
            case .invalid:
                DDLogDebug("State: Invalid, Network: \(String(describing: self.networkIdLabel.text))")
                onOffSwitch.setOn(false, animated: true)
            case .reasserting:
                DDLogDebug("State: Reasserting, Network: \(String(describing: self.networkIdLabel.text))")
            }
        }
        else {
            DDLogDebug("Got notofication for unknown object: \(String(describing: note.object))")
        }
    }

    @IBAction func onSwitchStateChanged(_ sender: UISwitch) {
        let isOn = sender.isOn

        let networkId = self.vpnManager.getNetworkID()
        let networkIdStr = String(networkId.uint64Value, radix:16, uppercase: false)
        
        if isOn {
            if vpnManager.status() == .disconnected {
                vpnManager.setEnabled(true)
                vpnManager.saveWithCompletionHandler() { (error) -> Void in
                    if let e = error {
                        DDLogError("\(e)")
                        return
                    }

                    PiwikTracker.sharedInstance().sendEvent(withCategory: "network", action: "join", name: networkIdStr, value: NSNumber(value: 0))

                    do {
                        try self.vpnManager.startVpn()
                    }
                    catch let error {
                        DDLogError("Unkown error starting VPN: \(error)")
                    }
                }
            }
        }
        else {
            PiwikTracker.sharedInstance().sendEvent(withCategory: "network", action: "leave", name: networkIdStr, value: NSNumber(value:0))
            vpnManager.stopVpn()
        }
    }
}
