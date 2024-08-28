//
//  SceneDelegate.swift
//  GPTBoard
//
//  Created by Karan Khurana on 4/10/23.
//

import UIKit

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) { }

    func sceneDidBecomeActive(_ scene: UIScene) { }

    func sceneWillResignActive(_ scene: UIScene) { }

    func sceneWillEnterForeground(_ scene: UIScene) { }

    func sceneDidEnterBackground(_ scene: UIScene) { }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url, url.scheme == "gptboardcontainerapp" {
            if let viewController = window?.rootViewController as? ViewController,
               let inputText = viewController.chatGPTHandler.fetchPendingMessage() {
                print("Going to convert!" + inputText)
                APIManager.shared.getFunnyMessage(for: inputText) { [weak viewController] funnyMessage in
                    DispatchQueue.main.async {
                        if let funnyMessage = funnyMessage {
                            print("Funny!" + funnyMessage)
                            viewController?.chatGPTHandler.savePendingMessage(funnyMessage)
                        } else {
                            print("Failed to generate funny message")
                        }
                    }
                }
            }
        }
    }
}

//class SceneDelegate: UIResponder, UIWindowSceneDelegate {
//
//    var window: UIWindow?
//
//    @available(iOSApplicationExtension 13.0, *)
//    func scene(_ scene: UIWindowScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
//        self.window = UIWindow(windowScene: scene)
//        self.window?.rootViewController = UIStoryboard(name: "GPTBoard", bundle: nil).instantiateInitialViewController()
//        self.window?.makeKeyAndVisible()
//    }
//
//}
