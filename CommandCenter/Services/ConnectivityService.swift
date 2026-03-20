import Foundation
import SwiftUI

enum ConnectivityState: Equatable {
    case checking
    case connected
    case disconnected
}

@MainActor @Observable
final class ConnectivityService {
    var state: ConnectivityState = .checking
    private var pollTask: Task<Void, Never>?

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config)
    }()

    /// Start monitoring — only polls while connected.
    /// When disconnected, stops polling to avoid nw_connection spam.
    /// Use `check()` manually to re-check (e.g. on scenePhase change).
    func startMonitoring(serverURL: String) {
        stopMonitoring()
        pollTask = Task { [weak self] in
            // Initial check
            await self?.performCheck(serverURL: serverURL)
            // Only keep polling if connected
            while !Task.isCancelled, self?.state == .connected {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await self?.performCheck(serverURL: serverURL)
            }
        }
    }

    func stopMonitoring() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Single connectivity check — called on demand
    func check(serverURL: String) async {
        await performCheck(serverURL: serverURL)
        // If we just became connected, restart polling
        if state == .connected {
            startMonitoring(serverURL: serverURL)
        }
    }

    func openTailscale() {
        if let url = URL(string: "tailscale://") {
            UIApplication.shared.open(url)
        }
    }

    private func performCheck(serverURL: String) async {
        let trimmed = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/api/openclaw-status") else {
            setIfChanged(.disconnected)
            return
        }

        do {
            let (_, response) = try await session.data(for: URLRequest(url: url))
            if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
                setIfChanged(.connected)
            } else {
                setIfChanged(.disconnected)
            }
        } catch {
            setIfChanged(.disconnected)
        }
    }

    private func setIfChanged(_ newState: ConnectivityState) {
        if state != newState {
            state = newState
        }
    }
}
