import Foundation
import LocalAuthentication

@MainActor @Observable
final class AuthService {
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    var errorMessage: String?

    /// Whether the user has opted in to biometric unlock
    var biometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometricEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometricEnabled") }
    }

    /// Whether biometric auth is available on this device
    var biometricAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// "Face ID", "Touch ID", or "Optic ID" depending on device
    var biometricLabel: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Biometrics"
        }
    }

    var serverURL: String {
        get { KeychainHelper.load(key: "server_url") ?? "" }
        set { KeychainHelper.save(newValue, for: "server_url") }
    }

    var password: String {
        get { KeychainHelper.load(key: "password") ?? "" }
        set { KeychainHelper.save(newValue, for: "password") }
    }

    init() {
        if let savedURL = KeychainHelper.load(key: "server_url"), !savedURL.isEmpty {
            APIClient.shared.configure(baseURL: savedURL)
            if biometricEnabled {
                Task { await authenticateWithBiometrics() }
            } else {
                Task { await autoLogin() }
            }
        }
    }

    func login() async {
        isLoading = true
        errorMessage = nil

        APIClient.shared.configure(baseURL: serverURL)

        do {
            let success = try await APIClient.shared.login(password: password)
            if success {
                self.isAuthenticated = true
                KeychainHelper.save(self.serverURL, for: "server_url")
                KeychainHelper.save(self.password, for: "password")
                HapticHelper.success()
            } else {
                self.errorMessage = "Login failed — check your password"
                HapticHelper.error()
            }
            self.isLoading = false
        } catch {
            self.errorMessage = "Unable to connect to server"
            self.isLoading = false
            HapticHelper.error()
        }
    }

    func logout() {
        isAuthenticated = false
        biometricEnabled = false
        KeychainHelper.delete(key: "server_url")
        KeychainHelper.delete(key: "password")
    }

    /// Authenticate using Face ID / Touch ID, then auto-login with stored credentials
    func authenticateWithBiometrics() async {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Command Center"
            )
            if success {
                await autoLogin()
            }
        } catch {
            // User cancelled or biometrics failed — fall through to login screen
        }
    }

    private func autoLogin() async {
        guard !password.isEmpty else { return }
        do {
            let success = try await APIClient.shared.login(password: password)
            self.isAuthenticated = success
        } catch {
            // Silent fail on auto-login
        }
    }
}
