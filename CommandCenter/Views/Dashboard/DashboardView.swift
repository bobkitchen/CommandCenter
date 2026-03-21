import SwiftUI

struct DashboardView: View {
    @State private var refreshID = UUID()
    @State private var monitor = OpenClawMonitor()
    @State private var config = DashboardConfig.shared
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient

                ScrollView {
                    #if os(iOS)
                    if #available(iOS 26, *) {
                        GlassEffectContainer(spacing: 16) {
                            dashboardContent
                        }
                    } else {
                        dashboardContent
                    }
                    #else
                    dashboardContent
                    #endif
                }
                .refreshable {
                    await monitor.refresh()
                    refreshID = UUID()
                }
            }
            .navigationTitle("Command Center")
            #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticHelper.light()
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(AppColors.muted)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        HapticHelper.light()
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(AppColors.muted)
                    }
                }
                #endif
            }
            .sheet(isPresented: $showSettings) {
                DashboardSettingsSheet(config: config)
            }
        }
        .task {
            monitor.startMonitoring()
            NotificationService.shared.requestPermission()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
    }

    private var dashboardContent: some View {
        VStack(spacing: 16) {
            // Health banner — always visible at top
            HealthBanner(monitor: monitor)

            // Dynamic cards based on user config
            ForEach(config.visibleCards) { card in
                cardView(for: card)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .id(refreshID)
    }

    @ViewBuilder
    private func cardView(for card: DashboardCard) -> some View {
        switch card {
        case .status:
            StatusCard(monitor: monitor)
        case .tokenUsage:
            TokenCard(monitor: monitor)
        case .activityFeed:
            ActivityFeedCard(monitor: monitor)
        case .quickActions:
            QuickActionsCard(monitor: monitor)
        case .crises:
            CrisisCard()
        case .memory:
            MemoryCard()
        case .calendar:
            CalendarCard()
        case .weather:
            WeatherCard()
        case .strava:
            StravaCard()
        }
    }
}
