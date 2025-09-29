//
//  KeyboardViewController.swift
//  CustomKeyboard
//
//  Created by Karan Khurana on 4/10/23.
//

import UIKit
import Alamofire
import Foundation

class KeyboardViewController: UIInputViewController {
    struct TextHistory {
        let originalText: String
        var convertedText: String
        let contextIndex: Int
        var suggestions: [String]
        var suggestionIndex: Int
    }

    var textHistoryStack: [TextHistory] = []
    var contextButtons: [UIButton] = []
    var isProcessingRequest = false
    var currentLoadingButton: UIButton?
    var textChangeTimer: Timer?
    var hasShownKeyboardBefore = false

    // Batch caching properties
    var isBatchPreloading = false
    var lastPreloadedText: String?

    // Authentication caching
    private var cachedAuthState: Bool?
    private var lastAuthCheck: Date?
    private let authCacheTimeout: TimeInterval = 5.0 // 5 seconds

    // UI View caching - pre-build expensive views
    private var cachedAIButtonsView: UIView?
    private var cachedInstructionsView: UIView?
    private var cachedUnauthenticatedView: UIView?
    private var cachedTokenExpiredView: UIView?

    // The response and error structs are now defined in APIManager.swift
    // to be shared across the app.


    let buttonTitlesAndContexts = [
            ("😂 Funny", "How would you say this sentence in a funny way"),
            ("😏 Snarky", "Make this sentence snarky"),
            ("🤓 Witty", "Make this sentence witty"),
            ("🤬 Insult", "Convert this sentence into an insult"),
            ("️‍🔥 GenZ", "How would a genz say this line"),
            ("🙃 Millennial", "How would a millennial say this line"),
            ("Emojis", "Convert this sentence into all emojis"),
            ("🏰 Medieval", "Make this sentence into how they would say it in medieval times"),
            ("🥰 Romantic", "How would you say this in a romantic way")
        ]
    
    // This is no longer needed as we are using the APIManager
    // private let chatGPTHandler = ChatGPTHandler()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set modern gradient background
        setupGradientBackground()

        // Check authentication before setting up UI
        refreshUIBasedOnAuthState()

