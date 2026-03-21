import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @Environment(\.scenePhase) private var scenePhase
    @State private var serverURL = ""
    @State private var password = ""
    @State private var connectivity = ConnectivityService()
    @State private var urlDebounce: Task<Void, Never>?

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
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .keyboardType(.URL)
                            #endif
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
                .modifier(GlassButtonStyle())
                .padding(.horizontal, 32)
                .disabled(authService.isLoading || serverURL.isEmpty || password.isEmpty)

                // Biometric unlock
                if authService.biometricEnabled && !authService.password.isEmpty {
                    Button {
                        Task { await authService.authenticateWithBiometrics() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: authService.biometricLabel == "Face ID" ? "faceid" : "touchid")
                            Text("Unlock with \(authService.biometricLabel)")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(AppColors.accent)
                    }
                    .padding(.top, 4)
                }

                // Connectivity status — fixed layout to prevent jitter
                connectivityIndicator
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            serverURL = authService.serverURL
            password = authService.password
            // Default URL for first launch
            if serverURL.isEmpty {
                serverURL = "http://100.74.188.28:8765"
            }
            // Start monitoring
            if serverURL.hasPrefix("http") {
                connectivity.startMonitoring(serverURL: serverURL)
            } else {
                connectivity.state = .disconnected
            }
        }
        .onDisappear {
            connectivity.stopMonitoring()
            urlDebounce?.cancel()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, !serverURL.isEmpty, serverURL.hasPrefix("http") {
                Task { await connectivity.check(serverURL: serverURL) }
            }
        }
        .onChange(of: serverURL) {
            // Debounce URL changes — only restart monitoring after user stops typing
            urlDebounce?.cancel()
            guard !serverURL.isEmpty, serverURL.hasPrefix("http") else {
                connectivity.stopMonitoring()
                return
            }
            urlDebounce = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                connectivity.stopMonitoring()
                connectivity.startMonitoring(serverURL: serverURL)
            }
        }
    }

    @ViewBuilder
    private var connectivityIndicator: some View {
        // Always show the disconnected layout structure to prevent height changes
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if connectivity.state == .checking {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking connection...")
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Circle()
                        .fill(connectivity.state == .connected ? AppColors.success : AppColors.danger)
                        .frame(width: 8, height: 8)
                    Text(connectivity.state == .connected ? "Server reachable" : "Server unreachable")
                        .font(.caption)
                        .foregroundStyle(connectivity.state == .connected ? AppColors.success : AppColors.danger)
                }
            }

            if connectivity.state == .disconnected {
                HStack(spacing: 12) {
                    Button {
                        connectivity.openTailscale()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "network")
                            Text("Open Tailscale")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(AppColors.accent)
                    }

                    Button {
                        connectivity.state = .checking
                        Task { await connectivity.check(serverURL: serverURL) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(AppColors.muted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .glassCard(cornerRadius: 12)
            }
        }
    }
}
