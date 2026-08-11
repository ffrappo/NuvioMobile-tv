import Foundation

struct NuvioAccountService {
    static let baseURL = URL(string: "https://api.nuvio.tv")!
    static let webLoginURL = "https://nuvio.tv/tv-login"
    static let anonKey = "sb_publishable_1Clq8rlTVACkdcZuqr6_AD__xUUC_EN"

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func signIn(email: String, password: String) async throws -> TokenResponse {
        try await request(
            path: "/auth/v1/token?grant_type=password",
            body: ["email": email, "password": password]
        )
    }

    func refresh(token: String) async throws -> TokenResponse {
        try await request(
            path: "/auth/v1/token?grant_type=refresh_token",
            body: ["refresh_token": token]
        )
    }

    func user(accessToken: String) async throws -> AuthUser {
        var request = URLRequest(url: Self.baseURL.appending(path: "/auth/v1/user"))
        request.httpMethod = "GET"
        addHeaders(to: &request, accessToken: accessToken)
        return try await execute(request)
    }

    func signOut(accessToken: String) async throws {
        var request = URLRequest(url: Self.baseURL.appending(path: "/auth/v1/logout"))
        request.httpMethod = "POST"
        addHeaders(to: &request, accessToken: accessToken)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.invalidResponse
        }
    }

    func startTVLogin(nonce: String, deviceName: String) async throws -> TVLoginStart {
        let rows: [TVLoginStart] = try await request(
            path: "/rest/v1/rpc/start_tv_login_session",
            body: [
                "p_device_nonce": nonce,
                "p_redirect_base_url": Self.webLoginURL,
                "p_device_name": deviceName,
            ]
        )
        guard let first = rows.first else { throw AuthError.invalidResponse }
        return first
    }

    func pollTVLogin(code: String, nonce: String) async throws -> TVLoginPoll {
        let rows: [TVLoginPoll] = try await request(
            path: "/rest/v1/rpc/poll_tv_login_session",
            body: ["p_code": code, "p_device_nonce": nonce]
        )
        guard let first = rows.first else { throw AuthError.invalidResponse }
        return first
    }

    func exchangeTVLogin(code: String, nonce: String) async throws -> TokenResponse {
        try await request(
            path: "/functions/v1/tv-logins-exchange",
            body: ["code": code, "device_nonce": nonce]
        )
    }

    func effectiveOwner(accessToken: String) async throws -> String {
        try await request(
            path: "/rest/v1/rpc/get_sync_owner",
            body: [String: String](),
            accessToken: accessToken
        )
    }

    func addons(accessToken: String, ownerID: String, profileID: Int = 1) async throws -> [SyncedAddon] {
        var components = URLComponents(
            url: Self.baseURL.appending(path: "/rest/v1/addons"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "select", value: "url,name,enabled,sort_order"),
            URLQueryItem(name: "user_id", value: "eq.\(ownerID)"),
            URLQueryItem(name: "profile_id", value: "eq.\(profileID)"),
            URLQueryItem(name: "order", value: "sort_order.asc"),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        addHeaders(to: &request, accessToken: accessToken)
        return try await execute(request)
    }

    func profileSettings(accessToken: String, profileID: Int = 1) async throws -> TVIntegrationSettings? {
        let params = ["p_profile_id": profileID, "p_platform": "mobile"] as [String: Any]
        let body = try JSONSerialization.data(withJSONObject: params)
        var request = URLRequest(url: Self.baseURL.appending(path: "/rest/v1/rpc/sync_pull_profile_settings_blob"))
        request.httpMethod = "POST"
        addHeaders(to: &request, accessToken: accessToken)
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.invalidResponse
        }
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let settingsJSON = rows.first?["settings_json"] as? [String: Any],
              let features = settingsJSON["features"] as? [String: Any],
              let player = features["player_settings"] as? [String: Any] else { return nil }
        return TVIntegrationSettings(
            skipIntroEnabled: syncBoolean("skip_intro_enabled", in: player) ?? true,
            animeSkipEnabled: syncBoolean("animeskip_enabled", in: player) ?? false,
            animeSkipClientID: syncString("animeskip_client_id", in: player) ?? ""
        )
    }

    private func syncBoolean(_ key: String, in payload: [String: Any]) -> Bool? {
        (payload[key] as? [String: Any])?["value"] as? Bool
    }

    private func syncString(_ key: String, in payload: [String: Any]) -> String? {
        (payload[key] as? [String: Any])?["value"] as? String
    }

    private func request<T: Decodable, B: Encodable>(
        path: String,
        body: B,
        accessToken: String? = nil
    ) async throws -> T {
        var request = URLRequest(url: Self.baseURL.appending(path: path))
        request.httpMethod = "POST"
        addHeaders(to: &request, accessToken: accessToken)
        request.httpBody = try JSONEncoder().encode(body)
        return try await execute(request)
    }

    private func addHeaders(to request: inout URLRequest, accessToken: String? = nil) {
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthError.server(serverMessage(from: data) ?? "Account request failed (\(http.statusCode)).")
        }
        return try decoder.decode(T.self, from: data)
    }

    private func serverMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (object["msg"] ?? object["message"] ?? object["error_description"] ?? object["error"]) as? String
    }
}
