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
    let suggestions: [String]
}

struct APIError: Decodable {
    let error: String
}

class APIManager {
    static let shared = APIManager()

    // Use the correct backend URL
    private let baseURL = "https://gptboard-backend-945064039557.us-central1.run.app"

    func generateSuggestions(for message: String, context: String, completion: @escaping (Result<[String], Error>) -> Void) {
        // Always read from the shared App Group container
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

        AF.request(baseURL, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default, headers: headers)
            .validate(statusCode: 200..<300) // Only treat 2xx status codes as success
            .responseDecodable(of: APIResponse.self) { response in
                switch response.result {
                case .success(let apiResponse):
                    completion(.success(apiResponse.suggestions))
                case .failure(let afError):
                    // Try to decode a specific API error message from the backend for more detailed error info
                    if let data = response.data, let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                        let customError = NSError(domain: "APIManager", code: response.response?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: apiError.error])
                        completion(.failure(customError))
                    } else {
                        // Otherwise, return the generic Alamofire error
                        completion(.failure(afError))
                    }
                }
            }
    }
}
