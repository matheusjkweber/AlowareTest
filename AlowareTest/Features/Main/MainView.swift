//
//  MainView.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

import SwiftUI

enum MainViewState {
    case checkingPermissions
    case permissionsDenied
    case idle
    case connecting
    case activeCall
}

struct MainView: View {
    @StateObject var viewModel: MainViewModel
    @State private var recipientNumber: String = ""
    @State private var showSettingsAlert = false
    @State private var showCallErrorAlert = false

    var body: some View {
        VStack(spacing: 20) {
            currentView
            
//            Toggle("Speaker", isOn: $viewModel.isSpeakerEnabled)
//            .onChange(of: viewModel.isSpeakerEnabled) { isOn in
//                viewModel.toggleSpeaker(isOn: isOn)
//            }
        }
        .padding()
        .onAppear {
            if viewModel.state == .permissionsDenied {
                showSettingsAlert = true
            }
        }
        .alert("Microphone Permission Denied", isPresented: $showSettingsAlert) {
            Button("Go to Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to use this feature.")
        }
        .alert("Error Making Call", isPresented: $showCallErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Failed to start the call. Please check the recipient's number and try again.")
        }
    }

    // MARK: - Current View
    private var currentView: some View {
        switch viewModel.state {
        case .checkingPermissions:
            return AnyView(checkingPermissionsView)
        case .permissionsDenied:
            return AnyView(permissionsDeniedView)
        case .idle:
            return AnyView(idleView)
        case .connecting:
            return AnyView(connectingView)
        case .activeCall:
            return AnyView(activeCallView)
        }
    }

    // MARK: - Subviews
    private var checkingPermissionsView: some View {
        ProgressView("Checking permissions...")
    }

    private var permissionsDeniedView: some View {
        Text("Microphone permission is denied. Please enable it in Settings.")
            .multilineTextAlignment(.center)
    }

    private var idleView: some View {
        VStack(spacing: 10) {
            TextField("Enter recipient number", text: $recipientNumber)
                .textFieldStyle(.roundedBorder)
                .padding()
            Button("Make Call") {
                makeCall()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var connectingView: some View {
        ProgressView("Connecting call...")
    }

    private var activeCallView: some View {
        VStack(spacing: 10) {
            Text("Call Active")

            Button("End Call") {
                viewModel.endCall()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helper Methods
    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }

    private func makeCall() {
        guard !recipientNumber.isEmpty else {
            showCallErrorAlert = true
            return
        }
        viewModel.makeCall(to: recipientNumber)
    }
}
