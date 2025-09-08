import SwiftUI
import Combine
import FirebaseAuth

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
                    // Store in both standard UserDefaults and shared App Group
                    UserDefaults.standard.set(idToken, forKey: "firebaseIDToken")
                    
                    // Store in shared App Group for keyboard extension access
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") {
                        sharedDefaults.set(idToken, forKey: "firebaseIDToken")
                    }
                }
            }
        }
    }

    func signUp() {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] (authResult, error) in
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
                    // Store in both standard UserDefaults and shared App Group
                    UserDefaults.standard.set(idToken, forKey: "firebaseIDToken")
                    
                    // Store in shared App Group for keyboard extension access
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") {
                        sharedDefaults.set(idToken, forKey: "firebaseIDToken")
                    }
                }
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
