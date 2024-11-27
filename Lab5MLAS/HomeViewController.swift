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
    @IBOutlet weak var selectModelButton: UIButton!
    @IBOutlet weak var compareModelsButton: UIButton!
    @IBOutlet weak var selectedModelLabel: UILabel!
    @IBOutlet weak var quizButton: UIButton!

    @IBAction func selectModelButtonTapped(_ sender: UIButton) {
        selectModel()
    }

    @IBAction func compareModelsButtonTapped(_ sender: UIButton) {
        compareModels()
    }

    @IBAction func quizButtonTapped(_ sender: UIButton) {
        let isTrained = UserDefaults.standard.bool(forKey: "isTrained")
        if isTrained {
            performSegue(withIdentifier: "showQuizSegue", sender: self)
        } else {
            showAlert(title: "Training Required", message: "Please train the model before starting the quiz.")
        }
    }

    let client = MlaasModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        selectModelButton.isEnabled = false
        quizButton.isEnabled = false  // Initially, disable quiz button

        // Check if a model has been selected and update the UI accordingly
        if let selectedModel = UserDefaults.standard.string(forKey: "SelectedModelType"), !selectedModel.isEmpty {
            selectedModelLabel.text = "Selected Model: \(selectedModel)"
            tutorialButton.isEnabled = true
            quizButton.isEnabled = UserDefaults.standard.bool(forKey: "isTrained") // Enable only if trained
        } else {
            selectedModelLabel.text = "No model selected"
            tutorialButton.isEnabled = false
            quizButton.isEnabled = false
        }

        // Ensure the label is visible and displays the loading sequence
        messageLabel.isHidden = false
        tutorialButton.alpha = 0
        selectModelButton.addTarget(self, action: #selector(selectModel), for: .touchUpInside)
        compareModelsButton.addTarget(self, action: #selector(compareModels), for: .touchUpInside)
        prepareDatasetAndShowMessages()
    }

    @objc private func selectModel() {
        let alert = UIAlertController(title: "Select Model", message: "Choose the machine learning model.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "KNN", style: .default, handler: { _ in
            UserDefaults.standard.set("KNN", forKey: "SelectedModelType")
            self.showAlert(title: "Model Selected", message: "KNN has been selected.")
            self.selectedModelLabel.text = "Selected Model: KNN"
        }))
        alert.addAction(UIAlertAction(title: "XGBoost", style: .default, handler: { _ in
            UserDefaults.standard.set("XGBoost", forKey: "SelectedModelType")
            self.showAlert(title: "Model Selected", message: "XGBoost has been selected.")
            self.selectedModelLabel.text = "Selected Model: XGBoost"
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func compareModels() {
        let dsid = 1
        let urlString = "http://\(client.server_ip):8000/compare_models/\(dsid)"
        guard let url = URL(string: urlString) else {
            showAlert(title: "Error", message: "Invalid URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let results = json["comparison_results"] as? [String: Double] else {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "Failed to compare models.")
                }
                return
            }

            // Format the results and show them
            let resultsText = results.map { "\($0.key): \($0.value * 100)%" }.joined(separator: "\n")
            DispatchQueue.main.async {
                self.showAlert(title: "Model Comparison Results", message: resultsText)
                // Enable Select Model button after comparison is done
                self.selectModelButton.isEnabled = true
            }
        }
        task.resume()
    }

    private func prepareDatasetAndShowMessages() {
        let dataPath = "/Users/zareenahmurad/Desktop/CS/CS5323/Lab5Python/datasets/ahcd/Train Images 13440x32x32/train"
        
        updateLabelWithFade("Loading necessary data...")
        client.prepareDataset(dsid: 1, dataPath: dataPath) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    self?.updateLabelWithFade("Welcome to Alif Ba Ta!")
                    UIView.animate(withDuration: 0.5) {
                        self?.tutorialButton.alpha = 1.0
                        self?.tutorialButton.isHidden = false
                    }

                    // Start training after tutorial data is prepared
                    self?.trainModelAndEnableQuiz()
                    
                } else {
                    let errorMessage = errorMessage ?? "Unknown error"
                    self?.showAlert(title: "Dataset Preparation Failed", message: errorMessage)
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
            self?.updateLabelWithFade("Almost done...")
        }
    }
  


    private func trainModelAndEnableQuiz() {
        // Ensure we have a model selected
        let selectedModel = UserDefaults.standard.string(forKey: "SelectedModelType") ?? "KNN"
        
        // Start training the model
        client.trainModel(dsid: 1, modelType: selectedModel) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Model trained successfully.")
                    
                    // Enable and show the quiz button after successful training
                    self?.quizButton.isEnabled = true
                    UIView.animate(withDuration: 0.5) {
                        self?.quizButton.alpha = 1.0
                        self?.quizButton.isHidden = false
                    }
                    
                    // Set the flag to true to indicate that the model has been trained
                    UserDefaults.standard.set(true, forKey: "isTrained")
                    
                case .failure(let error):
                    print("Training Failed: \(error.localizedDescription)")
                    self?.showAlert(title: "Training Failed", message: error.localizedDescription)
                }
            }
        }
    }


    private func navigateBackToHome() {
        // Assuming you're using a navigation controller
        if let navigationController = self.navigationController {
            navigationController.popToRootViewController(animated: true)
        }
    }

    private func updateLabelWithFade(_ newText: String) {
        UIView.transition(with: messageLabel,
                          duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: { [weak self] in
            self?.messageLabel.text = newText
        }, completion: nil)
    }
}
