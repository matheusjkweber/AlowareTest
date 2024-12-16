//
//  MainViewModel.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import Foundation
import Combine

final class MainViewModel: ObservableObject {
    @Published var state: MainViewState = .checkingPermissions
    @Published var isCallActive = false
    @Published var isConnecting = false
    @Published var isSpeakerEnabled = false

    private let permissionStream: PermissionStreaming
    private let twilioStream: MutableTwilioStreaming
    private var cancellables = Set<AnyCancellable>()
    
    init(permissionStream: PermissionStreaming, twilioStream: MutableTwilioStreaming) {
        self.permissionStream = permissionStream
        self.twilioStream = twilioStream
        start()
    }
    
    private func start() {
        subscribeToStreams()
    }
    
    private func subscribeToStreams() {
        // Observe microphone permissions
        permissionStream.askMicrophonePermission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                self?.state = granted ? .idle : .permissionsDenied
            }
            .store(in: &cancellables)
        
        // Observe call status
        twilioStream.callStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                self.isCallActive = status.isCallActive
                self.isConnecting = status.isConnecting
                self.updateState()
            }
            .store(in: &cancellables)
    }
    
    private func updateState() {
        if isConnecting {
            state = .connecting
        } else if isCallActive {
            state = .activeCall
        } else {
            state = .idle
        }
    }
    
    func makeCall(to recipient: String) {
        twilioStream.updateCallOperation(.makeCall(recipient: recipient))
    }
    
    func endCall() {
        twilioStream.updateCallOperation(.endCall)
    }
    
    func toggleSpeaker(isOn: Bool) {
        twilioStream.updateCallConfiguration(TwilioCallConfiguration(speakerOn: isOn))
    }
}