        // Start observing text changes
        startTextChangeObserver()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // If this is the first time showing, automatically switch to system keyboard
        if !hasShownKeyboardBefore {
            hasShownKeyboardBefore = true

            // Check if we have UserDefaults to persist this state
            if let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") {
                let hasOpenedBefore = sharedDefaults.bool(forKey: "hasOpenedKeyboardBefore")
                if !hasOpenedBefore {
                    sharedDefaults.set(true, forKey: "hasOpenedKeyboardBefore")
                    // Automatically switch to system keyboard on first open
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.advanceToNextInputMode()
                    }
                    return
                }
            }
        }

        // Re-check authentication state when keyboard appears
        refreshUIBasedOnAuthState()

        // Preload suggestions if text has changed
        preloadSuggestionsIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Stop observing text changes
        stopTextChangeObserver()
    }

    private func setupGradientBackground() {
        let gradientLayer = CAGradientLayer()

        if traitCollection.userInterfaceStyle == .dark {
            gradientLayer.colors = [
                UIColor.systemBlue.withAlphaComponent(0.15).cgColor,
                UIColor.systemPurple.withAlphaComponent(0.15).cgColor,
                UIColor.systemIndigo.withAlphaComponent(0.1).cgColor
            ]
        } else {
            gradientLayer.colors = [
                UIColor.systemBlue.withAlphaComponent(0.08).cgColor,
                UIColor.systemPurple.withAlphaComponent(0.08).cgColor,
                UIColor.systemIndigo.withAlphaComponent(0.05).cgColor
            ]
        }

        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = view.bounds

        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update gradient frame when view layout changes
        if let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = view.bounds
        }
    }

    private func refreshUIBasedOnAuthState() {
        // Clear existing UI and reset state
        view.subviews.forEach { $0.removeFromSuperview() }
        contextButtons.removeAll()
        textHistoryStack.removeAll()

        // Re-setup gradient background
        setupGradientBackground()

        if isUserAuthenticated() {
            setupUI()
        } else {
            setupUnauthenticatedUI()
        }
    }

    private func setupUI() {
        // Check if there's text to transform
        if let inputText = textDocumentProxy.documentContextBeforeInput, !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            setupAIButtonsUI()
        } else {
            setupInstructionsUI()
        }
    }

    private func isUserAuthenticated() -> Bool {
        // Use cached authentication state if within timeout
        if let cachedState = cachedAuthState,
           let lastCheck = lastAuthCheck,
           Date().timeIntervalSince(lastCheck) < authCacheTimeout {
            return cachedState
        }

        guard let sharedDefaults = UserDefaults(suiteName: "group.com.mmcm.gptboard") else {
            cachedAuthState = false
            lastAuthCheck = Date()
            return false
        }

        let isAuthenticated = sharedDefaults.bool(forKey: "userIsAuthenticated")
        let hasUID = sharedDefaults.string(forKey: "userUID") != nil
        let hasToken = sharedDefaults.string(forKey: "firebaseIDToken") != nil

        if !hasToken {
            print("No Firebase ID token found")
        }

        // All conditions must be true for proper authentication
        let authState = isAuthenticated && hasToken && hasUID

        // Cache the result
        cachedAuthState = authState
        lastAuthCheck = Date()

        return authState
    }


    private func setupUnauthenticatedUI() {
        // Use cached view if available
        if let cachedLabel = cachedUnauthenticatedView {
            view.addSubview(cachedLabel)
            cachedLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                cachedLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                cachedLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                cachedLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                cachedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
            ])
            return
        }

        // Build the view for the first time
        let messageLabel = UILabel()
        messageLabel.text = "Please open GPTBoard app and sign in to use the keyboard"
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .label
        messageLabel.font = UIFont.systemFont(ofSize: 16)

        // Cache the label directly and add to main view
        cachedUnauthenticatedView = messageLabel
        view.addSubview(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func setupTokenExpiredUI() {
        // Use cached view if available
        if let cachedLabel = cachedTokenExpiredView {
            view.addSubview(cachedLabel)
            cachedLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                cachedLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                cachedLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                cachedLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                cachedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
            ])
            return
        }

        // Build the view for the first time
        let messageLabel = UILabel()
        messageLabel.text = "Authentication expired. Please open GPTBoard app to refresh and try again."
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .label
        messageLabel.font = UIFont.systemFont(ofSize: 16)

        // Cache the label directly and add to main view
        cachedTokenExpiredView = messageLabel
        view.addSubview(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }


    private func setupAIButtonsUI() {
        // Use cached view if available
        if let cachedView = cachedAIButtonsView {
            view.addSubview(cachedView)
            cachedView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                // Fill the view completely - no extra padding from container
                cachedView.topAnchor.constraint(equalTo: view.topAnchor),
                cachedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                cachedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                cachedView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            return
        }

        // Build the view for the first time
        let containerView = UIView()

        // Create action buttons and stack view
        let keyboardSwitchButton = createKeyboardSwitchButton()
        let undoButton = createUndoButton()
        let clearButton = createClearButton()
        let regenerateButton = createRegenerateButton()

        let actionButtons = [keyboardSwitchButton, undoButton, clearButton, regenerateButton]
        let actionButtonStack = UIStackView(arrangedSubviews: actionButtons)
        actionButtonStack.axis = .horizontal
        actionButtonStack.distribution = .fillEqually
        actionButtonStack.spacing = 16

        // Create a container view for action buttons with glass morphism
        let actionButtonContainer = UIView()
        actionButtonContainer.addSubview(actionButtonStack)
        addGlassMorphismEffect(to: actionButtonContainer)

        // Create button grid
        let buttonContainer = createButtonsFor3x3Grid()
        addGlassMorphismEffect(to: buttonContainer)

        // Add both containers to the main container
        containerView.addSubview(buttonContainer)
        containerView.addSubview(actionButtonContainer)

        // Setup Auto Layout for all containers - using original spacing relative to the containerView
        actionButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        actionButtonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Button grid constraints - positioned exactly like the original
            buttonContainer.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 10),
            buttonContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            buttonContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            buttonContainer.bottomAnchor.constraint(equalTo: actionButtonContainer.topAnchor, constant: -15),

            // Action button container constraints - positioned exactly like the original
            actionButtonContainer.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            actionButtonContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            actionButtonContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            actionButtonContainer.heightAnchor.constraint(equalToConstant: 70),

            // Stack view constraints within container
            actionButtonStack.topAnchor.constraint(equalTo: actionButtonContainer.topAnchor, constant: 6),
            actionButtonStack.leadingAnchor.constraint(equalTo: actionButtonContainer.leadingAnchor, constant: 8),
            actionButtonStack.trailingAnchor.constraint(equalTo: actionButtonContainer.trailingAnchor, constant: -8),
            actionButtonStack.bottomAnchor.constraint(equalTo: actionButtonContainer.bottomAnchor, constant: -6)
        ])

        // Cache the built view and add to main view
        cachedAIButtonsView = containerView
        view.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            // Fill the view completely - no extra padding from container
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupInstructionsUI() {
        // Use cached view if available
        if let cachedContainer = cachedInstructionsView {
            view.addSubview(cachedContainer)
            cachedContainer.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                cachedContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                cachedContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                cachedContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                cachedContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
            ])
            return
        }

        // Build the view for the first time
        // Create container for instructions with glass morphism
        let instructionsContainer = UIView()
        addGlassMorphismEffect(to: instructionsContainer)

        // Create instruction text
        let titleLabel = UILabel()
        titleLabel.text = "GPTBoard AI Keyboard"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let instructionLabel = UILabel()
        instructionLabel.text = "First, switch to the system keyboard and type some text.\nThen switch back here to transform it with AI!"
        instructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0

        // Create switch button
        let switchButton = createKeyboardSwitchButton()

        // Create stack view for labels and button
        let stackView = UIStackView(arrangedSubviews: [titleLabel, instructionLabel, switchButton])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center

        instructionsContainer.addSubview(stackView)

        // Setup constraints
        instructionsContainer.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Stack view constraints
            stackView.topAnchor.constraint(equalTo: instructionsContainer.topAnchor, constant: 30),
            stackView.leadingAnchor.constraint(equalTo: instructionsContainer.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: instructionsContainer.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: instructionsContainer.bottomAnchor, constant: -30),

            // Button constraints
            switchButton.widthAnchor.constraint(equalToConstant: 80),
            switchButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        // Cache the instructions container directly and add to main view
        cachedInstructionsView = instructionsContainer
        view.addSubview(instructionsContainer)

        NSLayoutConstraint.activate([
            // Container constraints
            instructionsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionsContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            instructionsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func startTextChangeObserver() {
        // Use a timer to periodically check for text changes since textDocumentProxy doesn't send notifications
        textChangeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForTextChanges()
        }
    }

    private func stopTextChangeObserver() {
        textChangeTimer?.invalidate()
        textChangeTimer = nil
    }

    private func checkForTextChanges() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Only refresh if we're authenticated and not processing
            guard self.isUserAuthenticated() && !self.isProcessingRequest else { return }

            let hasText = self.textDocumentProxy.documentContextBeforeInput?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            let currentlyShowingButtons = !self.contextButtons.isEmpty

            // If state changed, refresh UI
            if hasText != currentlyShowingButtons {
                self.refreshUIBasedOnAuthState()
            }
        }
    }

    private func setupScrollViewAndButtonsStackView() {
        let buttonContainer = createButtonsFor3x3Grid()

        // Add glass morphism effect to container
        addGlassMorphismEffect(to: buttonContainer)

        view.addSubview(buttonContainer)
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            buttonContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            buttonContainer.heightAnchor.constraint(equalToConstant: 150)
        ])
    }
    
