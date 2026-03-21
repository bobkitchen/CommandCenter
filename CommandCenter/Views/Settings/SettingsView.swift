import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var authService
    @State private var notificationSettings = NotificationSettings.load()
    @State private var showAlertHistory = false
    @State private var biometricOn = UserDefaults.standard.bool(forKey: "biometricEnabled")

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient

                List {
                    // Connection
                    Section {
                        HStack {
                            Label("Server", systemImage: "server.rack")
                                .foregroundStyle(AppColors.text)
                            Spacer()
                            Text(authService.serverURL)
                                .font(.caption)
                                .foregroundStyle(AppColors.muted)
                                .lineLimit(1)
                        }
                        .listRowBackground(AppColors.card)
                    } header: {
                        Text("Connection")
                            .foregroundStyle(AppColors.muted)
                    }

                    // Notifications
                    Section {
                        Toggle(isOn: $notificationSettings.gatewayAlerts) {
                            Label("Gateway Down", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(AppColors.text)
                        }
                        .listRowBackground(AppColors.card)
                        .onChange(of: notificationSettings.gatewayAlerts) { notificationSettings.save() }

                        Toggle(isOn: $notificationSettings.contextAlerts) {
                            Label("Context Warnings", systemImage: "chart.bar.fill")
                                .foregroundStyle(AppColors.text)
                        }
                        .listRowBackground(AppColors.card)
                        .onChange(of: notificationSettings.contextAlerts) { notificationSettings.save() }

                        Toggle(isOn: $notificationSettings.processAlerts) {
                            Label("Process Crashes", systemImage: "gearshape.2")
                                .foregroundStyle(AppColors.text)
                        }
                        .listRowBackground(AppColors.card)
                        .onChange(of: notificationSettings.processAlerts) { notificationSettings.save() }

                        Toggle(isOn: $notificationSettings.cronAlerts) {
                            Label("Cron Failures", systemImage: "clock.arrow.circlepath")
                                .foregroundStyle(AppColors.text)
                        }
                        .listRowBackground(AppColors.card)
                        .onChange(of: notificationSettings.cronAlerts) { notificationSettings.save() }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Alert Threshold", systemImage: "gauge.medium")
                                    .foregroundStyle(AppColors.text)
                                Spacer()
                                Text("\(Int(notificationSettings.contextThreshold))%")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppColors.accent)
                            }
                            Slider(
                                value: $notificationSettings.contextThreshold,
                                in: 50...95,
                                step: 5
                            )
                            .tint(AppColors.accent)
                            .onChange(of: notificationSettings.contextThreshold) { notificationSettings.save() }
                        }
                        .listRowBackground(AppColors.card)
                    } header: {
                        Text("Notifications")
                            .foregroundStyle(AppColors.muted)
                    } footer: {
                        Text("Configure which events trigger push notifications.")
                            .foregroundStyle(AppColors.muted)
                    }

                    // Alert History
                    Section {
                        Button {
                            showAlertHistory = true
                        } label: {
                            HStack {
                                Label("Alert History", systemImage: "bell.badge")
                                    .foregroundStyle(AppColors.text)
                                Spacer()
                                Text("\(AlertHistory.shared.alerts.count)")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.muted)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.muted)
                            }
                        }
                        .listRowBackground(AppColors.card)
                    }

                    // Location
                    Section {
                        HStack {
                            Label("Location", systemImage: "location")
                                .foregroundStyle(AppColors.text)
                            Spacer()
                            if let lat = LocationService.shared.latitude,
                               let lon = LocationService.shared.longitude {
                                Text(String(format: "%.2f, %.2f", lat, lon))
                                    .font(.caption)
                                    .foregroundStyle(AppColors.muted)
                            } else {
                                Text("Not available")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                        }
                        .listRowBackground(AppColors.card)

                        Button {
                            LocationService.shared.requestLocation()
                            HapticHelper.light()
                        } label: {
                            Label("Refresh Location", systemImage: "arrow.clockwise")
                                .foregroundStyle(AppColors.accent)
                        }
                        .listRowBackground(AppColors.card)
                    } header: {
                        Text("Location")
                            .foregroundStyle(AppColors.muted)
                    } footer: {
                        Text("Used for local weather data on the dashboard.")
                            .foregroundStyle(AppColors.muted)
                    }

                    // Security
                    if authService.biometricAvailable {
                        Section {
                            Toggle(isOn: $biometricOn) {
                                Label("Unlock with \(authService.biometricLabel)", systemImage: authService.biometricLabel == "Face ID" ? "faceid" : "touchid")
                                    .foregroundStyle(AppColors.text)
                            }
                            .listRowBackground(AppColors.card)
                            .onChange(of: biometricOn) {
                                authService.biometricEnabled = biometricOn
                            }
                        } header: {
                            Text("Security")
                                .foregroundStyle(AppColors.muted)
                        } footer: {
                            Text("Skip the password screen on launch using \(authService.biometricLabel).")
                                .foregroundStyle(AppColors.muted)
                        }
                    }

                    // About
                    Section {
                        HStack {
                            Label("Version", systemImage: "info.circle")
                                .foregroundStyle(AppColors.text)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                                .font(.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                        .listRowBackground(AppColors.card)
                    } header: {
                        Text("About")
                            .foregroundStyle(AppColors.muted)
                    }

                    // Sign Out
                    Section {
                        Button {
                            authService.logout()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .foregroundStyle(AppColors.danger)
                                Spacer()
                            }
                        }
                        .listRowBackground(AppColors.card)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .sheet(isPresented: $showAlertHistory) {
                AlertHistoryView()
            }
        }
    }
}
