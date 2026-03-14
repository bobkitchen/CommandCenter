import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var serverURL = ""
    @State private var password = ""

    var body: some View {
        @Bindable var auth = authService

        ZStack {
            AppColors.backgroundGradient

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    Text("🦩")
                        .font(.system(size: 64))

                    Text("Command Center")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppColors.text)

                    Text("Connect to your dashboard")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.muted)
                }

                // Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Server URL")
                            .font(.caption)
                            .foregroundStyle(AppColors.muted)

                        TextField("http://100.74.188.28:8765", text: $serverURL)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(AppColors.text)
                            .padding(12)
                            .glassCard(cornerRadius: 12)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.caption)
                            .foregroundStyle(AppColors.muted)

                        SecureField("Dashboard token", text: $password)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundStyle(AppColors.text)
                            .padding(12)
                            .glassCard(cornerRadius: 12)
                    }
                }
                .padding(.horizontal, 32)

                // Error
                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.danger)
                        .padding(.horizontal, 32)
                }

                // Login button
                Button {
                    authService.serverURL = serverURL
                    authService.password = password
                    Task { await authService.login() }
                } label: {
                    if authService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Connect")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .if(true) { view in
                    if #available(iOS 26, *) {
                        view.buttonStyle(.glassProminent)
                    } else {
                        view
                            .foregroundStyle(.white)
                            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 32)
                .disabled(authService.isLoading || serverURL.isEmpty || password.isEmpty)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            serverURL = authService.serverURL
            password = authService.password
        }
    }
}
