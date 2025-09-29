//
//  ContentView.swift
//  GPTBoard
//
//  Created by Karan Khurana on 4/10/23.
//

import SwiftUI
import Combine
import FirebaseAuth
import UIKit

// MARK: - Theme Constants
extension Color {
    static let primaryBlue = Color.blue
    static let successGreen = Color.green
    static let dangerRed = Color.red
    static let cardBackground = Color(.systemGray6)
    static let secondaryText = Color.secondary
}

extension View {
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.primaryBlue)
            .cornerRadius(12)
    }

    func successButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.successGreen)
            .cornerRadius(12)
    }

    func dangerButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.dangerRed)
            .cornerRadius(12)
    }

    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
    }
}

// MARK: - AuthViewModel
public class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published var userIsLoggedIn = false

    private var handle: AuthStateDidChangeListenerHandle?
    private var tokenRefreshTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            self?.userIsLoggedIn = user != nil

            if let user = user {
                // User is signed in, start automatic token refresh
                self?.startTokenRefresh(for: user)
                // Also refresh token immediately to update shared UserDefaults
                self?.refreshTokenAndUpdateSharedDefaults(for: user)
            } else {
                // User is signed out, stop token refresh
                self?.stopTokenRefresh()
            }
        }
    }

    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        stopTokenRefresh()
    }

    func login() {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] (authResult, error) in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }

            guard let user = authResult?.user else { return }

            user.getIDToken { idToken, error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                if let idToken = idToken {
                    // Get refresh token for REST API usage
                    let refreshToken = user.refreshToken

                    // Store UID, ID token, and refresh token in shared App Group
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") {
                        sharedDefaults.set(user.uid, forKey: "userUID")
                        sharedDefaults.set(idToken, forKey: "firebaseIDToken")
                        if let refreshToken = refreshToken {
                            sharedDefaults.set(refreshToken, forKey: "firebaseRefreshToken")
                        }
                        sharedDefaults.set(true, forKey: "userIsAuthenticated")
                        sharedDefaults.synchronize()
                    }

                    // Also store in standard UserDefaults for main app
                    UserDefaults.standard.set(user.uid, forKey: "userUID")
                    UserDefaults.standard.set(idToken, forKey: "firebaseIDToken")
                    if let refreshToken = refreshToken {
                        UserDefaults.standard.set(refreshToken, forKey: "firebaseRefreshToken")
                    }
                    UserDefaults.standard.set(true, forKey: "userIsAuthenticated")
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

            guard let user = authResult?.user else { return }

            user.getIDToken { idToken, error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                if let idToken = idToken {
                    // Get refresh token for REST API usage
                    let refreshToken = user.refreshToken

                    // Store UID, ID token, and refresh token in shared App Group
                    if let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") {
                        sharedDefaults.set(user.uid, forKey: "userUID")
                        sharedDefaults.set(idToken, forKey: "firebaseIDToken")
                        if let refreshToken = refreshToken {
                            sharedDefaults.set(refreshToken, forKey: "firebaseRefreshToken")
                        }
                        sharedDefaults.set(true, forKey: "userIsAuthenticated")
                        sharedDefaults.synchronize()
                    }

                    // Also store in standard UserDefaults for main app
                    UserDefaults.standard.set(user.uid, forKey: "userUID")
                    UserDefaults.standard.set(idToken, forKey: "firebaseIDToken")
                    if let refreshToken = refreshToken {
                        UserDefaults.standard.set(refreshToken, forKey: "firebaseRefreshToken")
                    }
                    UserDefaults.standard.set(true, forKey: "userIsAuthenticated")
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            clearAuthenticationState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearAuthenticationState() {
        // Clear authentication data from shared App Group
        if let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") {
            sharedDefaults.removeObject(forKey: "userUID")
            sharedDefaults.removeObject(forKey: "firebaseIDToken")
            sharedDefaults.set(false, forKey: "userIsAuthenticated")
            sharedDefaults.synchronize()
        }

        // Clear authentication data from standard UserDefaults
        UserDefaults.standard.removeObject(forKey: "userUID")
        UserDefaults.standard.removeObject(forKey: "firebaseIDToken")
        UserDefaults.standard.set(false, forKey: "userIsAuthenticated")
    }

    private func performBackgroundTokenRefresh(for user: User) {
        // Start background task to ensure refresh completes even if app is backgrounded
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Called when time expires
            if let taskID = self?.backgroundTaskID {
                UIApplication.shared.endBackgroundTask(taskID)
                self?.backgroundTaskID = .invalid
            }
        }

        refreshTokenAndUpdateSharedDefaults(for: user)

        // End background task when done
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if let taskID = self?.backgroundTaskID, taskID != .invalid {
                UIApplication.shared.endBackgroundTask(taskID)
                self?.backgroundTaskID = .invalid
            }
        }
    }

    private func scheduleBackgroundTokenRefresh(for user: User) {
        // Perform one immediate refresh when going to background
        performBackgroundTokenRefresh(for: user)
    }

    private func startTokenRefresh(for user: User) {
        stopTokenRefresh()

        // Refresh every 15 minutes to ensure tokens stay fresh
        // This aggressive refresh schedule prevents expiration in keyboard extension
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.performBackgroundTokenRefresh(for: user)
        }

        // Also register for background notifications
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleBackgroundTokenRefresh(for: user)
        }
    }

    private func stopTokenRefresh() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil

        // Remove background observers
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)

        // End background task if active
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    private func refreshTokenAndUpdateSharedDefaults(for user: User) {
        // Force refresh token (not using cache)
        user.getIDTokenForcingRefresh(true) { idToken, error in
            if let error = error {
                print("Error refreshing token: \(error.localizedDescription)")
                // Clear invalid authentication state on error
                DispatchQueue.main.async {
                    self.clearAuthenticationState()
                }
                return
            }

            if let idToken = idToken {
                print("Successfully refreshed Firebase token")
                let refreshToken = user.refreshToken

                if let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") {
                    sharedDefaults.set(user.uid, forKey: "userUID")
                    sharedDefaults.set(idToken, forKey: "firebaseIDToken")
                    if let refreshToken = refreshToken {
                        sharedDefaults.set(refreshToken, forKey: "firebaseRefreshToken")
                    }
                    sharedDefaults.set(true, forKey: "userIsAuthenticated")
                    sharedDefaults.synchronize()
                }

                UserDefaults.standard.set(user.uid, forKey: "userUID")
                UserDefaults.standard.set(idToken, forKey: "firebaseIDToken")
                if let refreshToken = refreshToken {
                    UserDefaults.standard.set(refreshToken, forKey: "firebaseRefreshToken")
                }
                UserDefaults.standard.set(true, forKey: "userIsAuthenticated")
            }
        }
    }
}

