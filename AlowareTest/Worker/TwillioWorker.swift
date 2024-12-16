import Combine
import PushKit
import TwilioVoice
import CallKit
import AVFoundation

final class TwilioWorker: NSObject, Worker {
    private let twilioStream: MutableTwilioStreaming
    private let accessToken: String
    private let twimlParamTo: String = "to"
    
    private var cancellables = Set<AnyCancellable>()
    private var audioDevice = DefaultAudioDevice()
    private var activeCall: Call?
    private var callKitProvider: CXProvider?
    private let callKitCallController = CXCallController()
    private var callKitCompletionCallback: ((Bool) -> Void)?
    private var userInitiatedDisconnect = false
    private var activeCallInvites: [String: CallInvite] = [:]
    private var activeCalls: [String: Call] = [:]
    private var activeOngoing = ""
    let kCachedBindingDate = "CachedBindingDate"
    
    // MARK: - Initialization
    init(mutableTwilioStream: MutableTwilioStreaming) {
        guard let accessToken = Bundle.main.object(forInfoDictionaryKey: "TwilioAccessToken") as? String else {
            fatalError("TwilioAccessToken is missing in Info.plist")
        }
        self.twilioStream = mutableTwilioStream
        self.accessToken = accessToken
        super.init()
    }
    
    // MARK: - Worker Protocol
    func start() {
        NSLog("TwilioWorker started")
        setupCallKitProvider()
        setupAudioDevice()
        observeStream()
    }
    
    // MARK: - Private Methods
    private func observeStream() {
        twilioStream.callOperation
            .compactMap { $0 } // Ignore nil values
            .sink { [weak self] operation in
                switch operation {
                case .makeCall(let recipient):
                    self?.activeOngoing = recipient
                    self?.makeCall(to: recipient)
                case .endCall:
                    self?.endCall()
                }
            }
            .store(in: &cancellables)
        
        twilioStream.incomingPushPayload
            .sink { [weak self] payload in
                self?.incomingPushReceived(payload: payload)
            }
            .store(in: &cancellables)
        
        twilioStream.callConfiguration
            .sink { [weak self] config in
                self?.updateCallConfiguration(config: config)
            }
            .store(in: &cancellables)
    }
    
    private func makeCall(to recipient: String) {
        if activeCall != nil {
            // End the current active call before making a new one
            guard let currentCall = activeCall else { return }
            userInitiatedDisconnect = true
            performEndCallAction(uuid: currentCall.uuid!)
            return
        }
        
        let uuid = UUID()
        let handle = "Voice Bot"
        
        performStartCallAction(uuid: uuid, handle: handle)
    }
    
    func performStartCallAction(uuid: UUID, handle: String) {
        guard let provider = callKitProvider else {
            NSLog("CallKit provider not available")
            return
        }
        
        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)

        callKitCallController.request(transaction) { error in
            if let error = error {
                NSLog("StartCallAction transaction request failed: \(error.localizedDescription)")
                return
            }

            NSLog("StartCallAction transaction request successful")

            let callUpdate = CXCallUpdate()
            
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false

            provider.reportCall(with: uuid, updated: callUpdate)
        }
    }
    
    func reportIncomingCall(from: String, uuid: UUID) {
        guard let provider = callKitProvider else {
            NSLog("CallKit provider not available")
            return
        }

        let callHandle = CXHandle(type: .generic, value: from)
        let callUpdate = CXCallUpdate()
        
        callUpdate.remoteHandle = callHandle
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false

        provider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if let error = error {
                NSLog("Failed to report incoming call successfully: \(error.localizedDescription).")
            } else {
                NSLog("Incoming call successfully reported.")
            }
        }
    }
    
    private func endCall() {
        guard let activeCall = activeCall else { return }
        performEndCallAction(uuid: activeCall.uuid!)
    }
    
    private func setupCallKitProvider() {
        let configuration = CXProviderConfiguration(localizedName: "Twilio Voice")
        configuration.supportsVideo = false
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        
        callKitProvider = CXProvider(configuration: configuration)
        callKitProvider?.setDelegate(self, queue: nil)
    }
    
    private func setupAudioDevice() {
        TwilioVoiceSDK.audioDevice = audioDevice
    }
    
    private func performEndCallAction(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callKitCallController.request(transaction) { error in
            if let error = error {
                NSLog("EndCallAction transaction failed: \(error.localizedDescription)")
            } else {
                NSLog("EndCallAction transaction succeeded")
            }
        }
    }
    
    func incomingPushReceived(payload: PKPushPayload) {
        TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
    }
    
    private func updateCallConfiguration(config: TwilioCallConfiguration) {
        NSLog("Updating audio device for speaker: \(config.speakerOn)")
        audioDevice.block = {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                
                // Set category and activate the session
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                // Override audio port if needed
                if config.speakerOn {
                    try audioSession.overrideOutputAudioPort(.speaker)
                } else {
                    try audioSession.overrideOutputAudioPort(.none)
                }
                
                NSLog("Audio session updated successfully. Speaker: \(config.speakerOn)")
            } catch {
                NSLog("Error updating audio session: \(error.localizedDescription)")
            }
        }
        audioDevice.block()
    }
}

