import SwiftUI

struct DashboardView: View {
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient

                ScrollView {
                    if #available(iOS 26, *) {
                        GlassEffectContainer(spacing: 16) {
                            dashboardGrid
                        }
                    } else {
                        dashboardGrid
                    }
                }
                .refreshable {
                    refreshID = UUID()
                }
            }
            .navigationTitle("Command Center")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var dashboardGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 16)],
            spacing: 16
        ) {
            WeatherCard()
            CalendarCard()
            CrisisCard()
            StravaCard()
            AgentCard()
            StatusCard()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .id(refreshID)
    }
}
