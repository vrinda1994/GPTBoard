//
//  KeyboardViewController.swift
//  CustomKeyboard
//
//  Created by Karan Khurana on 4/10/23.
//

import UIKit
import Alamofire

class KeyboardViewController: UIInputViewController {
    struct TextHistory {
        let originalText: String
        var convertedText: String
        let contextIndex: Int
        let suggestions: [String]
        var suggestionIndex: Int
    }
    
    var textHistoryStack: [TextHistory] = []
    var contextButtons: [UIButton] = []

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
        // Set background color depending on the current user interface style
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = UIColor.systemGray6
        } else {
            view.backgroundColor = UIColor.systemGray3
        }

        // Setup UI components
        setupUI()
    }

    private func setupUI() {
        // Create action buttons and stack view
        let undoButton = createUndoButton()
        let clearButton = createClearButton()
        let regenerateButton = createRegenerateButton()

        let actionButtons = [undoButton, clearButton, regenerateButton]
        let actionButtonStack = UIStackView(arrangedSubviews: actionButtons)
        actionButtonStack.axis = .horizontal
        actionButtonStack.distribution = .fillEqually

        // Add the stack view to the main view
        view.addSubview(actionButtonStack)

        // Setup Auto Layout for the action buttons
        actionButtonStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            actionButtonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            actionButtonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            actionButtonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            actionButtonStack.heightAnchor.constraint(equalToConstant: 50)
        ])

        // Defer creation of the scrollView and buttonsStackView
//        DispatchQueue.main.async {
        self.setupScrollViewAndButtonsStackView()
