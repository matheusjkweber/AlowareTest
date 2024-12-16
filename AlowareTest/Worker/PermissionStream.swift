//
//  PermissionStream.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import Combine

public protocol PermissionStreaming {
    var askedPermission: Bool { get set }
    var currentPermissions: Set<PermissionType> { get set }
    var askMicrophonePermission: AnyPublisher<Bool, Never> { get }
}

public protocol MutablePermissionStreaming: PermissionStreaming {
    func update(audioPermissionStatus: Bool)
}

public enum PermissionType {
    case audio
}

final class PermissionStream: MutablePermissionStreaming {
    @Published var askedPermission = false
    @Published var currentPermissions: Set<PermissionType> = []
    
    private let microphonePermissionSubject = CurrentValueSubject<Bool, Never>(false)
    
    var askMicrophonePermission: AnyPublisher<Bool, Never> {
        microphonePermissionSubject.eraseToAnyPublisher()
    }
    
    func update(audioPermissionStatus: Bool) {
        askedPermission = true
        microphonePermissionSubject.send(audioPermissionStatus)
        if audioPermissionStatus {
            currentPermissions.insert(.audio)
        }
    }
}
