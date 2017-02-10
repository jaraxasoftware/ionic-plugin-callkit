/*
	Abstract:
	CallKit provider delegate class, which conforms to CXProviderDelegate protocol
 */

import Foundation
import CallKit
import AVFoundation

@available(iOS 10.0, *)
final class CDVProviderDelegate: NSObject, CXProviderDelegate {
    
    let callManager: CDVCallManager
    private let provider: CXProvider
    static let AudioNotification = "CDVCallKitAudioNotification"
    
    init(callManager: CDVCallManager) {
        self.callManager = callManager
        provider = CXProvider(configuration: self.dynamicType.providerConfiguration)
        
        super.init()
        
        provider.setDelegate(self, queue: nil)
    }
    
    /// The app's provider configuration, representing its CallKit capabilities
    static var providerConfiguration: CXProviderConfiguration {
        let localizedName = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? String
        let providerConfiguration = CXProviderConfiguration(localizedName: localizedName!)
        
        providerConfiguration.supportsVideo = true
        
        providerConfiguration.maximumCallsPerCallGroup = 1
        
//        FIXME: find equivalent form for swift 2.3
//        providerConfiguration.supportedHandleTypes = [.generic]
        
        if let iconMaskImage = UIImage(named: "IconMask") {
            providerConfiguration.iconTemplateImageData = UIImagePNGRepresentation(iconMaskImage)
        }
        
        providerConfiguration.ringtoneSound = NSBundle.mainBundle().pathForResource("Ringtone", ofType: "caf")
        
        return providerConfiguration
    }
    
    // MARK: Incoming Calls
    
    /// Use CXProvider to report the incoming call to the system
    func reportIncomingCall(uuid: NSUUID, handle: String, hasVideo: Bool = false,supportsGroup: Bool = false, supportsUngroup: Bool = false, supportsDTMF: Bool = false, supportsHold: Bool = false, completion: ((NSError?) -> Void)? = nil) {
        // Construct a CXCallUpdate describing the incoming call, including the caller.
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .Generic, value: handle)
        update.hasVideo = hasVideo
        update.supportsGrouping = supportsGroup
        update.supportsUngrouping = supportsUngroup
        update.supportsDTMF = supportsDTMF
        update.supportsHolding = supportsHold
        
        // Report the incoming call to the system
        provider.reportNewIncomingCallWithUUID(uuid, update: update, completion: { error in
            /*
             Only add incoming call to the app's list of calls if the call was allowed (i.e. there was no error)
             since calls may be "denied" for various legitimate reasons. See CXErrorCodeIncomingCallError.
             */
            if error == nil {
                let call = CDVCall(uuid: uuid)
                call.handle = handle
                
                self.callManager.addCall(call)
            }
            
            completion?(error as NSError!)
        })
    }
    
    // MARK: CXProviderDelegate
    
    func providerDidReset(provider: CXProvider) {
        print("Provider did reset")
        
        self.postAudioNotification( "stopAudio" )

        /*
         End any ongoing calls if the provider resets, and remove them from the app's list of calls,
         since they are no longer valid.
         */
        for call in callManager.calls {
            call.endCDVCall()
        }
        
        // Remove all calls from the app's list of calls.
        callManager.removeAllCalls()
    }
    
    func provider(provider: CXProvider, performStartCallAction action: CXStartCallAction) {
        // Create & configure an instance of CDVCall, the app's model class representing the new outgoing call.
        let call = CDVCall(uuid: action.callUUID, isOutgoing: true)
        call.handle = action.handle.value
        
        /*
         Configure the audio session, but do not start call audio here, since it must be done once
         the audio session has been activated by the system after having its priority elevated.
         */
        self.postAudioNotification( "configureAudio" )
        
        /*
         Set callback blocks for significant events in the call's lifecycle, so that the CXProvider may be updated
         to reflect the updated state.
         */
        call.hasStartedConnectingDidChange = { [weak self] in
            self?.provider.reportOutgoingCallWithUUID(call.uuid, startedConnectingAtDate: call.connectingDate)
        }
        call.hasConnectedDidChange = { [weak self] in
            self?.provider.reportOutgoingCallWithUUID(call.uuid, connectedAtDate: call.connectDate)
        }
        
        // Trigger the call to be started via the underlying network service.
        call.startCDVCall { success in
            if success {
                // Signal to the system that the action has been successfully performed.
                action.fulfill()
                
                // Add the new outgoing call to the app's list of calls.
                self.callManager.addCall(call)
            } else {
                // Signal to the system that the action was unable to be performed.
                action.fail()
            }
        }
    }
    
    func provider(provider: CXProvider, performAnswerCallAction action: CXAnswerCallAction) {
        // Retrieve the CDVCall instance corresponding to the action's call UUID
        guard let call = callManager.callWithUUID(action.callUUID) else {
            action.fail()
            return
        }
        
        /*
         Configure the audio session, but do not start call audio here, since it must be done once
         the audio session has been activated by the system after having its priority elevated.
         */
        self.postAudioNotification( "configureAudio" )
        
        // Trigger the call to be answered via the underlying network service.
        call.answerCDVCall()
        
        // Signal to the system that the action has been successfully performed.
        action.fulfill()
    }
    
    func provider(provider: CXProvider, performEndCallAction action: CXEndCallAction) {
        // Retrieve the CDVCall instance corresponding to the action's call UUID
        guard let call = callManager.callWithUUID(action.callUUID) else {
            action.fail()
            return
        }
        
        // Stop call audio whenever ending the call.
        self.postAudioNotification( "stopAudio" )
        
        // Trigger the call to be ended via the underlying network service.
        call.endCDVCall()
        
        // Signal to the system that the action has been successfully performed.
        action.fulfill()
        
        // Remove the ended call from the app's list of calls.
        callManager.removeCall(call)
    }
    
    func provider(provider: CXProvider, performSetHeldCallAction action: CXSetHeldCallAction) {
        // Retrieve the CDVCall instance corresponding to the action's call UUID
        guard let call = callManager.callWithUUID(action.callUUID) else {
            action.fail()
            return
        }
        
        // Update the CDVCall's underlying hold state.
        call.isOnHold = action.onHold
        
        // Stop or start audio in response to holding or unholding the call.
        if call.isOnHold {
            self.postAudioNotification( "stopAudio" )
        } else {
            self.postAudioNotification( "startAudio" )
        }
        
        // Signal to the system that the action has been successfully performed.
        action.fulfill()
    }
    
    func provider(provider: CXProvider, timedOutPerformingAction action: CXAction) {
        print("Timed out \(#function)")
        
        // React to the action timeout if necessary, such as showing an error UI.
        
        action.fulfill();
    }

    func provider(provider: CXProvider, didActivateAudioSession audioSession: AVAudioSession) {
        print("Received \(#function)")
        
        // Start call audio media, now that the audio session has been activated after having its priority boosted.
        self.postAudioNotification( "startAudio" )
    }

    func provider(provider: CXProvider, didDeactivateAudioSession audioSession: AVAudioSession) {
        print("Received \(#function)")
        
        /*
         Restart any non-call related audio now that the app's audio session has been
         de-activated after having its priority restored to normal.
         */
    }

    private func postAudioNotification(message: String) {
        NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.AudioNotification, object: message)
    }
}
