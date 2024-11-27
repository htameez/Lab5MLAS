//
//  UIViewController+Extensions.swift
//  Lab5MLAS
//
//  Created by Zareenah Murad on 11/26/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit

extension UIViewController {
    func showAlert(title: String, message: String, actionTitle: String = "OK", completion: (() -> Void)? = nil) {
        // Check if an alert is already being presented
        if self.presentedViewController is UIAlertController {
            print("Alert already being presented.")
            return
        }
        
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in
                completion?()
            })
            self.present(alert, animated: true)
        }
    }
}

