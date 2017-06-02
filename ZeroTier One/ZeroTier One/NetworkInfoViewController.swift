//
//  NetworkInfoViewController.swift
//  ZeroTier One
//
//  Created by Grant Limberg on 12/31/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

import UIKit
import NetworkExtension
import CocoaLumberjackSwift

class NetworkInfoViewController: UIViewController, ConnectedNetworkMonitorDelegate {

    var manager: ZTVPN!

    @IBOutlet var networkIdLabel: UILabel!
    @IBOutlet var networkNameLabel: UILabel!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var typeLabel: UILabel!
    @IBOutlet var macLabel: UILabel!
    @IBOutlet var mtuLabel: UILabel!
    @IBOutlet var broadcastLabel: UILabel!
    @IBOutlet var bridgingLabel: UILabel!
    @IBOutlet var managedIPsLabel: UILabel!
    @IBOutlet var routeViaZTSwitch: UISwitch!

    @IBOutlet var restartRequiredLabel: UILabel!

    var _deviceId: String? = nil

    var _networkMonitor: ConnectedNetworkMonitor?

    override func viewDidLoad() {
        super.viewDidLoad()

        _networkMonitor = ConnectedNetworkMonitor(delegate: self)
        loadViewInformation()

        restartRequiredLabel.isHidden = true

        let defaults = UserDefaults.standard
        if var deviceId = defaults.string(forKey: "com.zerotier.one.deviceId") {
            while deviceId.characters.count < 10 {
                deviceId = "0\(deviceId)"
            }
            _deviceId = deviceId
            let idButton = UIBarButtonItem(title: deviceId, style: .plain, target: self, action: #selector(NetworkInfoViewController.copyId(_:)))
            idButton.tintColor = UIColor.white
            self.setToolbarItems([idButton], animated: true)
        }

        if let mgr = manager as? ZTVPN_Device {
            let proto = mgr.mgr.protocolConfiguration as! NETunnelProviderProtocol
            if let allowDefault = proto.providerConfiguration?["allowDefault"] as? NSNumber {
                routeViaZTSwitch.isOn = allowDefault.boolValue
            }
            else {
                routeViaZTSwitch.isOn = false
            }
        }

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !_networkMonitor!.refreshRunning {
            loadViewInformation()
        }

        //PiwikTracker.sharedInstance().sendView("Network Info");
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        _networkMonitor!.stopMonitor()
    }

    func loadViewInformation() {
        _networkMonitor!.startMonitor(manager)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func copyId(_ sender: AnyObject) {
        if let id = _deviceId {
            DDLogDebug("id \(id) copied!")
            let pb = UIPasteboard.general
            pb.string = id
        }
    }

    func onNetworkStatusReceived(_ networkInfo: NetworkInfo) {
        self.networkIdLabel.text = networkInfo.networkId
        self.networkNameLabel.text = networkInfo.networkName
        self.statusLabel.text = networkInfo.status
        self.typeLabel.text = networkInfo.type
        self.macLabel.text = networkInfo.macAddress
        self.mtuLabel.text = networkInfo.mtu
        self.broadcastLabel.text = networkInfo.broadcast
        self.bridgingLabel.text = networkInfo.bridging

        var ipString = ""

        let constrainedWidth = self.managedIPsLabel.frame.width
        let fontName = self.managedIPsLabel.font.fontName
        var fontSize = self.managedIPsLabel.font.pointSize
        var labelFont = UIFont(name: fontName, size: fontSize)!
        var maxAdjustedWidth : CGFloat = 0.0

        if let managedIPs = networkInfo.managedIPs {
            for (index,ip) in managedIPs.enumerated() {

                let nsIp = ip as NSString
                var outputSize = nsIp.size(attributes: [NSFontAttributeName: labelFont])

                if outputSize.width > maxAdjustedWidth {
                    while outputSize.width > constrainedWidth {
                        fontSize -= 1.0
                        labelFont = UIFont(name: fontName, size: fontSize)!
                        outputSize = nsIp.size(attributes: [NSFontAttributeName: labelFont])
                    }
                    maxAdjustedWidth = outputSize.width
                    managedIPsLabel.font = labelFont
                }

                ipString += ip
                if index < (managedIPs.count - 1) {
                    ipString += "\n"
                }
            }
        }


        self.managedIPsLabel.text = ipString
    }

    @IBAction func onRoutingSwitchChanged(_ sender: AnyObject) {
        if let mgr = manager as? ZTVPN_Device {
            let proto = mgr.mgr.protocolConfiguration as! NETunnelProviderProtocol
            proto.providerConfiguration!["allowDefault"] = NSNumber(value: routeViaZTSwitch.isOn as Bool)
        }
        manager.save()

        restartRequiredLabel.isHidden = false
    }
}