//    private func setupScrollViewAndButtonsStackView() {
//        let scrollView = UIScrollView()
//        let buttonsStackView = createButtonsStackView()
//
//        scrollView.addSubview(buttonsStackView)
//        view.addSubview(scrollView)
//
//        scrollView.translatesAutoresizingMaskIntoConstraints = false
//        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
//
//        NSLayoutConstraint.activate([
//            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
//            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
//            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
//            scrollView.heightAnchor.constraint(equalToConstant: 140),
//
//            buttonsStackView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
//            buttonsStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
//            buttonsStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
//            buttonsStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
//        ])
//    }
    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .lightGray
//        
//        let buttonsStackView = createButtonsStackView()
//        let scrollView = UIScrollView()
//        scrollView.addSubview(buttonsStackView)
//        view.addSubview(scrollView)
//        
//        let undoButton = createUndoButton()
//        let clearButton = createClearButton()
//        let regenerateButton = createRegenerateButton()
//        
//        let actionButtons = [undoButton, clearButton, regenerateButton]
//        let actionButtonStack = UIStackView(arrangedSubviews: actionButtons)
//        view.addSubview(actionButtonStack)
//        
//        scrollView.translatesAutoresizingMaskIntoConstraints = false
//        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
//        
//        actionButtonStack.translatesAutoresizingMaskIntoConstraints = false
//        actionButtonStack.axis = .horizontal
//        actionButtonStack.distribution = .fillEqually
//        
//        let maxWidth = UIScreen.main.bounds.width
//        for actionButton in actionButtons {
//            actionButton.widthAnchor.constraint(equalToConstant: maxWidth/3).isActive = true
//        }
//        
//        NSLayoutConstraint.activate([
//            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
//            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
//            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
//            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
//
//            scrollView.heightAnchor.constraint(equalToConstant: 140),
//            
//            buttonsStackView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
//            buttonsStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
//            buttonsStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 10),
//            buttonsStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -10),
//            
//            actionButtonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
//            actionButtonStack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
//
//        ])
//    }
    
    func createButtonsStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 10
        stackView.distribution = .fill
        
