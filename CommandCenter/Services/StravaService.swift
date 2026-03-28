import Foundation
#if os(iOS)
import AuthenticationServices
#endif

/// Direct Strava API access with OAuth2.
/// Tokens stored in Keychain; refreshed automatically when expired.
@MainActor @Observable
final class StravaService {
    static let shared = StravaService()

    private(set) var stats: StravaStats?
    private(set) var activities: [StravaActivity] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var isConnected = false

    // OAuth credentials — set these in Settings
    var clientId: String {
        get { KeychainHelper.load(key: "strava_client_id") ?? "" }
        set { KeychainHelper.save(newValue, for: "strava_client_id") }
    }

    var clientSecret: String {
        get { KeychainHelper.load(key: "strava_client_secret") ?? "" }
        set { KeychainHelper.save(newValue, for: "strava_client_secret") }
    }

    private var accessToken: String? {
        get { KeychainHelper.load(key: "strava_access_token") }
        set {
            if let newValue { KeychainHelper.save(newValue, for: "strava_access_token") }
            else { KeychainHelper.delete(key: "strava_access_token") }
        }
    }

    private var refreshToken: String? {
        get { KeychainHelper.load(key: "strava_refresh_token") }
        set {
            if let newValue { KeychainHelper.save(newValue, for: "strava_refresh_token") }
            else { KeychainHelper.delete(key: "strava_refresh_token") }
        }
    }

    private var tokenExpiry: Date {
        get {
            let ts = UserDefaults.standard.double(forKey: "strava_token_expiry")
            return ts > 0 ? Date(timeIntervalSince1970: ts) : .distantPast
        }
        set { UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "strava_token_expiry") }
    }

    private let session = URLSession.shared
    private let baseAPI = "https://www.strava.com/api/v3"

    init() {
        isConnected = accessToken != nil && !clientId.isEmpty
    }

    // MARK: - OAuth Flow

    #if os(iOS)
    func authenticate(from window: UIWindow) async {
        guard !clientId.isEmpty else {
            error = "Set your Strava Client ID in Settings first"
            return
        }

        let redirectURI = "commandcenter://localhost/exchange_token"
        let scope = "activity:read_all,profile:read_all"
        let authURL = "https://www.strava.com/oauth/authorize"
            + "?client_id=\(clientId)"
            + "&redirect_uri=\(redirectURI)"
            + "&response_type=code"
            + "&approval_prompt=auto"
            + "&scope=\(scope)"

        guard let url = URL(string: authURL) else {
            error = "Invalid auth URL"
            return
        }

        do {
            let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "commandcenter"
                ) { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let url {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: StravaError.invalidResponse)
                    }
                }
                let contextProvider = WebAuthContextProvider(anchor: window)
                session.presentationContextProvider = contextProvider
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }

            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                error = "No authorization code received"
                return
            }

            await exchangeToken(code: code)
        } catch {
            if (error as NSError).code == 1 { return } // User cancelled
            self.error = "Auth failed: \(error.localizedDescription)"
        }
    }
    #endif

    func exchangeToken(code: String) async {
        guard let url = URL(string: "https://www.strava.com/oauth/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await session.data(for: request)
            try handleTokenResponse(data)
            isConnected = true
            await fetchData()
        } catch {
            self.error = "Token exchange failed: \(error.localizedDescription)"
        }
    }

    private func refreshAccessToken() async -> Bool {
        guard let refresh = refreshToken, !clientId.isEmpty, !clientSecret.isEmpty else { return false }
        guard let url = URL(string: "https://www.strava.com/oauth/token") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refresh,
            "grant_type": "refresh_token"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await session.data(for: request)
            try handleTokenResponse(data)
            return true
        } catch {
            print("[Strava] Refresh failed: \(error)")
            return false
        }
    }

    private func handleTokenResponse(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StravaError.invalidResponse
        }
        if let accessToken = json["access_token"] as? String {
            self.accessToken = accessToken
        }
        if let refreshToken = json["refresh_token"] as? String {
            self.refreshToken = refreshToken
        }
        if let expiresAt = json["expires_at"] as? Double {
            self.tokenExpiry = Date(timeIntervalSince1970: expiresAt)
        }
    }

    // MARK: - Data Fetching

    func fetchData() async {
        guard isConnected else {
            error = "Not connected to Strava"
            return
        }

        isLoading = true
        error = nil

        // Refresh token if expired
        if Date() >= tokenExpiry {
            let refreshed = await refreshAccessToken()
            if !refreshed {
                error = "Session expired — reconnect Strava"
                isConnected = false
                isLoading = false
                return
            }
        }

        // Fetch activities and stats in parallel
        async let activitiesResult = fetchActivities()
        async let statsResult = fetchStats()

        activities = await activitiesResult
        stats = await statsResult
        isLoading = false
    }

    private func fetchActivities() async -> [StravaActivity] {
        guard let data = await apiGet("/athlete/activities?per_page=5") else { return [] }
        do {
            return try JSONDecoder().decode([StravaActivity].self, from: data)
        } catch {
            print("[Strava] Activities decode error: \(error)")
            return []
        }
    }

    private func fetchStats() async -> StravaStats? {
        // Need athlete ID first
        guard let athleteData = await apiGet("/athlete"),
              let athlete = try? JSONSerialization.jsonObject(with: athleteData) as? [String: Any],
              let athleteId = athlete["id"] as? Int else {
            return nil
        }

        guard let data = await apiGet("/athletes/\(athleteId)/stats") else { return nil }
        do {
            return try JSONDecoder().decode(StravaStats.self, from: data)
        } catch {
            print("[Strava] Stats decode error: \(error)")
            return nil
        }
    }

    private func apiGet(_ path: String) async -> Data? {
        guard let token = accessToken,
              let url = URL(string: "\(baseAPI)\(path)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                // Token expired mid-request
                let refreshed = await refreshAccessToken()
                if refreshed { return await apiGet(path) }
                return nil
            }
            return data
        } catch {
            print("[Strava] API error on \(path): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = .distantPast
        stats = nil
        activities = []
        isConnected = false
        KeychainHelper.delete(key: "strava_client_id")
        KeychainHelper.delete(key: "strava_client_secret")
    }
}

private enum StravaError: Error {
    case invalidResponse
}

#if os(iOS)
private final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
#endif
