//
//  QuizViewController.swift
//  Lab5MLAS
//
//  Created by Hamna Tameez on 11/26/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit

class QuizViewController: UIViewController {

    // MARK: - Properties
    var touchCoordinates = [(x: Double, y: Double)]()
    var drawnPath = UIBezierPath() // Path for user's drawing
    var drawnLayer = CAShapeLayer() // Layer for the user's drawing
    var currentLetter: String = "" // The letter the user needs to draw
    var quizResults: [(expected: String, predicted: String, accuracy: Double?)] = []
    let arabicLetters = ["ا", "ب", "ت", "ث", "ج"] // Letters for the quiz
    
    var currentIndex = 0
    let client = MlaasModel()

    // MARK: - IBOutlets
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var submitButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure the drawing layer
        drawnLayer.strokeColor = UIColor.red.cgColor
        drawnLayer.lineWidth = 5.0
        drawnLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(drawnLayer)

        // Initialize the progress bar
        progressView.progress = 0.0

        loadNextQuestion()
    }

    func loadNextQuestion() {
        resetDrawing()
        
        if currentIndex < arabicLetters.count {
            currentLetter = arabicLetters[currentIndex]
            instructionsLabel.text = "Draw the letter: \(currentLetter)"
            
            // Update progress bar
            progressView.progress = Float(currentIndex) / Float(arabicLetters.count)
        } else {
            // Quiz is complete
            progressView.progress = 1.0
            showResults()
        }
    }

    func resetDrawing() {
        drawnPath = UIBezierPath()
        touchCoordinates.removeAll()
        drawnLayer.path = nil
    }

    // MARK: - Drawing Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)
        drawnPath.move(to: point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)
        drawnPath.addLine(to: point)
        drawnLayer.path = drawnPath.cgPath
        touchCoordinates.append((x: Double(point.x), y: Double(point.y)))
    }

    // MARK: - Submit Drawing for Evaluation
    @IBAction func submitButtonPressed(_ sender: UIButton) {
        // Normalize and flatten the user's drawing into a 1024-element feature vector
        let normalizedCoordinates = normalizeCoordinates(touchCoordinates)
        let featureVector = flattenCoordinates(normalizedCoordinates)
        
        print("Submit Button Pressed, featureVector: \(featureVector)") // Debugging

        // Validate the drawing before sending
        if touchCoordinates.count < 5 {
            showAlert(title: "Error", message: "Please draw more for a valid submission.")
            return
        }

        // Retrieve the selected model type
        let selectedModel = UserDefaults.standard.string(forKey: "SelectedModelType") ?? "KNN"

        // Call the API to evaluate the user's input
        client.predict(dsid: 1, feature: featureVector, modelType: selectedModel) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                print("API call completed.")  // Debugging

                switch result {
                case .success(let prediction):
                    print("Prediction received: \(prediction)")
                    self.quizResults.append((expected: self.currentLetter, predicted: prediction, accuracy: nil))
                case .failure(let error):
                    print("Prediction error: \(error.localizedDescription)")
                    self.quizResults.append((expected: self.currentLetter, predicted: "Error", accuracy: nil))
                }
                
                // Move to the next question or show final results
                if self.currentIndex < self.arabicLetters.count - 1 {
                    self.currentIndex += 1
                    self.loadNextQuestion()
                } else {
                    self.showResults()
                }
            }
        }
    }


    // MARK: - Helper Methods
    func normalizeCoordinates(_ coordinates: [(x: Double, y: Double)]) -> [(x: Double, y: Double)] {
        // Scale coordinates to fit within a 32x32 grid
        let screenWidth = Double(UIScreen.main.bounds.width)
        let screenHeight = Double(UIScreen.main.bounds.height)
        return coordinates.map { (x: $0.x / screenWidth * 32.0, y: $0.y / screenHeight * 32.0) }
    }

    func flattenCoordinates(_ coordinates: [(x: Double, y: Double)]) -> [Double] {
        // Create a 32x32 grid and initialize with zeros
        var grid = Array(repeating: Array(repeating: 0.0, count: 32), count: 32)

        // Mark the grid cells corresponding to the normalized coordinates
        for point in coordinates {
            let x = min(max(Int(point.x), 0), 31) // Ensure the index is within bounds
            let y = min(max(Int(point.y), 0), 31)
            grid[y][x] = 1.0 // Mark the cell as "drawn"
        }

        // Flatten the grid into a 1D array of 1024 elements
        return grid.flatMap { $0 }
    }
    
    // MARK: - Show Results
    func showResults() {
        let correctCount = quizResults.filter { $0.expected == $0.predicted }.count
        let totalQuestions = quizResults.count
        let message = """
        Quiz Complete!
        Correct Answers: \(correctCount)/\(totalQuestions)
        """
        showAlert(title: "Results", message: message)
    }
}

