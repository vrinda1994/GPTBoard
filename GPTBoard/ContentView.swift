//
//  ContentView.swift
//  GPTBoard
//
//  Created by Karan Khurana on 4/10/23.
//

import SwiftUI
import Combine
import FirebaseAuth

// MARK: - AuthViewModel
class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var userIsLoggedIn = false

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            self?.userIsLoggedIn = user != nil
        }
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func login() {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] (authResult, error) in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            
            authResult?.user.getIDToken { idToken, error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                if let idToken = idToken {
                    // You can now send this idToken to your backend
                    print("Firebase ID Token: \(idToken)")
                    // Example of how you might store it for later use
                    UserDefaults.standard.set(idToken, forKey: "firebaseIDToken")
                }
            }
        }
    }

    func signUp() {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] (_, error) in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - LoginView
struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("GPTBoard")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            SecureField("Password", text: $viewModel.password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                viewModel.login()
            }) {
                Text("Login")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }

            Button(action: {
                viewModel.signUp()
            }) {
                Text("Don't have an account? Sign Up")
                    .font(.subheadline)
            }
        }
        .padding()
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        Group {
            if viewModel.userIsLoggedIn {
                VStack {
                    // Main app content goes here
                    Text("Welcome to GPTBoard!")
                    
                    Button(action: {
                        viewModel.signOut()
                    }) {
                        Text("Sign Out")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            } else {
                LoginView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Previews
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(viewModel: AuthViewModel())
    }
}
