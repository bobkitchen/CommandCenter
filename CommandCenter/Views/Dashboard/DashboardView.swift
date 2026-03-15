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
                            dashboardContent
                        }
                    } else {
                        dashboardContent
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

    private var dashboardContent: some View {
        VStack(spacing: 16) {
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
