//
//  NotConnectedViewController.swift
//  ZeroTier One
//
//  Created by Grant Limberg on 4/18/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

import UIKit
import NetworkExtension
import CocoaLumberjackSwift

class NotConnectedViewController: UIViewController {

    @IBOutlet var networkIdLabel: UILabel!
    @IBOutlet var networkNameLabel: UILabel!
    @IBOutlet weak var routeViaZTSwitch: UISwitch!

    var _deviceId: String? = nil

    var manager: ZTVPN!

    override func viewDidLoad() {
        super.viewDidLoad()
        let defaults = UserDefaults.standard

        if var deviceId = defaults.string(forKey: "com.zerotier.one.deviceId") {
            while deviceId.characters.count < 10 {
                deviceId = "0\(deviceId)"
            }
            _deviceId = deviceId
            let idButton = UIBarButtonItem(title: deviceId, style: .plain, target: self, action: #selector(NotConnectedViewController.copyId(_:)))
            idButton.tintColor = UIColor.white
            self.setToolbarItems([idButton], animated: true)
        }


    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        PiwikTracker.sharedInstance().sendView("Network Info: Not Connected");

        let curNetworkId = manager.getNetworkID().uint64Value

        let networkIdTxt = String(curNetworkId, radix: 16)
        networkIdLabel.text = networkIdTxt
        networkNameLabel.text = manager.getNetworkName()

        if let mgr = manager as? ZTVPN_Device {
            let proto = mgr.mgr.protocolConfiguration as! NETunnelProviderProtocol
            if let allowDefault = proto.providerConfiguration?["allowDefault"] as? NSNumber {
                routeViaZTSwitch.isOn = allowDefault.boolValue
            }
            else {
                routeViaZTSwitch.isOn = false
            }
        }

        manager.addStatusObserver(self, selector: #selector(NotConnectedViewController.onConnectionStateChanged(_:)))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        manager.removeStatusOserver(self)
    }

    func copyId(_ sender: AnyObject) {
        if let id = _deviceId {
            DDLogDebug("id \(id) copied!")
            let pb = UIPasteboard.general
            pb.string = id
        }
    }

    func onConnectionStateChanged(_ note: Notification) {
        if let connection = note.object as? NETunnelProviderSession {

            if connection.status == .connected {

//                let root = self.navigationController?.viewControllers[0]
//
//                root?.navigationController?.popViewControllerAnimated(false)
//                root?.performSegueWithIdentifier("ShowNetworkInfo", sender: root)

                let newvc: NetworkInfoViewController = self.storyboard?.instantiateViewController(withIdentifier: "network-info") as! NetworkInfoViewController
                newvc.manager = self.manager

                var controllers = self.navigationController!.viewControllers

                controllers.removeLast()
                controllers.append(newvc)
                self.navigationController?.viewControllers = controllers
            }
        }
    }

    @IBAction func onRouteSwitchChanged(_ sender: AnyObject) {
        if let mgr = manager as? ZTVPN_Device {
            let proto = mgr.mgr.protocolConfiguration as! NETunnelProviderProtocol
            proto.providerConfiguration!["allowDefault"] = NSNumber(value: routeViaZTSwitch.isOn as Bool)
        }
        manager.save()
    }
}
