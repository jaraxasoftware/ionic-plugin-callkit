/*
	Abstract:
	Model class representing a single call
 */
import Foundation

@available(iOS 10.0, *)
final class CDVCall {
    
    // MARK: Metadata Properties
    
    let uuid: NSUUID
    let isOutgoing: Bool
    var handle: String?
    
    // MARK: Call State Properties
    
    var connectingDate: NSDate? {
        didSet {
            stateDidChange?()
            hasStartedConnectingDidChange?()
        }
    }
    var connectDate: NSDate? {
        didSet {
            stateDidChange?()
            hasConnectedDidChange?()
        }
    }
    var endDate: NSDate? {
        didSet {
            stateDidChange?()
            hasEndedDidChange?()
        }
    }
    var isOnHold = false {
        didSet {
            stateDidChange?()
        }
    }
    
    // MARK: State change callback blocks
    
    var stateDidChange: (() -> Void)?
    var hasStartedConnectingDidChange: (() -> Void)?
    var hasConnectedDidChange: (() -> Void)?
    var hasEndedDidChange: (() -> Void)?
    
    // MARK: Derived Properties
    
    var hasStartedConnecting: Bool {
        get {
            return connectingDate != nil
        }
        set {
            connectingDate = newValue ? NSDate() : nil
        }
    }
    var hasConnected: Bool {
        get {
            return connectDate != nil
        }
        set {
            connectDate = newValue ? NSDate() : nil
        }
    }
    var hasEnded: Bool {
        get {
            return endDate != nil
        }
        set {
            endDate = newValue ? NSDate() : nil
        }
    }
    var duration: NSTimeInterval {
        guard let connectDate = connectDate else {
            return 0
        }
        
        return NSDate().timeIntervalSinceDate(connectDate)
    }
    
    // MARK: Initialization
    
    init(uuid: NSUUID, isOutgoing: Bool = false) {
        self.uuid = uuid
        self.isOutgoing = isOutgoing
    }
    
    // MARK: Actions
    
    func startCDVCall(completion: ((success: Bool) -> Void)?) {
        // Simulate the call starting successfully
        completion?(success: true)
        
        hasStartedConnecting = true
    }
    
    func connectedCDVCall() {
        // Call has connected
        hasConnected = true
    }
    
    func answerCDVCall() {
        // call is answered, start connecting
        hasStartedConnecting = true
    }
    
    func endCDVCall() {
        /*
         Simulate the end taking effect immediately, since
         the example app is not backed by a real network service
         */
        hasEnded = true
    }
    
}