// MARK: - CXProviderDelegate
extension TwilioWorker: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        NSLog("CallKit provider reset")
        audioDevice.isEnabled = false
        activeCall = nil
        activeCallInvites.removeAll()
        activeCalls.removeAll()
        twilioStream.updateCallStatus(isCallActive: false, isConnecting: false)
        callKitCompletionCallback = nil
    }
    
    func providerDidBegin(_ provider: CXProvider) {
        NSLog("providerDidBegin")
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        NSLog("provider:didActivateAudioSession:")
        audioDevice.isEnabled = true
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        NSLog("provider:didDeactivateAudioSession:")
        audioDevice.isEnabled = false
    }
    
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        NSLog("provider:timedOutPerformingAction:")
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        NSLog("provider:performStartCallAction:")
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        
        performVoiceCall(uuid: action.callUUID, client: "") { success in
            if success {
                NSLog("performVoiceCall() successful")
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
            } else {
                NSLog("performVoiceCall() failed")
            }
        }
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        NSLog("provider:performAnswerCallAction:")
        performAnswerVoiceCall(uuid: action.callUUID) { success in
            if success {
                NSLog("performAnswerVoiceCall() successful")
            } else {
                NSLog("performAnswerVoiceCall() failed")
            }
        }
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        NSLog("provider:performEndCallAction:")
        if let invite = activeCallInvites[action.callUUID.uuidString] {
            invite.reject()
            activeCallInvites.removeValue(forKey: action.callUUID.uuidString)
        } else if let call = activeCalls[action.callUUID.uuidString] {
            call.disconnect()
        } else {
            NSLog("Unknown UUID to perform end-call action with")
        }
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        NSLog("provider:performSetHeldAction:")
        if let call = activeCalls[action.callUUID.uuidString] {
            call.isOnHold = action.isOnHold
            if !call.isOnHold {
                audioDevice.isEnabled = true
                activeCall = call
            }
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        NSLog("provider:performSetMutedAction:")
        if let call = activeCalls[action.callUUID.uuidString] {
            call.isMuted = action.isMuted
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    private func performVoiceCall(uuid: UUID, client: String, completionHandler: @escaping (Bool) -> Void) {
        let connectOptions = ConnectOptions(accessToken: accessToken) { builder in
            builder.params = [self.twimlParamTo: self.activeOngoing]
            builder.uuid = uuid
        }
        let call = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
        activeCall = call
        activeCalls[call.uuid!.uuidString] = call
        callKitCompletionCallback = completionHandler
    }
    
    private func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Void) {
        guard let callInvite = activeCallInvites[uuid.uuidString] else { return }
        let acceptOptions = AcceptOptions(callInvite: callInvite) { builder in
            builder.uuid = uuid
        }
        let call = callInvite.accept(options: acceptOptions, delegate: self)
        activeCall = call
        activeCalls[call.uuid!.uuidString] = call
        callKitCompletionCallback = completionHandler
        activeCallInvites.removeValue(forKey: uuid.uuidString)
    }
}

extension TwilioWorker: NotificationDelegate {
    func callInviteReceived(callInvite: CallInvite) {
        NSLog("callInviteReceived:")
        
        /**
         * The TTL of a registration is 1 year. The TTL for registration for this device/identity
         * pair is reset to 1 year whenever a new registration occurs or a push notification is
         * sent to this device/identity pair.
         */
        UserDefaults.standard.set(Date(), forKey: kCachedBindingDate)
        
        let callerInfo: TVOCallerInfo = callInvite.callerInfo
        if let verified: NSNumber = callerInfo.verified {
            if verified.boolValue {
                NSLog("Call invite received from verified caller number!")
            }
        }
        
        let from = (callInvite.from ?? "Voice Bot").replacingOccurrences(of: "client:", with: "")

        // Always report to CallKit
        reportIncomingCall(from: from, uuid: callInvite.uuid)
        activeCallInvites[callInvite.uuid.uuidString] = callInvite
    }
    
    func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        NSLog("cancelledCallInviteCanceled:error:, error: \(error.localizedDescription)")

        guard !activeCallInvites.isEmpty else {
            NSLog("No pending call invite")
            return
        }
        
        let callInvite = activeCallInvites.values.first { invite in invite.callSid == cancelledCallInvite.callSid }
        
        if let callInvite = callInvite {
            performEndCallAction(uuid: callInvite.uuid)
            self.activeCallInvites.removeValue(forKey: callInvite.uuid.uuidString)
        }
    }
}

