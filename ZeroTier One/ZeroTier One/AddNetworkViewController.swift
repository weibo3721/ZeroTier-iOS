//
//  AddNetworkViewController.swift
//  ZeroTier One
//
//  Created by Grant Limberg on 12/31/15.
//  Copyright © 2015 Zero Tier, Inc. All rights reserved.
//

import UIKit
import CocoaLumberjackSwift

class AddNetworkViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet var networkIdView: UITextField!
    @IBOutlet var networkNameView: UITextField!
    @IBOutlet var addNetworkButton: UIButton!
    @IBOutlet var allowManagedSwitch: UISwitch!
    @IBOutlet var allowGlobalSwitch: UISwitch!
    @IBOutlet var allowDefaultSwitch: UISwitch!
    
    let hexCharset = CharacterSet(charactersIn: "ABCDEFabcdef0123456789")

    var _deviceId: String? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        navigationItem.title = "Add Network"

        addNetworkButton.isEnabled = false

        let defaults = UserDefaults.standard
        if var deviceId = defaults.string(forKey: "com.zerotier.one.deviceId") {
            while deviceId.characters.count < 10 {
                deviceId = "0\(deviceId)"
            }
            _deviceId = deviceId
            let idButton = UIBarButtonItem(title: deviceId, style: .plain, target: self, action: #selector(AddNetworkViewController.copyId(_:)))
            idButton.tintColor = UIColor.white
            self.setToolbarItems([idButton], animated: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        PiwikTracker.sharedInstance().sendView("Add Network");
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func dismissKeyboard(_ sender: AnyObject) {
        view.endEditing(true)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        for c in string.utf16.enumerated() {
            if !hexCharset.contains(UnicodeScalar(c.element)!) {
                return false
            }
        }

        guard let text = textField.text else { return true }

        let newLength = text.utf16.count + string.utf16.count - range.length

        // catch > 16 here so we don't disable the button
        if newLength > 16 {
            return false
        }

        if newLength == 16 {
            addNetworkButton.isEnabled = true
        }
        else {
            addNetworkButton.isEnabled = false
        }

        return true
    }

    @IBAction func onAddNetwork(_ sender: AnyObject) {
        DDLogDebug("Adding network: \(networkIdView.text!)")
        view.endEditing(true)

        let vcs = navigationController!.viewControllers
        let thisIndex = vcs.index(of: self)

        if let index = thisIndex {
            let networkListView = vcs[index-1] as! NetworkListViewController
            let nwid = UInt64(networkIdView.text!, radix: 16)!
            let allowDefault = allowDefaultSwitch.isOn
            
            networkListView.addNetwork(nwid, name: networkNameView.text!, allowDefault: allowDefault)
        }

        self.navigationController?.popViewController(animated: true)
    }

    func copyId(_ sender: AnyObject) {
        if let id = _deviceId {
            DDLogDebug("id \(id) copied!")
            let pb = UIPasteboard.general
            pb.string = id
        }
    }
}