//        }
    }

    private func setupScrollViewAndButtonsStackView() {
        let scrollView = UIScrollView()
        let buttonsStackView = createButtonsStackView()
        
        scrollView.addSubview(buttonsStackView)
        view.addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            scrollView.heightAnchor.constraint(equalToConstant: 150),

            buttonsStackView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            buttonsStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            buttonsStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])

        // Optionally, load buttons lazily
        DispatchQueue.global(qos: .userInitiated).async {
            let buttons = self.createButtonsForRows() // Create buttons in background
            DispatchQueue.main.async {
                buttons.forEach { buttonsStackView.addArrangedSubview($0) }
            }
        }
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
    
    func createButtonsForRows() -> [UIStackView] {
//        var buttons = [UIButton]()
        let numButtons = 3.0
        let numberOfRows = Int(ceil(Double(buttonTitlesAndContexts.count) / numButtons))
//        let maxWidth = UIScreen.main.bounds.width
//        let buttonWidth = maxWidth / 3 - 20;

        var rowStackViews = [UIStackView]()

        var index = 0
        for i in 0..<numberOfRows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .center
            rowStack.spacing = 10
            rowStack.distribution = .fillEqually
            
            let buttonsInThisRow = buttonTitlesAndContexts.dropFirst(i * Int(numButtons)).prefix(Int(numButtons))
            
            for (title, _) in buttonsInThisRow {
                let button = UIButton(type: .system)
                button.setTitle(title, for: .normal)
                button.layer.cornerRadius = 10
                button.backgroundColor = .white
                button.setTitleColor(.black, for: .normal)
                button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
                button.tag = index
                index = index + 1
                button.addTarget(self, action: #selector(handleButtonTap(_:)), for: .touchUpInside)
    
                button.layer.cornerRadius = 10
                button.backgroundColor = .white
                button.setTitleColor(.black, for: .normal)
                button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
                contextButtons.append(button)
                rowStack.addArrangedSubview(button)
            }
            
            rowStackViews.append(rowStack)
        }
        
        return rowStackViews
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
    }
    
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
    
    @objc func handleButtonTap(_ sender: UIButton) {
        let index = sender.tag
        if let originalText = self.textDocumentProxy.documentContextBeforeInput {
            requestMessageConversion(originalText: originalText, index: index)
        }
    }
    
    func requestMessageConversion(originalText: String, index: Int) {
        let (_, context) = buttonTitlesAndContexts[index]
        var inputText = originalText
        
        if let textInfo = textHistoryStack.last {
            if (textInfo.convertedText == inputText) {
                inputText = textInfo.originalText
            }
        }
        
        APIManager.shared.generateSuggestions(for: inputText, context: context) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                switch result {
                case .success(let suggestions):
                    guard !suggestions.isEmpty else {
                        print("Received empty suggestions.")
                        return
                    }
                    
                    let firstSuggestion = suggestions[0]
                    
                    for _ in 0 ..< originalText.count {
                        self.textDocumentProxy.deleteBackward()
                    }
                    
                    let textHistory = TextHistory(originalText: inputText, convertedText: firstSuggestion, contextIndex: index, suggestions: suggestions, suggestionIndex: 0)

                    if let textInfo = self.textHistoryStack.popLast() {
                        self.updateActiveButton(at: textInfo.contextIndex, active: false)
                    }
                    
                    self.textHistoryStack.append(textHistory)
                    if self.textHistoryStack.count > 10 {
                        self.textHistoryStack.removeFirst()
                    }
                    
                    self.updateActiveButton(at: index, active: true)
                    self.textDocumentProxy.insertText(firstSuggestion)

                case .failure(let error):
                    // The UI will no longer freeze because errors are handled.
                    print("Error generating suggestions: \(error.localizedDescription)")
                    // Optionally, you could show an alert to the user here.
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
        // Handle clear button tap
        guard var textInfo = textHistoryStack.popLast() else {
            print("No textInfo!")
            return
        }

        // Delete the converted text
        for _ in textInfo.convertedText {
            textDocumentProxy.deleteBackward()
        }
        
        // Get the next suggestion
        textInfo.suggestionIndex = (textInfo.suggestionIndex + 1) % textInfo.suggestions.count
        let nextSuggestion = textInfo.suggestions[textInfo.suggestionIndex]
        textInfo.convertedText = nextSuggestion
        
        // Insert the new suggestion
        textDocumentProxy.insertText(nextSuggestion)
        
        // Push the updated history back onto the stack
        textHistoryStack.append(textInfo)
    }

    func updateActiveButton(at index: Int, active: Bool) {
        let button = contextButtons[index]
        button.backgroundColor = active ? .systemBlue : .white
        button.setTitleColor(active ? .white : .black, for: .normal)
    }
    
    func createUndoButton() -> UIButton {
        let button = UIButton(type: .system)
        let undoImage = UIImage(systemName: "arrow.uturn.left")
        button.setImage(undoImage, for: .normal)
        
//        button.setTitle("Undo", for: .normal)
        button.backgroundColor = UIColor.systemGray3
        button.setTitleColor(.black, for: .normal)
//        button.layer.borderColor = UIColor.black.cgColor
//        button.layer.borderWidth = 1.0
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        
        
        button.addTarget(self, action: #selector(undoButtonTapped), for: .touchUpInside)
        return button
    }

    func createClearButton() -> UIButton {
        let button = UIButton(type: .system)
        
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        
//        button.setTitle("Clear", for: .normal)
        button.backgroundColor = UIColor.systemGray3
        button.setTitleColor(.black, for: .normal)
//        button.layer.borderColor = UIColor.black.cgColor
//        button.layer.borderWidth = 1.0
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        
        button.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        return button
    }
    
    func createRegenerateButton() -> UIButton {
        let button = UIButton(type: .system)
//        button.setTitle("Regenerate", for: .normal)
        button.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        
        button.backgroundColor = UIColor.systemGray3
        button.setTitleColor(.black, for: .normal)
//        button.layer.borderColor = UIColor.black.cgColor
//        button.layer.borderWidth = 1.0
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        
        button.addTarget(self, action: #selector(regenerateButtonTapped), for: .touchUpInside)
        return button
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
