//
//  AppCoordinator.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import SwiftUI

final class AppCoordinator: Coordinator, ObservableObject {
    @Published private var mainCoordinator: MainCoordinator
    
    init() {
        self.mainCoordinator = MainCoordinator()
    }
    
    func start() {
        mainCoordinator.start()
    }
    
    var rootView: some View {
        mainCoordinator.rootView
    }
}