// MARK: - LoginView
struct LoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            Text("GPTBoard")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(12)

            SecureField("Password", text: $viewModel.password)
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(12)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(Color.dangerRed)
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
                    .background(Color.primaryBlue)
                    .cornerRadius(12)
            }

            Button(action: {
                viewModel.signUp()
            }) {
                Text("Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundColor(Color.primaryBlue)
            }
        }
        .padding()
    }
}

// MARK: - KeyboardStatusChecker
class KeyboardStatusChecker: ObservableObject {
    @Published var isKeyboardAdded = false
    @Published var hasFullAccess = false

    init() {
        checkKeyboardStatus()
    }

    func checkKeyboardStatus() {
        // Check if GPTBoard keyboard is added to the system
        if let keyboards = UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String] {
            isKeyboardAdded = keyboards.contains { $0.contains("GPTBoard") || $0.contains("com.mmcm.gptboard") }
        }

        // Check if keyboard has full access by testing shared UserDefaults access
        if let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") {
            // If we can write to shared defaults, we likely have full access
            sharedDefaults.set("test", forKey: "testKey")
            hasFullAccess = sharedDefaults.object(forKey: "testKey") != nil
            sharedDefaults.removeObject(forKey: "testKey")
        }
    }

    func refreshStatus() {
        DispatchQueue.main.async {
            self.checkKeyboardStatus()
        }
    }
}

// MARK: - KeyboardCompleteView
struct KeyboardCompleteView: View {
    var body: some View {
        VStack(spacing: 25) {
            VStack(spacing: 15) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color.successGreen)

                Text("GPTBoard is Ready!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your keyboard is set up and ready to use")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryText)
            }
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 20) {
                Text("How to use GPTBoard:")
                    .font(.headline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 15) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "globe")
                            .foregroundColor(Color.primaryBlue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Switch to GPTBoard")
                                .fontWeight(.medium)
                            Text("Long press the globe icon on any keyboard")
                                .font(.caption)
                                .foregroundColor(Color.secondaryText)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(Color.primaryBlue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI-Powered Writing")
                                .fontWeight(.medium)
                            Text("Get suggestions, completions, and rewrites")
                                .font(.caption)
                                .foregroundColor(Color.secondaryText)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "text.cursor")
                            .foregroundColor(Color.primaryBlue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Works Everywhere")
                                .fontWeight(.medium)
                            Text("Messages, email, notes, social media, and more")
                                .font(.caption)
                                .foregroundColor(Color.secondaryText)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(Color.primaryBlue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick & Smart")
                                .fontWeight(.medium)
                            Text("Fast responses powered by advanced AI")
                                .font(.caption)
                                .foregroundColor(Color.secondaryText)
                        }
                    }
                }
            }
            .cardStyle()

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    // Open Messages app to try the keyboard
                    if let messagesURL = URL(string: "sms:") {
                        UIApplication.shared.open(messagesURL)
                    }
                }) {
                    Text("Try GPTBoard Now")
                }
                .successButtonStyle()

                Text("Opens Messages app to test your new keyboard")
                    .font(.caption)
                    .foregroundColor(Color.secondaryText)
            }
        }
        .padding()
    }
}

