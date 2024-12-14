//
//  HomeViewController.swift
//  Lab5MLAS
//
//  Created by Hamna Tameez on 11/26/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var lesson1Button: UIButton!
    let client = MlaasModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black

        // Initial setup
        lesson1Button.isEnabled = false // Disabled until dataset is prepared
        updateLabelWithFade("Preparing dataset...")

        // Observer for tutorial completion
        NotificationCenter.default.addObserver(self, selector: #selector(tutorialCompleted), name: Notification.Name("TutorialCompleted"), object: nil)

        // Prepare the dataset
        prepareDatasetAndShowMessages()
    }

    // MARK: - Dataset Preparation
    private func prepareDatasetAndShowMessages() {
        let dataPath = "/Users/zareenahmurad/Desktop/CS/CS5323/Lab5Python/datasets/ahcd/Train Images 13440x32x32/train"

        client.prepareDataset(dsid: 1, dataPath: dataPath) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    self?.updateLabelWithFade("Dataset prepared. Start Lesson 1!")
                    self?.lesson1Button.isEnabled = true // Enable the button
                } else {
                    self?.showAlert(title: "Error", message: errorMessage ?? "Dataset preparation failed.")
                }
            }
        }
    }

    // MARK: - Button Action
    @IBAction func lesson1ButtonTapped(_ sender: UIButton) {
    }

    // MARK: - Tutorial Completed
    @objc private func tutorialCompleted() {
        print("Tutorial completed.")
        showPostTutorialAlert()
    }

    // MARK: - Post-Tutorial Options
    private func showPostTutorialAlert() {
        let alert = UIAlertController(
            title: "Tutorial Complete",
            message: "You have completed the tutorial. What would you like to do next?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Go to Quiz", style: .default, handler: { _ in
            self.navigateToQuiz()
        }))
        alert.addAction(UIAlertAction(title: "Learn Again", style: .default, handler: { _ in
            self.navigateToTutorial()
        }))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Navigation Methods
    private func navigateToQuiz() {
        if let quizViewController = storyboard?.instantiateViewController(withIdentifier: "QuizViewController") {
            navigationController?.pushViewController(quizViewController, animated: true)
        }
    }

    private func navigateToTutorial() {
        if let tutorialViewController = storyboard?.instantiateViewController(withIdentifier: "TutorialViewController") {
            navigationController?.pushViewController(tutorialViewController, animated: true)
        }
    }

    // MARK: - Helper Methods
    private func updateLabelWithFade(_ newText: String) {
        UIView.transition(with: messageLabel,
                          duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: { self.messageLabel.text = newText },
                          completion: nil)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
