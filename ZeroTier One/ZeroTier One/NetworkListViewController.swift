//
//  ViewController.swift
//  ZeroTier One
//
//  Created by Grant Limberg on 8/27/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

import UIKit
import NetworkExtension

class NetworkListViewController: UITableViewController {

    var _deviceId: String? = nil

    var vpnManagers: [ZTVPN] = [] {
        willSet {
            if !newValue.isEmpty {
                for mgr in vpnManagers {
                    mgr.removeConfigObserver(self)
                    mgr.removeStatusOserver(self)
                }
            }
        }
        didSet {
            for mgr in vpnManagers {
                mgr.addConfigObserver(self, selector: #selector(NetworkListViewController.onVPNConfigChanged(_:)))
                mgr.addStatusObserver(self, selector: #selector(NetworkListViewController.onManagerStateChanged(_:)))
            }
            tableView.reloadData()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        navigationItem.leftBarButtonItem = editButtonItem
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 75

        navigationController!.navigationBar.tintColor = UIColor(red: 35.0/255.0, green: 68.0/255.0, blue: 71.0/255.0, alpha: 1.0)

        let defaults = UserDefaults.standard
        if var deviceId = defaults.string(forKey: "com.zerotier.one.deviceId") {
            while deviceId.characters.count < 10 {
                deviceId = "0\(deviceId)"
            }

            _deviceId = deviceId
            let idButton = UIBarButtonItem(title: deviceId, style: .plain, target: self, action: #selector(NetworkListViewController.showCopy(_:)))
            idButton.tintColor = UIColor.white
            self.setToolbarItems([idButton], animated: true)
        }

        //print(RouteTableManager.formatRouteTable())
        //print("\(NSSearchPathForDirectoriesInDomains(Foundation.FileManager.SearchPathDirectory.cachesDirectory, Foundation.FileManager.SearchPathDomainMask.userDomainMask, true).first)")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        //PiwikTracker.sharedInstance().sendView("Network List");
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.vpnManagers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "NetworkTableCell", for: indexPath) as! NetworkTableCell

        let manager = vpnManagers[indexPath.row]
        let networkId = manager.getNetworkID()
        cell.networkIdLabel.text = String(networkId.uint64Value, radix: 16)
        cell.networkNameLabel.text = manager.getNetworkName()
        cell.onOffSwitch.setOn(false, animated: true)

        cell.vpnManager = manager
        cell.tableViewController = self

        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
            let network = vpnManagers[indexPath.row]

            let title = "Delete \(network.getNetworkName()!)?"
            let message = "Are you sure you want to delete this network?"

            let ac = UIAlertController(title: title,
                message: message,
                preferredStyle: .actionSheet)

            let cancelAction = UIAlertAction(title: "Cancel",
                style: .cancel, handler: nil)
            ac.addAction(cancelAction)

            let deleteAction = UIAlertAction(title: "Delete",
                style: .destructive,
                handler: { (action) -> Void in
                    network.remove() { (error) -> Void in
                        if error != nil {
                            ////DDLogError("Error removing network: \(String(describing: error))")
                            return
                        }
                        let index = self.vpnManagers.index(of: network)
                        self.vpnManagers.remove(at: index!)

                        OperationQueue.main.addOperation() {
                            tableView.reloadData()
                        }
                    }
                })
            ac.addAction(deleteAction)

            let view = tableView.cellForRow(at: indexPath) as! NetworkTableCell
            ac.popoverPresentationController?.sourceView = view.networkNameLabel

            present(ac, animated: true, completion: nil)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let nw = indexPath.row

        let mgr = vpnManagers[nw]

        if mgr.status() == .connected {
            self.performSegue(withIdentifier: "ShowNetworkInfo", sender: self)
        }
        else {
            self.performSegue(withIdentifier: "ShowNetworkNotConnected", sender: self)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let id = segue.identifier {
            switch id {
            case "NewNetwork":
                break
                //DDLogDebug("Adding a new network")
            case "ShowNetworkInfo":
                //DDLogDebug("Showing network info")
                if let row = tableView.indexPathForSelectedRow?.row {
                    let network = vpnManagers[row]
                    let networkInfoView = segue.destination as! NetworkInfoViewController
                    networkInfoView.manager = network
                }
            case "ShowNetworkNotConnected":
                //DDLogDebug("Show Network: Not Connected")
                if let row = tableView.indexPathForSelectedRow?.row {
                    let network = vpnManagers[row]
                    let networkInfoView = segue.destination as! NotConnectedViewController
                    networkInfoView.manager = network
                }
            default:
                break
            }
        }
        else {
            ////DDLogError("Unknown segue identifier")
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {

        switch identifier {
        case "NewNetwork":
            return true
        case "ShowNetworkInfo":
            if let row = tableView.indexPathForSelectedRow?.row {
                let mgr = vpnManagers[row]

                if mgr.status() == .connected {
                    return true
                }
                else {
                    return false
                }
            }
            else {
                return false
            }
        case "ShowNetworkNotConnected":
            if let row = tableView.indexPathForSelectedRow?.row {
                let mgr = vpnManagers[row]

                if mgr.status() == .connected {
                    return false
                }
                else {
                    return true
                }
            }
            else {
                return true
            }
        default:
            return false
        }

    }

    func addNetwork(_ networkId: UInt64, name: String, allowDefault: Bool = false) {

        for mgr in vpnManagers {
            let curNetworkId = mgr.getNetworkID().uint64Value

            if networkId == curNetworkId {
                //DDLogWarn("Configuration with network id \(networkId) already exists")
                TWStatus.show("Network already exists!")
                TWStatus.dismiss(after: 3.0)
                return
            }
        }


        let newManager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.tunnel.unique.ZeroTierPTP"
        proto.serverAddress = "127.0.0.1"

        var config = [String:NSObject]()
        config["networkid"] = NSNumber(value: networkId as UInt64)
        config["allowDefault"] = NSNumber(value: allowDefault as Bool)

        proto.providerConfiguration = config

        newManager.protocolConfiguration = proto
        newManager.localizedDescription = name
        newManager.isEnabled = false

        newManager.saveToPreferences() { error in
            if error != nil {
                ////DDLogError("Error adding new network: \(String(describing: error))")
            }

            ZTVPNManager.sharedManager().loadVpnSettings() { newManagers, error in
                
                if error != nil {
                    ////DDLogError("\(String(describing: error))")
                    return
                }
              
                if let vpnManagers = newManagers {
                    OperationQueue.main.addOperation() {
                        self.vpnManagers = vpnManagers
                    }
                }
                else {
                    ////DDLogError("No managers loaded")
                }
            }

        }
    }

    func onVPNConfigChanged(_ note: Notification) {

    }

    func onManagerStateChanged(_ note: Notification) {
        if let connection = note.object as? NETunnelProviderSession {

            // get
            let requestDict : NSDictionary = ["request": "deviceid"]
            TunnelCommunication.sendRequest(connection, message: requestDict) { (responseDict) in
                if let dict = responseDict {
                    OperationQueue.main.addOperation() {
                        var deviceId = String( (dict["deviceid"] as! NSNumber).uint64Value, radix: 16)

                        while deviceId.characters.count < 10 {
                            deviceId = "0\(deviceId)"
                        }

                        //DDLogDebug("Got device id: \(deviceId)")
                        self._deviceId = deviceId

                        let defaults = UserDefaults.standard
                        if let savedDeviceId = defaults.string(forKey: "com.zerotier.one.deviceId") {
                            if savedDeviceId != deviceId {
                                let idButton = UIBarButtonItem(title: deviceId, style: .plain, target: self, action: #selector(NetworkListViewController.showCopy(_:)))
                                idButton.tintColor = UIColor.white
                                self.setToolbarItems([idButton], animated: true)

                                defaults.setValue(deviceId, forKey: "com.zerotier.one.deviceId")
                                defaults.synchronize()
                            }
                        }
                        else {
                            let idButton = UIBarButtonItem(title: deviceId, style: .plain, target: self, action: #selector(NetworkListViewController.showCopy(_:)))
                            idButton.tintColor = UIColor.white
                            self.setToolbarItems([idButton], animated: true)
                            defaults.setValue(deviceId, forKey: "com.zerotier.one.deviceId")
                            defaults.synchronize()
                        }
                    }
                }
            }

            if connection.status == .connected {
                updateConnectedNetworkName()
            }
        }
    }

    func showCopy(_ sender: AnyObject) {
        if let id = _deviceId {
            //DDLogDebug("id \(id) copied!")
            let pb = UIPasteboard.general
            pb.string = id
        }
    }

    func findConnectedNetwork() -> ZTVPN? {
        for mgr in vpnManagers {
            if mgr.status() == .connected {
                return mgr
            }
        }

        return nil
    }

    func updateConnectedNetworkName() {
        let connectedManager = findConnectedNetwork()

        if let mgr = connectedManager {
            let nwid = mgr.getNetworkID()
            let requestDict = ["request": "networkinfo", "networkid": nwid] as [String : Any]

            if let m = mgr as? ZTVPN_Device {
                TunnelCommunication.sendRequest(m.mgr.connection as! NETunnelProviderSession, message: requestDict as NSDictionary) { (responseDict) in
                    if let dict = responseDict {
                        if mgr.getNetworkName() == nil || mgr.getNetworkName()!.isEmpty {
                            m.mgr.localizedDescription = dict["name"] as? String

                            m.saveWithCompletionHandler() { (error) in
                                if error != nil {
                                    ////DDLogError("\(String(describing: error))")
                                }
                                else {
                                    ZTVPNManager.sharedManager().loadVpnSettings() { newManagers, error in

                                        if error != nil {
                                            ////DDLogError("\(String(describing: error))")
                                            return
                                        }

                                        if let vpnManagers = newManagers {
                                            OperationQueue.main.addOperation() {
                                                self.vpnManagers = vpnManagers
                                            }
                                        }
                                        else {
                                            ////DDLogError("No managers loaded")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

