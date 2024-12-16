//
//  PermissionWorker.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import AVFoundation

final class PermissionWorker: Worker {
    private let mutablePermissionStream: MutablePermissionStreaming
    
    init(mutablePermissionStream: MutablePermissionStreaming) {
        self.mutablePermissionStream = mutablePermissionStream
    }
    
    func start() {
        checkMicrophonePermission()
    }
    
    private func checkMicrophonePermission() {
        if #available(iOS 17.0, *) {
            // Use the new method for iOS 17 and above
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                self?.mutablePermissionStream.update(audioPermissionStatus: granted)
            }
        } else {
            // Fallback for earlier versions
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                self?.mutablePermissionStream.update(audioPermissionStatus: granted)
            }
        }
    }
}