// MARK: - CallDelegate
extension TwilioWorker: CallDelegate {
    func callDidStartRinging(call: Call) {
        NSLog("callDidStartRinging:")
        
        // Update stream status
        twilioStream.updateCallStatus(isCallActive: false, isConnecting: true)
        
//        // Handle custom ringback
//        if playCustomRingback {
//            playRingback()
//        }
    }
    
    func callDidConnect(call: Call) {
        NSLog("callDidConnect:")
        
        // Stop custom ringback if playing
//        if playCustomRingback {
//            stopRingback()
//        }
        
        // Update the stream and active call state
        twilioStream.updateCallStatus(isCallActive: true, isConnecting: false)
        callKitCompletionCallback?(true)
    }
    
    func callIsReconnecting(call: Call, error: Error) {
        NSLog("call:isReconnectingWithError: \(error.localizedDescription)")
        
        // Update stream status
        twilioStream.updateCallStatus(isCallActive: false, isConnecting: true)
    }
    
    func callDidReconnect(call: Call) {
        NSLog("callDidReconnect:")
        
        // Update stream status
        twilioStream.updateCallStatus(isCallActive: true, isConnecting: false)
    }
    
    func callDidFailToConnect(call: Call, error: Error) {
        NSLog("Call failed to connect: \(error.localizedDescription)")
        
        // Report failure to CallKit
        callKitProvider?.reportCall(with: call.uuid!, endedAt: Date(), reason: .failed)
        
        // Update stream status
        twilioStream.updateCallStatus(isCallActive: false, isConnecting: false)
        callKitCompletionCallback?(false)
        callKitCompletionCallback = nil
    }
    
    func callDidDisconnect(call: Call, error: Error?) {
        if let error = error {
            NSLog("Call failed: \(error.localizedDescription)")
        } else {
            NSLog("Call disconnected")
        }
        
        if !userInitiatedDisconnect {
            let reason: CXCallEndedReason = error == nil ? .remoteEnded : .failed
            callKitProvider?.reportCall(with: call.uuid!, endedAt: Date(), reason: reason)
        }
        
        callDisconnected(call: call)
    }
    
    func callDisconnected(call: Call) {
        // Clear the active call and update status
        if call == activeCall {
            activeCall = nil
        }
        
        activeCalls.removeValue(forKey: call.uuid!.uuidString)
        userInitiatedDisconnect = false
        
        twilioStream.updateCallStatus(isCallActive: false, isConnecting: false)
        
//        if playCustomRingback {
//            stopRingback()
//        }
    }
    
    func callDidReceiveQualityWarnings(call: Call, currentWarnings: Set<NSNumber>, previousWarnings: Set<NSNumber>) {
        let warningsIntersection = currentWarnings.intersection(previousWarnings)
        
        let newWarnings = currentWarnings.subtracting(warningsIntersection)
        if !newWarnings.isEmpty {
            qualityWarningsUpdatePopup(newWarnings, isCleared: false)
        }
        
        let clearedWarnings = previousWarnings.subtracting(warningsIntersection)
        if !clearedWarnings.isEmpty {
            qualityWarningsUpdatePopup(clearedWarnings, isCleared: true)
        }
    }
    
    private func qualityWarningsUpdatePopup(_ warnings: Set<NSNumber>, isCleared: Bool) {
        let status = isCleared ? "Warnings cleared" : "Warnings detected"
        let mappedWarnings = warnings.compactMap { Call.QualityWarning(rawValue: $0.uintValue)?.description }
        let message = "\(status): \(mappedWarnings.joined(separator: ", "))"
        
        // Log the quality warning message
        NSLog(message)
    }
}

// MARK: - Ringtone Handling
extension TwilioWorker {
    private func playRingback() {
        let ringtonePath = URL(fileURLWithPath: Bundle.main.path(forResource: "ringtone", ofType: "wav")!)
        
        do {
            let ringtonePlayer = try AVAudioPlayer(contentsOf: ringtonePath)
            ringtonePlayer.numberOfLoops = -1
            ringtonePlayer.volume = 1.0
            ringtonePlayer.play()
        } catch {
            NSLog("Failed to initialize audio player: \(error.localizedDescription)")
        }
    }
    
    private func stopRingback() {
//        if let ringtonePlayer = ringtonePlayer, ringtonePlayer.isPlaying {
//            ringtonePlayer.stop()
//        }
    }
}

// MARK: - Call QualityWarning Descriptions
private extension Call.QualityWarning {
    var description: String {
        switch self {
        case .highRtt: return "High RTT"
        case .highJitter: return "High Jitter"
        case .highPacketsLostFraction: return "High Packet Loss Fraction"
        case .lowMos: return "Low MOS"
        case .constantAudioInputLevel: return "Constant Audio Input Level"
        @unknown default: return "Unknown"
        }
    }
}
