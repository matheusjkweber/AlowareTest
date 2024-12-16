//
//  AlowareTestApp.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import SwiftUI

@main
struct AlowareTestApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
        
    var body: some Scene {
        WindowGroup {
            appCoordinator.rootView
                .onAppear {
                    appCoordinator.start()
                }
        }
    }
}
