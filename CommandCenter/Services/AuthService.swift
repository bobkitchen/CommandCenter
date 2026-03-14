import Foundation

@Observable
final class AuthService {
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    var errorMessage: String?

    var serverURL: String {
        get { KeychainHelper.load(key: "server_url") ?? "http://100.74.188.28:8765" }
        set { KeychainHelper.save(newValue, for: "server_url") }
    }

    var password: String {
        get { KeychainHelper.load(key: "password") ?? "a6f02a18250e3080e26e747b7b64e874" }
        set { KeychainHelper.save(newValue, for: "password") }
    }

    init() {
        // Auto-login if credentials exist
        if KeychainHelper.load(key: "server_url") != nil {
            APIClient.shared.configure(baseURL: serverURL)
            Task { await autoLogin() }
        }
    }

    func login() async {
        isLoading = true
        errorMessage = nil

        APIClient.shared.configure(baseURL: serverURL)

        do {
            let success = try await APIClient.shared.login(password: password)
            await MainActor.run {
                if success {
                    self.isAuthenticated = true
                    KeychainHelper.save(self.serverURL, for: "server_url")
                    KeychainHelper.save(self.password, for: "password")
                } else {
                    self.errorMessage = "Login failed — check your password"
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
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
            await MainActor.run {
                self.isAuthenticated = success
            }
        } catch {
            // Silent fail on auto-login
        }
    }
}
