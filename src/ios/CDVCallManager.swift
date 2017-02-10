/*
	Abstract:
	Manager of Calls, using a CallKit CXCallController to request actions on calls
 */

import CallKit

@available(iOS 10.0, *)
final class CDVCallManager: NSObject {
    
    let callController = CXCallController()
    
    // MARK: Actions
    
    func startCall(uuid: NSUUID, handle: String, video: Bool = false) {
        let handle = CXHandle(type: .Generic, value: handle)
        let startCallAction = CXStartCallAction(callUUID: uuid, handle: handle)
        
        startCallAction.video = video
        
        let transaction = CXTransaction()
        transaction.addAction(startCallAction)
        
        requestTransaction(transaction)
    }
    
    func end(call: CDVCall) {
        let endCallAction = CXEndCallAction(callUUID: call.uuid)
        let transaction = CXTransaction()
        transaction.addAction(endCallAction)
        
        requestTransaction(transaction)
    }
    
    func setHeld(call: CDVCall, onHold: Bool) {
        let setHeldCallAction = CXSetHeldCallAction(callUUID: call.uuid, onHold: onHold)
        let transaction = CXTransaction()
        transaction.addAction(setHeldCallAction)
        
        requestTransaction(transaction)
    }
    
    private func requestTransaction(transaction: CXTransaction) {
        callController.requestTransaction(transaction, completion: { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
            }
        })
    }
    
    // MARK: Call Management
    
    static let CallsChangedNotification = "CDVCallKitCallsChangedNotification"
    
    private(set) var calls = [CDVCall]()
    
    func callWithUUID(uuid: NSUUID) -> CDVCall? {
        guard let index = calls.indexOf({ $0.uuid == uuid }) else {
            return nil
        }
        return calls[index]
    }
    
    func addCall(call: CDVCall) {
        calls.append(call)
        
        call.stateDidChange = { [weak self] in
            self?.postCallsChangedNotification()
        }
        
        postCallsChangedNotification()
    }
    
    func removeCall(call: CDVCall) {
        calls.removeFirst(where: { $0 === call })
        postCallsChangedNotification()
    }
    
    func removeAllCalls() {
        calls.removeAll()
        postCallsChangedNotification()
    }
    
    private func postCallsChangedNotification() {
        NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.CallsChangedNotification, object: self)
    }
    
    // MARK: CDVCallDelegate
    
    func cdvCallDidChangeState(call: CDVCall) {
        postCallsChangedNotification()
    }
    
}
