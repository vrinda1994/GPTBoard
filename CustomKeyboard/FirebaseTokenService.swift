//
//  FirebaseTokenService.swift
//  CustomKeyboard
//
//  Created by Claude on 9/28/25.
//

import Foundation

struct FirebaseTokenResponse: Codable {
    let access_token: String
    let expires_in: String
    let token_type: String
    let refresh_token: String?
    let id_token: String
    let user_id: String
    let project_id: String
}

struct FirebaseTokenError: Codable {
    let error: FirebaseTokenErrorDetails
}

struct FirebaseTokenErrorDetails: Codable {
    let code: Int
    let message: String
    let status: String
}

class FirebaseTokenService {
    static let shared = FirebaseTokenService()

    private init() {}

    private func getFirebaseAPIKey() -> String? {
        // Try current bundle first (for keyboard extension)
        if let path = Bundle(for: type(of: self)).path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) {
            return plist["API_KEY"] as? String
        }

        // Fallback to main bundle (for main app)
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) {
            return plist["API_KEY"] as? String
        }

        print("Could not find GoogleService-Info.plist in any bundle")
        return nil
    }

    func refreshToken(completion: @escaping (Bool) -> Void) {
        guard let apiKey = getFirebaseAPIKey() else {
            print("Could not get Firebase API key")
            completion(false)
            return
        }

        guard let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard"),
              let refreshToken = sharedDefaults.string(forKey: "firebaseRefreshToken") else {
            print("No refresh token found")
            completion(false)
            return
        }

        let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error creating request body: \(error)")
            completion(false)
            return
        }

        print("Refreshing Firebase token via REST API...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error refreshing token: \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let data = data else {
                print("No data received")
                completion(false)
                return
            }

            // Check for HTTP error status
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                print("HTTP error \(httpResponse.statusCode)")

                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(FirebaseTokenError.self, from: data) {
                    print("Firebase error: \(errorResponse.error.message)")
                }
                completion(false)
                return
            }

            do {
                let tokenResponse = try JSONDecoder().decode(FirebaseTokenResponse.self, from: data)

                print("Successfully refreshed Firebase token via REST API")

                // Update stored tokens
                DispatchQueue.main.async {
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") {
                        sharedDefaults.set(tokenResponse.id_token, forKey: "firebaseIDToken")
                        if let newRefreshToken = tokenResponse.refresh_token {
                            sharedDefaults.set(newRefreshToken, forKey: "firebaseRefreshToken")
                        }
                        sharedDefaults.set(tokenResponse.user_id, forKey: "userUID")
                        sharedDefaults.set(true, forKey: "userIsAuthenticated")
                        sharedDefaults.synchronize()
                    }

                    completion(true)
                }

            } catch {
                print("Error decoding token response: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Response data: \(jsonString)")
                }
                completion(false)
            }

        }.resume()
    }

    func ensureValidToken(completion: @escaping (Bool) -> Void) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard"),
              let token = sharedDefaults.string(forKey: "firebaseIDToken") else {
            print("No Firebase ID token found")
            completion(false)
            return
        }

        // Check if token is still valid
        if isJWTTokenValid(token) {
            print("Token is still valid")
            completion(true)
            return
        }

        print("Token expired, refreshing via REST API...")
        refreshToken(completion: completion)
    }

    private func isJWTTokenValid(_ token: String) -> Bool {
        let components = token.components(separatedBy: ".")
        guard components.count == 3 else {
            print("Invalid JWT format")
            return false
        }

        // Decode the payload (second component)
        let payload = components[1]
        guard let payloadData = base64URLDecode(payload) else {
            print("Failed to decode JWT payload")
            return false
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any],
               let exp = json["exp"] as? TimeInterval {

                let expirationDate = Date(timeIntervalSince1970: exp)
                let currentDate = Date()

                // Add 5-minute buffer before expiration
                let bufferTime: TimeInterval = 300 // 5 minutes
                let isValid = currentDate.addingTimeInterval(bufferTime) < expirationDate

                if !isValid {
                    print("JWT token will expire soon. Expiration: \(expirationDate), Current: \(currentDate)")
                }

                return isValid
            } else {
                print("No expiration found in JWT payload")
                return false
            }
        } catch {
            print("Failed to parse JWT payload: \(error)")
            return false
        }
    }

    private func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}