//
//  PushKitStream.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import Combine
import PushKit

// MARK: - PushKit Event Types
enum PushKitOperation {
    case startListening
}

protocol PushKitStreaming {
    var pushOperations: AnyPublisher<PushKitOperation, Never> { get }
    var pushToken: AnyPublisher<Data, Never> { get }
    
    func sendPushToken(_ token: Data)
    func sendPushOperation(_ operation: PushKitOperation)
}

// MARK: - Mutable PushKit Stream
final class PushKitStream: PushKitStreaming {
    private let pushOperationsSubject = PassthroughSubject<PushKitOperation, Never>()
    private let pushTokenSubject = PassthroughSubject<Data, Never>()
    
    var pushOperations: AnyPublisher<PushKitOperation, Never> {
        pushOperationsSubject.eraseToAnyPublisher()
    }
    
    var pushToken: AnyPublisher<Data, Never> {
        pushTokenSubject.eraseToAnyPublisher()
    }
    
    func sendPushToken(_ token: Data) {
        pushTokenSubject.send(token)
    }
    
    func sendPushOperation(_ operation: PushKitOperation) {
        pushOperationsSubject.send(operation)
    }
}