// MARK: - KeyboardSetupView
struct KeyboardSetupView: View {
    @StateObject private var keyboardStatus = KeyboardStatusChecker()

    var body: some View {
        Group {
            if keyboardStatus.isKeyboardAdded && keyboardStatus.hasFullAccess {
                KeyboardCompleteView()
            } else {
                setupInstructions
            }
        }
        .onAppear {
            keyboardStatus.refreshStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                keyboardStatus.refreshStatus()
            }
        }
    }

    private var setupInstructions: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Setup GPTBoard Keyboard")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom)

            VStack(alignment: .leading, spacing: 15) {
                Text("Follow these steps to enable GPTBoard:")
                    .font(.headline)

                // Step 1: Open Settings
                HStack(alignment: .top, spacing: 12) {
                    HStack {
                        Text("1.")
                            .fontWeight(.bold)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.successGreen)
                            .opacity(1.0) // Always show as completed since user can always access settings
                    }
                    VStack(alignment: .leading) {
                        Text("Open Settings app")
                        Text("→ General → Keyboard → Keyboards")
                            .foregroundColor(Color.secondaryText)
                    }
                    Spacer()
                }

                // Step 2: Add Keyboard
                HStack(alignment: .top, spacing: 12) {
                    HStack {
                        Text("2.")
                            .fontWeight(.bold)
                        Image(systemName: keyboardStatus.isKeyboardAdded ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(keyboardStatus.isKeyboardAdded ? Color.successGreen : .gray)
                    }
                    VStack(alignment: .leading) {
                        Text("Tap 'Add New Keyboard...'")
                        Text("Select 'GPTBoard' from the list")
                            .foregroundColor(Color.secondaryText)
                    }
                    Spacer()
                }

                // Step 3: Enable Full Access
                HStack(alignment: .top, spacing: 12) {
                    HStack {
                        Text("3.")
                            .fontWeight(.bold)
                        Image(systemName: keyboardStatus.hasFullAccess ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(keyboardStatus.hasFullAccess ? Color.successGreen : .gray)
                    }
                    VStack(alignment: .leading) {
                        Text("Enable 'Allow Full Access'")
                        Text("This allows GPTBoard to connect to the internet")
                            .foregroundColor(Color.secondaryText)
                    }
                    Spacer()
                }

                // Step 4: Start Using
                HStack(alignment: .top, spacing: 12) {
                    HStack {
                        Text("4.")
                            .fontWeight(.bold)
                        Image(systemName: (keyboardStatus.isKeyboardAdded && keyboardStatus.hasFullAccess) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor((keyboardStatus.isKeyboardAdded && keyboardStatus.hasFullAccess) ? Color.successGreen : .gray)
                    }
                    VStack(alignment: .leading) {
                        Text("Start typing in any app!")
                        Text("Long press the globe icon to switch to GPTBoard")
                            .foregroundColor(Color.secondaryText)
                    }
                    Spacer()
                }
            }

            Spacer()

            VStack(spacing: 10) {
                Button(action: {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }) {
                    Text("Open Settings")
                }
                .primaryButtonStyle()

                Text("Status updates automatically when you return from Settings")
                    .font(.caption)
                    .foregroundColor(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color.primaryBlue)

                    if let user = Auth.auth().currentUser {
                        Text(user.email ?? "User")
                            .font(.headline)
                            .padding(.top, 5)
                    }
                }
                .padding(.top, 40)

                Spacer()

                Button(action: {
                    viewModel.signOut()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Sign Out")
                }
                .dangerButtonStyle()
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showingSettings = false

    var body: some View {
        Group {
            if viewModel.userIsLoggedIn {
                NavigationView {
                    KeyboardSetupView()
                        .navigationTitle("GPTBoard")
                        .navigationBarItems(trailing:
                            Button(action: {
                                showingSettings = true
                            }) {
                                Image(systemName: "person.circle")
                                    .font(.title2)
                            }
                        )
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                        .environmentObject(viewModel)
                }
            } else {
                LoginView()
                    .environmentObject(viewModel)
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

