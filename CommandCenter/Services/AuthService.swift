import Foundation

@MainActor @Observable
final class AuthService {
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    var errorMessage: String?

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
            Task { await autoLogin() }
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
        KeychainHelper.delete(key: "server_url")
        KeychainHelper.delete(key: "password")
    }

    private func autoLogin() async {
        do {
            let success = try await APIClient.shared.login(password: password)
            self.isAuthenticated = success
        } catch {
            // Silent fail on auto-login
        }
    }
}
