import Foundation
import SwiftUI

enum ConnectivityState {
    case checking
    case connected
    case disconnected
}

@MainActor @Observable
final class ConnectivityService {
    var state: ConnectivityState = .checking
    private var pollTask: Task<Void, Never>?

    func startMonitoring(serverURL: String) {
        stopMonitoring()
        state = .checking
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check(serverURL: serverURL)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopMonitoring() {
        pollTask?.cancel()
        pollTask = nil
    }

    func check(serverURL: String) async {
        let trimmed = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/api/openclaw-status") else {
            state = .disconnected
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 4

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
                state = .connected
            } else {
                state = .disconnected
            }
        } catch {
            state = .disconnected
        }
    }

    func openTailscale() {
        if let url = URL(string: "tailscale://") {
            UIApplication.shared.open(url)
        }
    }
}
