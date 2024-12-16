//
//  PushKitWorker.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import Foundation
import Combine
import PushKit
import TwilioVoice

final class PushKitWorker: NSObject, Worker, PKPushRegistryDelegate {
    // MARK: - Properties
    private let pushKitStream: PushKitStreaming
    private let twilioStream: MutableTwilioStreaming
    
    private let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    private var cancellables = Set<AnyCancellable>()
    private let accessToken: String
    
    // MARK: - Initialization
    init(mutablePushKitStream: PushKitStreaming, mutableTwilioStream: MutableTwilioStreaming) {
        guard let accessToken = Bundle.main.object(forInfoDictionaryKey: "TwilioAccessToken") as? String else {
            fatalError("TwilioAccessToken is missing in Info.plist")
        }
        self.pushKitStream = mutablePushKitStream
        self.twilioStream = mutableTwilioStream
        self.accessToken = accessToken
        super.init()
    }
    
    // MARK: - Worker Protocol
    func start() {
        observeStream()
        NSLog("PushKitWorker started")
    }
    
    // MARK: - Private Methods
    private func observeStream() {
        // Observe push operations and handle them
        pushKitStream.pushOperations
            .sink { [weak self] operation in
                switch operation {
                case .startListening:
                    self?.initializePushKit()
                }
            }
            .store(in: &cancellables)
        
        pushKitStream.pushToken
            .sink { [weak self] token in
                guard !token.isEmpty else { return }
                self?.registerWithTwilio(deviceToken: token)
            }
            .store(in: &cancellables)
    }
    
    private func initializePushKit() {
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
        NSLog("PushKit initialized and listening for VoIP pushes")
    }
    
    // MARK: - PKPushRegistryDelegate
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        NSLog("Push token updated: \(pushCredentials.token)")
        pushKitStream.sendPushToken(pushCredentials.token)
        let deviceToken = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
            NSLog("VoIP Device Token: \(deviceToken)")
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        NSLog("Push token invalidated")
        pushKitStream.sendPushToken(Data()) // Sending empty Data to signify invalidation
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        NSLog("Incoming VoIP push received")
        twilioStream.sendPushPayload(payload)
    }
    
    private func registerWithTwilio(deviceToken: Data) {
        TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: deviceToken) { error in
            if let error = error {
                NSLog("Failed to register VoIP token with Twilio: \(error.localizedDescription)")
            } else {
                NSLog("Successfully registered for VoIP push notifications with Twilio.")
            }
        }
    }
}
