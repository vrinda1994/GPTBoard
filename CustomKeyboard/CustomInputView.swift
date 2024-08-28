//
//  CustomInputView.swift
//  CustomKeyboard
//
//  Created by Karan Khurana on 4/12/23.
//

import UIKit

class CustomInputView: UIView {
    let convertButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Convert", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemGray
        addSubview(convertButton)
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            convertButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            convertButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            convertButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
}

