//
//  VTSetupView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-03.
//

import SwiftUI
import Defaults

struct VTSetupView: View {
    @State private var viewModel = QuotaStatusViewModel()

    @Default(.userName) private var userName: String

    @AppStorage("didShowAPIKeychainNotice") private var didShowAPIKeychainNotice = false
    @State private var apiKey: String = ""
    @State private var showSecret: Bool = false
    @State private var buttonIsLoading: Bool = false
    @State private var isAlertPresented: Bool = false
    @State private var isKeychainNoticePresented = false
    @State private var alertTitle: LocalizedStringKey?
    @State private var alertMessage = ""

    var body: some View {
        Form {
            Section {
                secretTextField
                userNameTextField
            } footer: {
                Button(action: verifyInput) {
                    buttonContent
                }
                .disabled(isButtonDisabled())
            }
            .alert(alertTitle ?? "", isPresented: $isAlertPresented) {
                Button("settings.api.alert.button") {
                    reset()
                }
            } message: {
                Text(alertMessage)
            }
            .alert("settings.api.keychain.notice.title", isPresented: $isKeychainNoticePresented) {
                Button("settings.api.keychain.notice.cancel", role: .cancel) {}
                Button("settings.api.keychain.notice.continue") {
                    didShowAPIKeychainNotice = true
                    saveAndVerifyAPIKey()
                }
            } message: {
                Text("settings.api.keychain.notice.message")
            }
            .onChange(of: viewModel.statusSuccess) { _, newValue in
                switch newValue {
                case true:
                    alertTitle = "settings.api.verify.success"
                    alertMessage = String(localized: "settings.api.message.success")
                    buttonIsLoading = false
                    isAlertPresented = true
                case false:
                    alertTitle = "settings.api.verify.failed"
                    alertMessage = viewModel.errorMessage ?? String(localized: "settings.api.message.failed")
                    buttonIsLoading = false
                    isAlertPresented = true
                default:
                    break
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onAppear {
            apiKey = APIKeychain.apiKey
        }
    }

    // MARK: ViewBuilder

    @ViewBuilder
    private var secretTextField: some View {
        HStack {
            if showSecret {
                TextField("settings.api.key",
                          text: $apiKey,
                          prompt: Text(apiKeyPlaceholder))
                .lineLimit(1)
            } else {
                SecureField("settings.api.key",
                            text: $apiKey,
                            prompt: Text(apiKeyPlaceholder))
                .lineLimit(1)
            }
            Button(action: toggleShowSecret) {
                Image(systemName: showSecret ? "eye.slash.fill" : "eye.fill")
            }
        }
    }

    @ViewBuilder
    private var userNameTextField: some View {
        VStack(alignment: .center) {
            TextField("settings.api.username",
                      text: $userName,
                      prompt: Text(userNamePlaceholder))
            .frame(height: 36)
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var buttonContent: some View {
        switch buttonIsLoading {
        case true:
            ProgressView()
                .controlSize(.small)
        case false:
            Text("settings.api.verify")
        }
    }

    // MARK: Private

    private let apiKeyPlaceholder: LocalizedStringKey = "settings.api.key.placeholder"
    private let userNamePlaceholder: LocalizedStringKey = "settings.api.username.placeholder"

    /// Toggle showSecret
    private func toggleShowSecret() {
        showSecret.toggle()
    }

    /// Triggers verification
    private func verifyInput() {
        if shouldShowKeychainNotice() {
            isKeychainNoticePresented = true
            return
        }

        saveAndVerifyAPIKey()
    }

    private func saveAndVerifyAPIKey() {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = trimmedAPIKey
        userName = trimmedUserName

        guard saveAPIKey(trimmedAPIKey) else { return }
        buttonIsLoading = true
        viewModel.retryRequest()
    }

    @discardableResult
    private func saveAPIKey(_ newValue: String) -> Bool {
        do {
            try APIKeychain.saveAPIKey(newValue)
            return true
        } catch {
            log.error(error)
            alertTitle = "settings.api.verify.failed"
            alertMessage = error.localizedDescription
            buttonIsLoading = false
            isAlertPresented = true
            return false
        }
    }

    private func shouldShowKeychainNotice() -> Bool {
        !didShowAPIKeychainNotice && !apiKey.isEmpty
    }

    /// Reset after button is pressed in alert
    private func reset() {
        isAlertPresented = false
        alertTitle = nil
        alertMessage = ""
    }

    /// Return true if any one of apiKey or userName is empty, return false otherwise
    private func isButtonDisabled() -> Bool {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    VTSetupView()
        .frame(width: 500, height: 400)
}
