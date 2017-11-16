//
//  TunnelCommunication.swift
//  ZeroTier One
//
//  Created by Grant Limberg on 1/4/16.
//  Copyright © 2016 Zero Tier, Inc. All rights reserved.
//

import Foundation
import NetworkExtension

class TunnelCommunication {
    class func sendRequest(_ session: NETunnelProviderSession, message: NSDictionary, responseHandler: @escaping (([String:AnyObject]?) -> Void)) {
        do {
            print("sendRequest",message.description)
            let jsonData = try JSONSerialization.data(withJSONObject: message, options: JSONSerialization.WritingOptions(rawValue: 0))
            do {
                try session.sendProviderMessage(jsonData) { (data: Data?) -> Void in
                    if data == nil {
                        responseHandler(nil)
                        return
                    }

                    do {
                        let json = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? [String:AnyObject]
                        print("json",json)
                        responseHandler(json)
                        return
                    }
                    catch {
                        print("Error converting response data to dictionary: \(error)")
                    }
                }
            }
            catch {
                print("Error communicating with tunnel: \(error)")
            }
        }
        catch {
            print("Error converting message to JSON: \(error)")
        }
    }
}
