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

class APIManager {
    static let shared = APIManager()

    // Use the correct backend URL
    private let baseURL = "https://gptboard-backend-945064039557.us-central1.run.app"

    // Cache for batch suggestions
    private var cachedSuggestions: [String: [String]] = [:]
    private var lastCachedText: String?

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

}