//        let numButtons = 3.0
//        let numberOfRows = Int(ceil(Double(buttonTitlesAndContexts.count) / numButtons))
//        let maxWidth = UIScreen.main.bounds.width
////        let buttonWidth = maxWidth / 3 - 20;
//
//        for _ in 0..<numberOfRows {
//            let rowStack = UIStackView()
//            rowStack.axis = .horizontal
//            rowStack.alignment = .center
//            rowStack.spacing = 10
//            rowStack.distribution = .fillEqually
//            stackView.addArrangedSubview(rowStack)
//        }
//        
//        for (index, (title, _)) in buttonTitlesAndContexts.enumerated() {
//            let button = UIButton(type: .system)
//            button.setTitle(title, for: .normal)
//            button.tag = index
//            button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)
//            
//            button.layer.cornerRadius = 10
//            button.backgroundColor = .white
//            button.setTitleColor(.black, for: .normal)
//            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
//            contextButtons.append(button)
//            
//            let rowIndex = index / Int(numButtons)
//            if let rowStack = stackView.arrangedSubviews[rowIndex] as? UIStackView {
//                rowStack.addArrangedSubview(button)
//            }
//        }
            
        return stackView
    }
    
    func createButtonsFor3x3Grid() -> UIView {
        let containerView = UIView()
        let mainStackView = UIStackView()

        // Configure main stack view (vertical)
        mainStackView.axis = .vertical
        mainStackView.alignment = .fill
        mainStackView.spacing = 12
        mainStackView.distribution = .fillEqually

        // Define color themes for each context button
        let buttonColors: [(UIColor, UIColor)] = [
            (UIColor.systemOrange, UIColor.systemYellow),     // 😂 Funny
            (UIColor.systemPurple, UIColor.systemPink),       // 😏 Snarky
            (UIColor.systemBlue, UIColor.systemTeal),         // 🤓 Witty
            (UIColor.systemRed, UIColor.systemOrange),        // 🤬 Insult
            (UIColor.systemGreen, UIColor.systemMint),        // 🔥 GenZ
            (UIColor.systemPink, UIColor.systemPurple),       // 🙃 Millennial
            (UIColor.systemIndigo, UIColor.systemBlue),       // Emojis
            (UIColor.systemBrown, UIColor.systemOrange),      // 🏰 Medieval
            (UIColor.systemPink, UIColor.systemRed)           // 🥰 Romantic
        ]

        let buttonsPerRow = 3
        let numberOfRows = Int(ceil(Double(buttonTitlesAndContexts.count) / Double(buttonsPerRow)))

        var buttonIndex = 0

        // Create rows
        for _ in 0..<numberOfRows {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.alignment = .fill
            rowStackView.spacing = 12
            rowStackView.distribution = .fillEqually

            // Add buttons to this row
            for _ in 0..<buttonsPerRow {
                if buttonIndex < buttonTitlesAndContexts.count {
                    let (title, _) = buttonTitlesAndContexts[buttonIndex]
                    let button = createModernContextButton(title: title, colorTheme: buttonColors[buttonIndex], tag: buttonIndex)

                    // Set height constraint for consistent sizing
                    button.heightAnchor.constraint(equalToConstant: 44).isActive = true

                    contextButtons.append(button)
                    rowStackView.addArrangedSubview(button)
                    buttonIndex += 1
                } else {
                    // Add spacer view for incomplete rows
                    let spacerView = UIView()
                    rowStackView.addArrangedSubview(spacerView)
                }
            }

            mainStackView.addArrangedSubview(rowStackView)
        }

        // Add main stack view to container
        containerView.addSubview(mainStackView)
        mainStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            mainStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            mainStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            mainStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])

        return containerView
    }

    private func setupButtonGridWithProperSpacing(actionButtonContainer: UIView) {
        let buttonContainer = createButtonsFor3x3Grid()

        // Add glass morphism effect to container
        addGlassMorphismEffect(to: buttonContainer)

        view.addSubview(buttonContainer)
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            buttonContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            buttonContainer.bottomAnchor.constraint(equalTo: actionButtonContainer.topAnchor, constant: -15)
        ])
    }
//        for _ in 0..<numberOfRows {
//            let rowStack = UIStackView()
//            rowStack.axis = .horizontal
//            rowStack.alignment = .center
//            rowStack.spacing = 10
//            rowStack.distribution = .fillEqually
////            stackView.addArrangedSubview(rowStack)
//        }
//        
//        for (index, (title, _)) in buttonTitlesAndContexts.enumerated() {
//            let button = UIButton(type: .system)
//            button.setTitle(title, for: .normal)
//            button.tag = index
//            button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)
//            
//            button.layer.cornerRadius = 10
//            button.backgroundColor = .white
//            button.setTitleColor(.black, for: .normal)
//            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
//            contextButtons.append(button)
////            buttons.append(button)
//            
//            let rowIndex = index / Int(numButtons)
//
//            if let rowStack = stackView.arrangedSubviews[rowIndex] as? UIStackView {
//                rowStack.addArrangedSubview(button)
//            }
//        }
//        return buttons
//    }
    
//    @objc func convertButtonTapped() {
//        print("Tippi tippi tap tap")
//        if let inputText = textDocumentProxy.documentContextBeforeInput {
//            print("Sending message " + inputText)
//
//            requestFunnyMessage(originalMessage: inputText) { [weak self] funnyMessage in
//                DispatchQueue.main.async {
//                    guard let funnyMessage = funnyMessage else {return}
//                    print("FUNNY MESSAGE" + funnyMessage)
//                    for i in 0 ..< inputText.count
//                    {
//                        self?.textDocumentProxy.deleteBackward()
//                    }
//
//                    self?.textDocumentProxy.insertText(funnyMessage)
//                    self?.advanceToNextInputMode()
//                }
//            }
//        }
        
