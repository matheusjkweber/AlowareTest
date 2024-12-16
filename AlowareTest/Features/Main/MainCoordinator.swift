//
//  MainCoordinator.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import SwiftUI

final class MainCoordinator: Coordinator, ObservableObject {
    @Published private var permissionStream: PermissionStream
    @Published private var twilioStream: TwilioStream
    @Published private var pushKitStream: PushKitStream
    
    private var workers: [AnyWorker] = []
    
    init() {
        self.permissionStream = PermissionStream()
        self.twilioStream = TwilioStream()
        self.pushKitStream = PushKitStream()
        
        self.workers = [
            AnyWorker(PermissionWorker(mutablePermissionStream: permissionStream)),
            AnyWorker(TwilioWorker(mutableTwilioStream: twilioStream)),
            AnyWorker(PushKitWorker(mutablePushKitStream: pushKitStream, mutableTwilioStream: twilioStream))
        ]
    }
    
    func start() {
        workers.forEach { $0.start() }
        
        pushKitStream.sendPushOperation(.startListening)
    }
    
    var rootView: some View {
        MainView(
            viewModel: MainViewModel(
                permissionStream: self.permissionStream,
                twilioStream: self.twilioStream
            )
        )
    }
}
