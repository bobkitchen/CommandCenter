import SwiftUI

struct DashboardSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let config: DashboardConfig

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient

                List {
                    // Theme
                    Section {
                        Picker("Theme", selection: Binding(
                            get: { AppTheme.shared.mode },
                            set: { AppTheme.shared.mode = $0 }
                        )) {
                            ForEach(ThemeMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(AppColors.card)
                    } header: {
                        Text("Appearance")
                            .foregroundStyle(AppColors.muted)
                    }

                    // Card order
                    Section {
                        ForEach(config.cardOrder) { card in
                            HStack(spacing: 12) {
                                Image(systemName: card.icon)
                                    .font(.body)
                                    .foregroundStyle(config.hiddenCards.contains(card) ? AppColors.muted : AppColors.accent)
                                    .frame(width: 24)

                                Text(card.rawValue)
                                    .font(.body)
                                    .foregroundStyle(config.hiddenCards.contains(card) ? AppColors.muted : AppColors.text)

                                Spacer()

                                Button {
                                    withAnimation { config.toggleCard(card) }
                                } label: {
                                    Image(systemName: config.hiddenCards.contains(card) ? "eye.slash" : "eye")
                                        .font(.body)
                                        .foregroundStyle(config.hiddenCards.contains(card) ? AppColors.muted : AppColors.success)
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowBackground(AppColors.card)
                        }
                        .onMove { source, destination in
                            config.moveCard(from: source, to: destination)
                        }
                    } header: {
                        Text("Card Order (drag to reorder)")
                            .foregroundStyle(AppColors.muted)
                    }

                    // Notifications
                    Section {
                        Button {
                            NotificationService.shared.requestPermission()
                            HapticHelper.success()
                        } label: {
                            HStack {
                                Image(systemName: "bell.badge")
                                    .foregroundStyle(AppColors.accent)
                                Text("Enable Notifications")
                                    .foregroundStyle(AppColors.text)
                            }
                        }
                        .listRowBackground(AppColors.card)
                    } header: {
                        Text("Alerts")
                            .foregroundStyle(AppColors.muted)
                    } footer: {
                        Text("Get notified when gateway goes down, context exceeds 85%, or processes crash.")
                            .foregroundStyle(AppColors.muted)
                    }

                    // Reset
                    Section {
                        Button {
                            withAnimation {
                                config.resetToDefaults()
                                AppTheme.shared.mode = .dark
                            }
                            HapticHelper.light()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(AppColors.danger)
                                Text("Reset to Defaults")
                                    .foregroundStyle(AppColors.danger)
                            }
                        }
                        .listRowBackground(AppColors.card)
                    }
                }
                .scrollContentBackground(.hidden)
                #if os(iOS)
                .environment(\.editMode, .constant(.active))
                #endif
            }
            .navigationTitle("Dashboard Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 500, idealHeight: 600)
        #endif
    }
}
