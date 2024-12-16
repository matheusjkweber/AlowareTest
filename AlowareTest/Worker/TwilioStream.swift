//
//  TwilioStream.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import Combine
import PushKit

public protocol TwilioStreaming {
    var callOperation: AnyPublisher<TwilioCallOperation?, Never> { get }
    var callConfiguration: AnyPublisher<TwilioCallConfiguration, Never> { get }
    var callStatusPublisher: AnyPublisher<(isCallActive: Bool, isConnecting: Bool), Never> { get }
    var incomingPushPayload: AnyPublisher<PKPushPayload, Never> { get }
}

public protocol MutableTwilioStreaming: TwilioStreaming {
    func updateCallOperation(_ operation: TwilioCallOperation?)
    func updateCallConfiguration(_ config: TwilioCallConfiguration)
    func updateCallStatus(isCallActive: Bool, isConnecting: Bool)
    func sendPushPayload(_ payload: PKPushPayload)
}

public enum TwilioCallOperation {
    case makeCall(recipient: String)
    case endCall
}

public struct TwilioCallConfiguration: Equatable {
    let speakerOn: Bool
}

final class TwilioStream: MutableTwilioStreaming {
    // MARK: - Published Properties
    @Published private var operation: TwilioCallOperation? = nil
    @Published private(set) var isCallActive: Bool = false
    @Published private(set) var isConnecting: Bool = false
    private var configurationSubject = CurrentValueSubject<TwilioCallConfiguration, Never>(TwilioCallConfiguration(speakerOn: false))

    private let incomingPushPayloadSubject = PassthroughSubject<PKPushPayload, Never>()

    // MARK: - Publishers
    var callOperation: AnyPublisher<TwilioCallOperation?, Never> {
        $operation.eraseToAnyPublisher()
    }
    
    var callConfiguration: AnyPublisher<TwilioCallConfiguration, Never> {
        configurationSubject.eraseToAnyPublisher()
    }
    
    var callStatusPublisher: AnyPublisher<(isCallActive: Bool, isConnecting: Bool), Never> {
        $isCallActive.combineLatest($isConnecting)
            .map { (isCallActive: $0.0, isConnecting: $0.1) }
            .eraseToAnyPublisher()
    }
    
    var incomingPushPayload: AnyPublisher<PKPushPayload, Never> {
        incomingPushPayloadSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Public Methods
    func updateCallOperation(_ operation: TwilioCallOperation?) {
        self.operation = operation
    }
    
    func updateCallConfiguration(_ config: TwilioCallConfiguration) {
        configurationSubject.send(config)
    }
    
    func updateCallStatus(isCallActive: Bool, isConnecting: Bool) {
        self.isCallActive = isCallActive
        self.isConnecting = isConnecting
    }
    
    func sendPushPayload(_ payload: PKPushPayload) {
        incomingPushPayloadSubject.send(payload)
    }
}