//        if let funnyMessage = chatGPTHandler.fetchPendingMessage() {
//            print("oh funny!!" + funnyMessage)
//            textDocumentProxy.deleteBackward()
//            textDocumentProxy.insertText(funnyMessage)
//            chatGPTHandler.clearPendingMessage()
//        }
        
        // Switch back to the standard keyboard
//        self.advanceToNextInputMode()
//    }

    
    // This function is now replaced by the APIManager

    private func preloadSuggestionsIfNeeded() {
        // Only preload if authenticated and not already processing
        guard isUserAuthenticated() && !isBatchPreloading && !isProcessingRequest else { return }

        // Get current text
        guard let currentText = textDocumentProxy.documentContextBeforeInput?.trimmingCharacters(in: .whitespacesAndNewlines),
              !currentText.isEmpty else { return }

        // Check if we need to refresh cache for this text
        guard APIManager.shared.shouldRefreshCache(for: currentText) else { return }

        // Avoid preloading the same text multiple times
        guard lastPreloadedText != currentText else { return }

        lastPreloadedText = currentText
        isBatchPreloading = true

        print("Preloading suggestions for text: \(currentText)")

        // Extract all context keys from button titles
        let contexts = buttonTitlesAndContexts.map { $0.0 }

        APIManager.shared.generateBatchSuggestions(for: currentText, contexts: contexts) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isBatchPreloading = false

                switch result {
                case .success(let suggestions):
                    print("Successfully preloaded \(suggestions.count) context suggestions")
                    APIManager.shared.cacheSuggestions(suggestions, for: currentText)
                case .failure(let error):
                    print("Failed to preload suggestions: \(error.localizedDescription)")
                    // Clear cache on error to allow retry
                    APIManager.shared.clearCache()
                    self.lastPreloadedText = nil
                }
            }
        }
    }

    @objc func handleButtonTap(_ sender: UIButton) {
        // Prevent multiple simultaneous requests
        guard !isProcessingRequest else { return }

        let index = sender.tag
        if let originalText = self.textDocumentProxy.documentContextBeforeInput {
            startLoadingAnimation(for: sender, buttonIndex: index)
            requestMessageConversion(originalText: originalText, index: index)
        }
    }

    private func processSuggestions(_ suggestions: [String], originalText: String, inputText: String, index: Int) {
        self.stopLoadingAnimation()

        guard !suggestions.isEmpty else {
            print("Received empty suggestions.")
            return
        }

        let firstSuggestion = suggestions[0]

        for _ in 0 ..< originalText.count {
            self.textDocumentProxy.deleteBackward()
        }

        // Get existing suggestions if we have any, or start with empty array
        var allSuggestions: [String] = []
        var currentSuggestionIndex = 0

        if let existingTextInfo = self.textHistoryStack.last, existingTextInfo.contextIndex == index {
            // We're regenerating for the same context, append to existing suggestions
            allSuggestions = existingTextInfo.suggestions
            currentSuggestionIndex = allSuggestions.count // Start at first new suggestion
        }

        allSuggestions.append(contentsOf: suggestions)

        let textHistory = TextHistory(originalText: inputText, convertedText: firstSuggestion, contextIndex: index, suggestions: allSuggestions, suggestionIndex: currentSuggestionIndex)

        if let textInfo = self.textHistoryStack.popLast() {
            self.updateActiveButton(at: textInfo.contextIndex, active: false)
        }

        self.textHistoryStack.append(textHistory)
        if self.textHistoryStack.count > 10 {
            self.textHistoryStack.removeFirst()
        }

        self.updateActiveButton(at: index, active: true)
        self.textDocumentProxy.insertText(firstSuggestion)
    }

    func requestMessageConversion(originalText: String, index: Int) {
        let (contextKey, context) = buttonTitlesAndContexts[index]
        var inputText = originalText

        // Always use the original text from history if we have any transformations
        // This ensures we always transform the user's original text, not previous AI responses
        if let textInfo = textHistoryStack.last {
            inputText = textInfo.originalText
        }

        // If batch preloading is in progress, wait for it to complete
        if isBatchPreloading {
            print("Batch preloading in progress, waiting for completion...")
            // Wait for batch to complete, then check cache again
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.requestMessageConversion(originalText: originalText, index: index)
            }
            return
        }

        // Check if we have cached suggestions for this context key
        if let cachedSuggestions = APIManager.shared.getCachedSuggestions(for: contextKey), !cachedSuggestions.isEmpty {
            // Check if we're regenerating and have already used all cached suggestions
            if let existingTextInfo = self.textHistoryStack.last,
               existingTextInfo.contextIndex == index,
               existingTextInfo.suggestionIndex >= cachedSuggestions.count - 1 {
                print("Regenerating: cached suggestions exhausted, making fresh API call for context: \(contextKey)")
                // Fall through to make fresh API call
            } else {
                print("Using cached suggestions for context: \(contextKey)")
                self.processSuggestions(cachedSuggestions, originalText: originalText, inputText: inputText, index: index)
                return
            }
        }

        // Fall back to individual API call if no cached suggestions
        print("No cached suggestions found, making individual API call for context: \(contextKey)")
        APIManager.shared.generateSuggestions(for: inputText, context: contextKey) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let suggestions):
                    self.processSuggestions(suggestions, originalText: originalText, inputText: inputText, index: index)

                case .failure(let error):
                    self.stopLoadingAnimation()

                    // Check if this is a 401 authentication error (token expired)
                    if let nsError = error as NSError?, nsError.code == 401 {
                        // Token has expired, clear cache and switch to unauthenticated UI
                        self.cachedAuthState = false
                        self.lastAuthCheck = Date()

                        self.view.subviews.forEach { $0.removeFromSuperview() }
                        self.contextButtons.removeAll()
                        self.textHistoryStack.removeAll()
                        self.setupGradientBackground()
                        self.setupUnauthenticatedUI()

                        print("Authentication token expired: \(error.localizedDescription)")
                    } else {
                        // Handle other types of errors
                        print("Error generating suggestions: \(error.localizedDescription)")
                        // Optionally, you could show an alert to the user here.
                    }
                }
            }
        }
    }
    
    @objc func undoButtonTapped() {
        // Handle undo button tap
        guard let textInfo = textHistoryStack.popLast() else {
            print("No textInfo!")
            return
        }

        // Delete the converted text
        for _ in textInfo.convertedText {
            textDocumentProxy.deleteBackward()
        }
        updateActiveButton(at: textInfo.contextIndex, active: false)

        // Insert the original text
        textDocumentProxy.insertText(textInfo.originalText)
    }

    @objc func clearButtonTapped() {
        if let originalText = self.textDocumentProxy.documentContextBeforeInput {
            for _ in 0 ..< originalText.count {
                self.textDocumentProxy.deleteBackward()
            }
        }
        guard let textInfo = textHistoryStack.last else {
            return
        }
        updateActiveButton(at: textInfo.contextIndex, active: false)
        textHistoryStack = []
    }

    @objc func regenerateButtonTapped() {
        print("REGEN")
        // Prevent multiple simultaneous requests
        guard !isProcessingRequest else { return }

        guard var textInfo = textHistoryStack.popLast() else {
            print("No textInfo!")
            return
        }

        // Check if we have more suggestions in the current batch
        let nextIndex = textInfo.suggestionIndex + 1

        if nextIndex < textInfo.suggestions.count {
            // Still have suggestions in current batch, use the next one
            // Delete the current text and insert the new suggestion
            for _ in textInfo.convertedText {
                textDocumentProxy.deleteBackward()
            }

            textInfo.suggestionIndex = nextIndex
            let nextSuggestion = textInfo.suggestions[textInfo.suggestionIndex]
            textInfo.convertedText = nextSuggestion

            // Insert the new suggestion
            textDocumentProxy.insertText(nextSuggestion)

            // Push the updated history back onto the stack
            textHistoryStack.append(textInfo)
        } else {
            // We've reached the end of current suggestions, request more from backend
            // DON'T delete text yet - keep it until we get new suggestions
            // Put the textInfo back and call requestMessageConversion which will handle text replacement
            textHistoryStack.append(textInfo)

            // Find the regenerate button to show loading animation
            if let regenerateButton = findRegenerateButton() {
                startLoadingAnimation(for: regenerateButton, buttonIndex: textInfo.contextIndex)
            }

            requestMessageConversion(originalText: textInfo.originalText, index: textInfo.contextIndex)
        }
    }

    private func findRegenerateButton() -> UIButton? {
        // Find the regenerate button by looking for the arrow.clockwise system image
        return view.subviews.compactMap { subview in
            return subview.subviews.compactMap { innerView in
                return innerView as? UIButton
            }.first { button in
                button.currentImage == UIImage(systemName: "arrow.clockwise")
            }
        }.first
    }

    @objc func keyboardSwitchButtonTapped() {
        // Switch to the next keyboard (typically the system keyboard)
        self.advanceToNextInputMode()
    }

    func createModernContextButton(title: String, colorTheme: (UIColor, UIColor), tag: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.tag = tag
        button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)

        // Modern styling with better text handling
        button.layer.cornerRadius = 16
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.textAlignment = .center

        // Better content edge insets for text fitting
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)

        // Set text color to white for better contrast
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.white, for: .selected)
        button.setTitleColor(.white, for: .highlighted)

        // Add shadow
        button.layer.shadowColor = colorTheme.0.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.layer.shadowOpacity = 0.3
        button.layer.masksToBounds = false

        // Add touch animations
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        // Set up gradient background after view layout (no longer needs async dispatch)
        DispatchQueue.main.async { [weak button] in
            guard let button = button else { return }
            self.setupGradientForButton(button, colorTheme: colorTheme)
        }

        return button
    }

    func setupGradientForButton(_ button: UIButton, colorTheme: (UIColor, UIColor)) {
        // Remove any existing gradient layers to prevent memory leaks
        button.layer.sublayers?.removeAll { $0 is CAGradientLayer }

        // Create gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [colorTheme.0.cgColor, colorTheme.1.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16
        gradientLayer.frame = button.bounds

        // Store gradient layer as a property we can access later
        button.layer.setValue(gradientLayer, forKey: "gradientLayer")
        button.layer.insertSublayer(gradientLayer, at: 0)
    }

    @objc func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    @objc func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform.identity
        }
    }

    func updateActiveButton(at index: Int, active: Bool) {
        guard index < contextButtons.count else { return }
        let button = contextButtons[index]

        if active {
            // Add a bright border for active state
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.cgColor

            // Add a subtle glow effect
            button.layer.shadowColor = UIColor.white.cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 0)
            button.layer.shadowRadius = 8
            button.layer.shadowOpacity = 0.6

            // Slight scale animation
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut], animations: {
                button.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
            })
        } else {
            // Remove border and glow for inactive state
            button.layer.borderWidth = 0

            // Restore original shadow (from gradient color)
            if let gradientLayer = button.layer.value(forKey: "gradientLayer") as? CAGradientLayer,
               let firstColor = gradientLayer.colors?.first {
                button.layer.shadowColor = firstColor as! CGColor
                button.layer.shadowOffset = CGSize(width: 0, height: 4)
                button.layer.shadowRadius = 8
                button.layer.shadowOpacity = 0.3
            }

            // Reset scale
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut], animations: {
                button.transform = CGAffineTransform.identity
            })
        }
    }
    
    func createUndoButton() -> UIButton {
        let button = createModernActionButton(
            systemImage: "arrow.uturn.left",
            gradientColors: (UIColor.systemBlue, UIColor.systemBlue.withAlphaComponent(0.7)),
            action: #selector(undoButtonTapped)
        )

        // Add special undo animation
        button.addTarget(self, action: #selector(undoButtonAnimation(_:)), for: .touchUpInside)

        return button
    }

    func createClearButton() -> UIButton {
        let button = createModernActionButton(
            systemImage: "xmark",
            gradientColors: (UIColor.systemRed, UIColor.systemRed.withAlphaComponent(0.7)),
            action: #selector(clearButtonTapped)
        )

        // Add special clear animation
        button.addTarget(self, action: #selector(clearButtonAnimation(_:)), for: .touchUpInside)

        return button
    }
    
    func createRegenerateButton() -> UIButton {
        let button = createModernActionButton(
            systemImage: "arrow.clockwise",
            gradientColors: (UIColor.systemGreen, UIColor.systemGreen.withAlphaComponent(0.7)),
            action: #selector(regenerateButtonTapped)
        )

        // Add special regenerate animation
        button.addTarget(self, action: #selector(regenerateButtonAnimation(_:)), for: .touchUpInside)

        return button
    }

    func createKeyboardSwitchButton() -> UIButton {
        let button = createModernActionButton(
            systemImage: "keyboard",
            gradientColors: (UIColor.systemPurple, UIColor.systemPurple.withAlphaComponent(0.7)),
            action: #selector(keyboardSwitchButtonTapped)
        )

        // Add special keyboard switch animation
        button.addTarget(self, action: #selector(keyboardSwitchButtonAnimation(_:)), for: .touchUpInside)

        return button
    }

    func startLoadingAnimation(for button: UIButton, buttonIndex: Int) {
        isProcessingRequest = true
        currentLoadingButton = button

        // Create pulsing dotted border animation
        createDottedLoadingBorder(for: button)

        // Disable user interaction during loading
        contextButtons.forEach { $0.isUserInteractionEnabled = false }
    }

    func stopLoadingAnimation() {
        isProcessingRequest = false

        guard let loadingButton = currentLoadingButton else { return }

        // Remove dotted border animation
        removeDottedLoadingBorder(from: loadingButton)

        // Re-enable user interaction
        contextButtons.forEach { $0.isUserInteractionEnabled = true }
        currentLoadingButton = nil
    }

    func createDottedLoadingBorder(for button: UIButton) {
        // Create dotted border layer that matches button exactly
        let dottedBorder = CAShapeLayer()

        // Use button's exact bounds and corner radius
        let buttonCornerRadius = button.layer.cornerRadius
        let path = UIBezierPath(roundedRect: button.bounds, cornerRadius: buttonCornerRadius)
        dottedBorder.path = path.cgPath
        dottedBorder.fillColor = UIColor.clear.cgColor
        dottedBorder.strokeColor = UIColor.white.cgColor
        dottedBorder.lineWidth = 2 // Same width as the future solid border
        dottedBorder.lineDashPattern = [6, 3] // Smaller, more refined dashes
        dottedBorder.frame = button.bounds

        // Match the button's corner radius exactly
        dottedBorder.cornerRadius = buttonCornerRadius

        // Add pulsing opacity animation
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.4
        pulseAnimation.toValue = 0.9
        pulseAnimation.duration = 0.6
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = Float.infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

        dottedBorder.add(pulseAnimation, forKey: "pulseOpacity")

        // Add subtle rotating dash animation
        let rotateAnimation = CABasicAnimation(keyPath: "lineDashPhase")
        rotateAnimation.fromValue = 0
        rotateAnimation.toValue = 9 // Length of one dash + gap
        rotateAnimation.duration = 1.2
        rotateAnimation.repeatCount = Float.infinity
        rotateAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)

        dottedBorder.add(rotateAnimation, forKey: "rotateDash")

        // Store and add the border
        button.layer.setValue(dottedBorder, forKey: "dottedLoadingBorder")
        button.layer.addSublayer(dottedBorder)
    }

    func removeDottedLoadingBorder(from button: UIButton) {
        // Remove the dotted border layer
        if let dottedBorder = button.layer.value(forKey: "dottedLoadingBorder") as? CAShapeLayer {
            dottedBorder.removeAllAnimations()
            dottedBorder.removeFromSuperlayer()
            button.layer.setValue(nil, forKey: "dottedLoadingBorder")
        }
    }

    func createModernActionButton(systemImage: String, gradientColors: (UIColor, UIColor), action: Selector) -> UIButton {
        let button = UIButton(type: .system)

        // Set up the icon
        let image = UIImage(systemName: systemImage)
        button.setImage(image, for: .normal)
        button.tintColor = .white

        // Modern styling
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)

        // Create gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [gradientColors.0.cgColor, gradientColors.1.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 16

        // Add shadow
        button.layer.shadowColor = gradientColors.0.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.layer.shadowOpacity = 0.3

        // Add target action
        button.addTarget(self, action: action, for: .touchUpInside)

        // Add touch animations
        button.addTarget(self, action: #selector(actionButtonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(actionButtonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        // Add the gradient layer when the button is laid out
        DispatchQueue.main.async {
            gradientLayer.frame = button.bounds
            button.layer.insertSublayer(gradientLayer, at: 0)
        }

        return button
    }

    @objc func actionButtonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
    }

    @objc func actionButtonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform.identity
        }
    }

    // Special animations for each action button
    @objc func undoButtonAnimation(_ sender: UIButton) {
        // Bounce animation for undo
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
            sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                sender.transform = CGAffineTransform.identity
            }
        }
    }

    @objc func clearButtonAnimation(_ sender: UIButton) {
        // Shake animation for clear
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.3
        animation.values = [-8.0, 8.0, -6.0, 6.0, -4.0, 4.0, 0.0]
        sender.layer.add(animation, forKey: "shake")
    }

    @objc func regenerateButtonAnimation(_ sender: UIButton) {
        // Rotation animation for regenerate
        UIView.animate(withDuration: 0.4) {
            sender.transform = CGAffineTransform(rotationAngle: .pi)
        } completion: { _ in
            UIView.animate(withDuration: 0.4) {
                sender.transform = CGAffineTransform.identity
            }
        }
    }

    @objc func keyboardSwitchButtonAnimation(_ sender: UIButton) {
        // Slide animation for keyboard switch
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: {
            sender.transform = CGAffineTransform(translationX: 0, y: -8)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                sender.transform = CGAffineTransform.identity
            })
        }
    }

    func addGlassMorphismEffect(to view: UIView) {
        // Remove any existing glass morphism effects
        view.subviews.filter { $0 is UIVisualEffectView }.forEach { $0.removeFromSuperview() }
        view.subviews.filter { $0.backgroundColor != nil && $0.subviews.isEmpty }.forEach { $0.removeFromSuperview() }

        // Create blur effect
        let blurEffect = UIBlurEffect(style: traitCollection.userInterfaceStyle == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Create background with slight tint
        let backgroundView = UIView()
        if traitCollection.userInterfaceStyle == .dark {
            backgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        } else {
            backgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        }

        // Style the container
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor

        // Add shadow but don't clip to bounds
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 15
        view.layer.shadowOpacity = 0.1
        view.layer.masksToBounds = false

        // Insert background and blur effect
        view.insertSubview(backgroundView, at: 0)
        view.insertSubview(blurEffectView, at: 1)

        // Set up constraints for background and blur
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            blurEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Ensure blur effect is clipped to bounds
        blurEffectView.layer.cornerRadius = 20
        blurEffectView.layer.masksToBounds = true
        backgroundView.layer.cornerRadius = 20
        backgroundView.layer.masksToBounds = true
    }

    func createCustomButton(title: String, backgroundColor: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 10
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}
