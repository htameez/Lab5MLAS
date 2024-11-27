//
//  HomeViewController.swift
//  Lab5MLAS
//
//  Created by Hamna Tameez on 11/26/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController {
    
    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var tutorialButton: UIButton!
    
    let client = MlaasModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Ensure the label is visible and displays loading sequence
        messageLabel.isHidden = false
        tutorialButton.alpha = 0
        prepareDatasetAndShowMessages()
    }
    
    private func prepareDatasetAndShowMessages() {
        // Path to the dataset on the server
        let dataPath = "/Users/hamnatameez/CS5323/Lab5Python/datasets/ahcd/Train Images 13440x32x32/train"
        
        // Display the first message and start preparing the dataset
        updateLabelWithFade("Loading necessary data...")
        client.prepareDataset(dsid: 1, dataPath: dataPath) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    // Show the welcome message after dataset preparation is complete
                    self?.updateLabelWithFade("Welcome to Alif Ba Ta!")
                    UIView.animate(withDuration: 0.5) {
                        self?.tutorialButton.alpha = 1.0
                        self?.tutorialButton.isHidden = false
                    }
                } else {
                    // Show error alert if dataset preparation fails
                    let errorMessage = errorMessage ?? "Unknown error"
                    self?.showAlert(title: "Dataset Preparation Failed", message: errorMessage)
                }
            }
        }
        
        // Schedule the next messages with delays
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            self?.updateLabelWithFade("Almost done...")
        }
    }
    
    private func updateLabelWithFade(_ newText: String) {
        // Crossfade transition for the label
        UIView.transition(with: messageLabel,
                          duration: 0.5, // Fade duration
                          options: .transitionCrossDissolve,
                          animations: { [weak self] in
                              self?.messageLabel.text = newText
                          },
                          completion: nil)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}


