//
//  Coordinator.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import Foundation
import SwiftUICore

protocol Coordinator: ObservableObject {
    associatedtype ContentView: View
    var rootView: ContentView { get }
    func start()
}
