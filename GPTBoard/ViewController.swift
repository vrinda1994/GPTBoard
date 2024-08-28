//
//  ViewController.swift
//  GPTBoard
//
//  Created by Karan Khurana on 4/14/23.
//

import Foundation
import UIKit

class ViewController: UIViewController {
    public let chatGPTHandler = ChatGPTHandler()
    
    @IBOutlet weak var inputTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func convertButtonTapped(_ sender: UIButton) {
        guard let inputText = inputTextField.text, !inputText.isEmpty else { return }
        APIManager.shared.getFunnyMessage(for: inputText) { [weak self] funnyMessage in
            DispatchQueue.main.async {
                if let funnyMessage = funnyMessage {
                    self?.chatGPTHandler.savePendingMessage(funnyMessage)
                    self?.inputTextField.text = ""
                } else {
                    print("Failed to generate funny message")
                }
            }
        }
    }
}
