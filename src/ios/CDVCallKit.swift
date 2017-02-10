/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

@available(iOS 10.0, *)
@objc(CDVCallKit) class CDVCallKit : CDVPlugin {
    var callManager: CDVCallManager?
    var providerDelegate: CDVProviderDelegate?
    var callbackId: String?

    func register(command:CDVInvokedUrlCommand) {
        self.commandDelegate.runInBackground({
            var pluginResult = CDVPluginResult(
                status : CDVCommandStatus_ERROR
            )
            
            self.callManager = CDVCallManager()

            self.providerDelegate = CDVProviderDelegate(callManager: self.callManager!)
            
            self.callbackId = command.callbackId

            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.handle(withNotification:)), name: "CDVCallKitCallsChangedNotification", object: nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.handle(withNotification:)), name: "CDVCallKitAudioNotification", object: nil)

            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK
            )
            pluginResult?.setKeepCallbackAsBool(true)
            
            self.commandDelegate!.sendPluginResult(pluginResult, callbackId: command.callbackId)
        });
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func reportIncomingCall(command:CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status : CDVCommandStatus_ERROR
        )
        
        let uuid = NSUUID()
        let name = command.arguments[0] as? String ?? ""
        let hasVideo = command.arguments[1] as? Bool ?? false
        let supportsGroup = command.arguments[2] as? Bool ?? false
        let supportsUngroup = command.arguments[3] as? Bool ?? false
        let supportsDTMF = command.arguments[4] as? Bool ?? false
        let supportsHold = command.arguments[5] as? Bool ?? false

        providerDelegate?.reportIncomingCall(uuid,handle: name,hasVideo: hasVideo,supportsGroup: supportsGroup, supportsUngroup: supportsUngroup,supportsDTMF: supportsDTMF, supportsHold: supportsHold)
        
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAsString: uuid.UUIDString
        )
        pluginResult?.setKeepCallbackAsBool(false)

        self.commandDelegate!.sendPluginResult(pluginResult, callbackId: command.callbackId)
    }

    func startCall(command:CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status : CDVCommandStatus_ERROR
        )
        
        let name = command.arguments[0] as? String ?? ""
        let isVideo = (command.arguments[1] as! Bool)
        
        let uuid = NSUUID()
        self.callManager?.startCall(uuid, handle: name, video: isVideo)
        
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAsString : uuid.UUIDString
        )
        pluginResult?.setKeepCallbackAsBool(false)
        
        self.commandDelegate!.sendPluginResult(pluginResult, callbackId: command.callbackId)
    }

    func finishRing(command:CDVInvokedUrlCommand) {
        let pluginResult = CDVPluginResult(
            status : CDVCommandStatus_OK
        )

        pluginResult?.setKeepCallbackAsBool(false)
        self.commandDelegate!.sendPluginResult(pluginResult, callbackId: command.callbackId)
        /* does nothing on iOS */
    }

    func endCall(command:CDVInvokedUrlCommand) {
        self.commandDelegate.runInBackground({
            let uuid = NSUUID(UUIDString: command.arguments[0] as? String ?? "")
            
            if (uuid != nil) {
                let call = self.callManager?.callWithUUID(uuid!)
            
                if (call != nil) {
                    self.callManager?.end(call!)
                }
            }
        });
    }
    
    func callConnected(command:CDVInvokedUrlCommand) {
        self.commandDelegate.runInBackground({
            let uuid = NSUUID(UUIDString: command.arguments[0] as? String ?? "")
            
            if (uuid != nil) {
                let call = self.callManager?.callWithUUID(uuid!)
                
                if (call != nil) {
                    call?.connectedCDVCall()
                }
            }
        });
    }
    
    @objc func handle(withNotification notification : NSNotification) {
        if (notification.name == "CDVCallKitCallsChangedNotification") {
            let notificationObject = notification.object as? CDVCallManager
            var resultMessage = [String: AnyObject]()
            
            if (((notificationObject?.calls) != nil) && (notificationObject!.calls.count>0)) {
                let call = (notificationObject?.calls[0])! as CDVCall
                
                resultMessage = [
                    "callbackType" : "callChanged",
                    "handle" : call.handle as String? ?? "",
                    "isOutgoing" : call.isOutgoing as Bool,
                    "isOnHold" : call.isOnHold as Bool,
                    "hasConnected" : call.hasConnected as Bool,
                    "hasEnded" : call.hasEnded as Bool,
                    "hasStartedConnecting" : call.hasStartedConnecting as Bool,
                    "endDate" : call.endDate?.string("yyyy-MM-dd'T'HH:mm:ssZ") as String? ?? "",
                    "connectDate" : call.connectDate?.string("yyyy-MM-dd'T'HH:mm:ssZ") as String? ?? "",
                    "connectingDate" : call.connectingDate?.string("yyyy-MM-dd'T'HH:mm:ssZ") as String? ?? "",
                    "duration" : call.duration as Double
                ]
            }
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: resultMessage)
            pluginResult?.setKeepCallbackAsBool(true)

            print("RECEIVED CALL CHANGED NOTIFICATION: \(notification)")
            
            self.commandDelegate!.sendPluginResult(pluginResult, callbackId: self.callbackId)
        } else if (notification.name == "CDVCallKitAudioNotification") {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: [ "callbackType" : "audioSystem", "message" : notification.object as? String ?? "" ])
            pluginResult?.setKeepCallbackAsBool(true)

            self.commandDelegate!.sendPluginResult(pluginResult, callbackId: self.callbackId)

            print("RECEIVED AUDIO NOTIFICATION: \(notification)")
        } else {
            print("INVALID NOTIFICATION RECEIVED: \(notification)")
        }
    }
}
