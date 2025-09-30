//
//  APIManager.swift
//  GPTBoard
//
//  Created by Karan Khurana on 4/14/23.
//

import Foundation
import Alamofire

// Shared Response/Error Models
struct APIResponse: Decodable {
    let status_code: Int
    let text: String
}

struct IndividualSuggestions: Decodable {
    let suggestions: [String]
}

struct BatchAPIResponse: Decodable {
    let status_code: Int
    let text: String
}

struct APIError: Decodable {
    let error: String
}

struct ContextItem: Codable {
    let key: String
    let display_name: String
    let prompt: String
}

class APIManager {
    static let shared = APIManager()

    // Use the correct backend URL
    private let baseURL = "https://gptboard-backend-945064039557.us-central1.run.app"

    // Cache for batch suggestions
    private var cachedSuggestions: [String: [String]] = [:]
    private var lastCachedText: String?

    // Cache for contexts with 12-hour expiry
    private var cachedContexts: [ContextItem] = []
    private var contextsCacheTimestamp: Date?
    private let contextsCacheTimeout: TimeInterval = 12 * 60 * 60 // 12 hours

    func generateSuggestions(for message: String, context: String, completion: @escaping (Result<[String], Error>) -> Void) {
        // Ensure we have a valid token, refresh if needed
        FirebaseTokenService.shared.ensureValidToken { isValid in
            guard isValid else {
                let error = NSError(domain: "APIManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authorization token not found or expired. Please check your authentication."])
                completion(.failure(error))
                return
            }

            // Get the fresh token
            guard let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard"),
                  let idToken = sharedDefaults.string(forKey: "firebaseIDToken") else {
                let error = NSError(domain: "APIManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authorization token not found. Please run the main app and log in first."])
                completion(.failure(error))
                return
            }

        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(idToken)",
            "Content-Type": "application/json"
        ]

        let parameters: [String: String] = [
            "message": message,
            "context": context
        ]

        print("Making individual request to: \(self.baseURL)")
        print("Individual parameters: \(parameters)")
        print("Individual headers: \(headers)")

            AF.request(self.baseURL, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default, headers: headers)
                .validate(statusCode: 200..<300) // Only treat 2xx status codes as success
                .responseDecodable(of: APIResponse.self) { response in
                    print("Individual response status code: \(response.response?.statusCode ?? -1)")
                    if let data = response.data {
                        print("Individual response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    }

                    switch response.result {
                    case .success(let apiResponse):
                        print("Individual success, parsing nested JSON...")

                        // Parse the nested JSON string
                        guard let textData = apiResponse.text.data(using: .utf8) else {
                            let parseError = NSError(domain: "APIManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert individual text to data"])
                            completion(.failure(parseError))
                            return
                        }

                        do {
                            let individualResult = try JSONDecoder().decode(IndividualSuggestions.self, from: textData)
                            print("Parsed individual suggestions: \(individualResult.suggestions)")
                            completion(.success(individualResult.suggestions))
                        } catch {
                            print("Failed to parse individual nested JSON: \(error)")
                            completion(.failure(error))
                        }
                    case .failure(let afError):
                        print("Individual failure: \(afError)")

                        // Try to decode a specific API error message from the backend for more detailed error info
                        if let data = response.data, let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                            print("Decoded individual API error: \(apiError.error)")
                            let customError = NSError(domain: "APIManager", code: response.response?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: apiError.error])
                            completion(.failure(customError))
                        } else {
                            print("Using individual AFError: \(afError.localizedDescription)")
                            // Otherwise, return the generic Alamofire error
                            completion(.failure(afError))
                        }
                    }
                }
        }
    }

    func generateBatchSuggestions(for message: String, contexts: [String], completion: @escaping (Result<[String: [String]], Error>) -> Void) {
        // Ensure we have a valid token, refresh if needed
        FirebaseTokenService.shared.ensureValidToken { isValid in
            guard isValid else {
                let error = NSError(domain: "APIManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authorization token not found or expired. Please check your authentication."])
                completion(.failure(error))
                return
            }

            // Get the fresh token
            guard let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard"),
                  let idToken = sharedDefaults.string(forKey: "firebaseIDToken") else {
                let error = NSError(domain: "APIManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authorization token not found. Please run the main app and log in first."])
                completion(.failure(error))
                return
            }

        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(idToken)",
            "Content-Type": "application/json"
        ]

        let parameters: [String: Any] = [
            "message": message,
            "contexts": contexts
        ]

            let batchURL = "\(self.baseURL)/batch"

        print("Making batch request to: \(batchURL)")
        print("Parameters: \(parameters)")
        print("Headers: \(headers)")

            AF.request(batchURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .validate(statusCode: 200..<300)
                .responseDecodable(of: BatchAPIResponse.self) { response in
                    print("Batch response status code: \(response.response?.statusCode ?? -1)")
                    if let data = response.data {
                        print("Batch response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    }

                    switch response.result {
                    case .success(let batchResponse):
                        print("Batch success, parsing nested JSON...")

                        // Parse the nested JSON string
                        guard let textData = batchResponse.text.data(using: .utf8) else {
                            let parseError = NSError(domain: "APIManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert text to data"])
                            completion(.failure(parseError))
                            return
                        }

                        do {
                            let results = try JSONDecoder().decode([String: [String]].self, from: textData)
                            print("Parsed batch results: \(results)")
                            completion(.success(results))
                        } catch {
                            print("Failed to parse nested JSON: \(error)")
                            completion(.failure(error))
                        }
                    case .failure(let afError):
                        print("Batch failure: \(afError)")

                        if let data = response.data, let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                            print("Decoded API error: \(apiError.error)")
                            let customError = NSError(domain: "APIManager", code: response.response?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: apiError.error])
                            completion(.failure(customError))
                        } else {
                            print("Using AFError: \(afError.localizedDescription)")
                            completion(.failure(afError))
                        }
                    }
                }
        }
    }

    func getCachedSuggestions(for context: String) -> [String]? {
        return cachedSuggestions[context]
    }

    func cacheSuggestions(_ suggestions: [String: [String]], for text: String) {
        cachedSuggestions = suggestions
        lastCachedText = text
    }

    func shouldRefreshCache(for text: String) -> Bool {
        return lastCachedText != text
    }

    func clearCache() {
        cachedSuggestions.removeAll()
        lastCachedText = nil
    }

    // MARK: - Context Caching Methods

    func getCachedContexts() -> [ContextItem]? {
        guard let timestamp = contextsCacheTimestamp,
              Date().timeIntervalSince(timestamp) < contextsCacheTimeout,
              !cachedContexts.isEmpty else {
            return nil
        }
        return cachedContexts
    }

    func getContextsWithFallback() -> [ContextItem] {
        // Return cached contexts if available, otherwise fallback to hardcoded
        if let cached = getCachedContexts() {
            return cached
        }

        // Fallback to hardcoded contexts
        return [
            ContextItem(key: "funny", display_name: "😂 Funny", prompt: "How would you say this sentence in a funny way"),
            ContextItem(key: "snarky", display_name: "😏 Snarky", prompt: "Make this sentence snarky"),
            ContextItem(key: "witty", display_name: "🤓 Witty", prompt: "Make this sentence witty"),
            ContextItem(key: "insult", display_name: "🤬 Insult", prompt: "Convert this sentence into an insult"),
            ContextItem(key: "genz", display_name: "🔥 GenZ", prompt: "How would a genz say this line"),
            ContextItem(key: "millennial", display_name: "🙃 Millennial", prompt: "How would a millennial say this line"),
            ContextItem(key: "emojis", display_name: "Emojis", prompt: "Convert this sentence into all emojis"),
            ContextItem(key: "medieval", display_name: "🏰 Medieval", prompt: "Make this sentence into how they would say it in medieval times"),
            ContextItem(key: "romantic", display_name: "🥰 Romantic", prompt: "How would you say this in a romantic way")
        ]
    }

    private func cacheContexts(_ contexts: [ContextItem]) {
        cachedContexts = contexts
        contextsCacheTimestamp = Date()

        // Also save to UserDefaults for keyboard extension access
        saveContextsToUserDefaults(contexts)
    }

    private func saveContextsToUserDefaults(_ contexts: [ContextItem]) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") else {
            print("Failed to access shared UserDefaults for context caching")
            return
        }

        do {
            let contextData = try JSONEncoder().encode(contexts)
            sharedDefaults.set(contextData, forKey: "cachedContextsData")
            sharedDefaults.set(Date(), forKey: "contextsCacheTimestamp")
            print("Saved \(contexts.count) contexts to UserDefaults for keyboard access")
        } catch {
            print("Failed to encode contexts for UserDefaults: \(error)")
        }
    }

    func shouldRefreshContexts() -> Bool {
        return true // Always refresh for testing
        // guard let timestamp = contextsCacheTimestamp else {
        //     return true // No cache, should refresh
        // }
        // return Date().timeIntervalSince(timestamp) >= contextsCacheTimeout
    }

    func fetchContexts(completion: @escaping (Result<[ContextItem], Error>) -> Void) {
        print("DEBUG: fetchContexts() called")

        // Ensure we have a valid token, refresh if needed
        FirebaseTokenService.shared.ensureValidToken { isValid in
            print("DEBUG: Token validation completed, isValid: \(isValid)")
            guard isValid else {
                let error = NSError(domain: "APIManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authorization token not found or expired. Please check your authentication."])
                completion(.failure(error))
                return
            }

            // Get the fresh token
            guard let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard"),
                  let idToken = sharedDefaults.string(forKey: "firebaseIDToken") else {
                let error = NSError(domain: "APIManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authorization token not found. Please run the main app and log in first."])
                completion(.failure(error))
                return
            }

            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(idToken)",
                "Content-Type": "application/json"
            ]

            let contextsURL = "\(self.baseURL)/contexts"

            print("Making contexts request to: \(contextsURL)")
            print("Headers: \(headers)")

            AF.request(contextsURL, method: .get, headers: headers)
                .validate(statusCode: 200..<300)
                .responseDecodable(of: [ContextItem].self) { response in
                    print("Contexts response status code: \(response.response?.statusCode ?? -1)")
                    if let data = response.data {
                        print("Contexts response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                    }

                    switch response.result {
                    case .success(let contexts):
                        print("Contexts success: \(contexts)")
                        self.cacheContexts(contexts)
                        completion(.success(contexts))
                    case .failure(let afError):
                        print("Contexts failure: \(afError)")
                        if let data = response.data, let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                            print("Decoded contexts API error: \(apiError.error)")
                            let customError = NSError(domain: "APIManager", code: response.response?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: apiError.error])
                            completion(.failure(customError))
                        } else {
                            print("Using contexts AFError: \(afError.localizedDescription)")
                            completion(.failure(afError))
                        }
                    }
                }
        }
    }

    func refreshContextsInBackground() {
        print("DEBUG: refreshContextsInBackground() called")

        // Only refresh if we should (cache expired or no cache)
        let shouldRefresh = shouldRefreshContexts()
        print("DEBUG: shouldRefreshContexts() returned: \(shouldRefresh)")

        guard shouldRefresh else {
            print("Contexts cache is still valid, skipping background refresh")
            return
        }

        print("Starting background refresh of contexts...")
        fetchContexts { result in
            switch result {
            case .success(let contexts):
                print("Background contexts refresh successful: \(contexts.count) contexts loaded")
            case .failure(let error):
                print("Background contexts refresh failed: \(error.localizedDescription)")
                // Don't clear cache on background refresh failure to maintain UX
            }
        }
    }

}
