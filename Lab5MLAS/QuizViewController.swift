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
    var drawnPath = UIBezierPath()
    var drawnLayer = CAShapeLayer()
    var boundingBoxLayer = CAShapeLayer()
    var currentLetter = ""
    var quizResults: [(expected: String, predicted: String)] = []
    let arabicLetters = ["ا", "ب", "ت", "ث", "ج"]
    var currentIndex = 0


    let client = MlaasModel()
   
    // MARK: - IBOutlets
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!

    // MARK: - Properties
    var arabicLettersMapping: [Int: String] = [
        0: "ا", // Alif
        1: "ب", // Ba
        2: "ت", // Ta
        3: "ث", // Tha
        4: "ج"  // Jeem
    ]

    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupDrawingLayer()
        setupBoundingBox()
        setupButtons()
        
        loadNextQuestion()
    }

    func setupDrawingLayer() {
        drawnLayer.strokeColor = UIColor.white.cgColor
        drawnLayer.lineWidth = 19.0
        drawnLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(drawnLayer)
    }

    func setupBoundingBox() {
        let boxWidth: CGFloat = 300
        let boxHeight: CGFloat = 300
        let centerX = view.bounds.midX
        let centerY = view.bounds.midY

        let boundingBox = CGRect(x: centerX - boxWidth / 2, y: centerY - boxHeight / 2, width: boxWidth, height: boxHeight)
        boundingBoxLayer.path = UIBezierPath(rect: boundingBox).cgPath
        boundingBoxLayer.strokeColor = UIColor.blue.cgColor
        boundingBoxLayer.lineWidth = 2.0
        boundingBoxLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(boundingBoxLayer)
    }

    func setupButtons() {
        submitButton.isEnabled = false
        clearButton.isEnabled = false
    }

    // MARK: - Load Question
    func loadNextQuestion() {
        resetDrawing()
        if currentIndex < arabicLetters.count {
            currentLetter = arabicLetters[currentIndex]
            instructionsLabel.text = "Write the letter: \(currentLetter)"
            progressView.progress = Float(currentIndex) / Float(arabicLetters.count)
        } else {
            progressView.progress = 1.0
            showResults()
        }
    }

    // MARK: - Reset Drawing
    func resetDrawing() {
        drawnPath = UIBezierPath()
        touchCoordinates.removeAll()
        drawnLayer.path = nil
        submitButton.isEnabled = false
        clearButton.isEnabled = false
    }

    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)
        drawnPath.move(to: point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)

        if let boundingBoxPath = boundingBoxLayer.path, boundingBoxPath.contains(point) {
            drawnPath.addLine(to: point)
            drawnLayer.path = drawnPath.cgPath
            touchCoordinates.append((x: Double(point.x), y: Double(point.y)))

            if !submitButton.isEnabled {
                submitButton.isEnabled = true
                clearButton.isEnabled = true
            }
        }
    }

    // MARK: - Submit
    @IBAction func submitButtonPressed(_ sender: UIButton) {
        guard let boundingBox = boundingBoxLayer.path?.boundingBox else {
            print("Bounding box is not available")
            return
        }

        // Capture the user-drawn image
        guard let capturedImage = viewToImage() else {
            showAlert(title: "Error", message: "Failed to capture drawing.")
            return
        }
        
        // Crop the image to the bounding box
        guard let croppedImage = cropImageToBoundingBox(capturedImage, boundingBox: boundingBox) else {
            print("Failed to crop image to bounding box")
            return
        }
        
        guard let grayscaleImage = self.convertToGrayscale(image: croppedImage) else {
            print("Failed to convert image to grayscale")
            return
        }
    
        // Extract features from the cropped image
        let features = extractFeatures(from: grayscaleImage)
                
        // Predict using the model
        client.predict(dsid: 1, feature: features) { result in
            DispatchQueue.main.async {
                print("Result from prediction API: \(result)") // Log the entire result

                switch result {
                case .success(let predictedLabel):
                    print("Raw predictedLabel: \(predictedLabel)") // Log raw predictedLabel
                    if let predictedInt = Int(predictedLabel), // Try converting to Int
                       let mappedLetter = self.arabicLettersMapping[predictedInt] {
                        print("Mapped letter: \(mappedLetter)")
                        self.quizResults.append((expected: self.currentLetter, predicted: mappedLetter))

                        // Show immediate feedback
                        if mappedLetter == self.currentLetter {
                            self.showAlert(title: "Correct!", message: "You wrote \(mappedLetter) correctly!")
                            // Clear drawing and move to the next question
                            self.resetDrawing()
                            self.currentIndex += 1
                            self.loadNextQuestion()
                        } else {
                            self.showAlert(title: "Incorrect!", message: "Expected \(self.currentLetter), but got \(mappedLetter).")
                            // Clear drawing and move to the next question
                            self.resetDrawing()
                            self.currentIndex += 1
                            self.loadNextQuestion()
                        }
                    } else {
                        print("Prediction \(predictedLabel) is invalid or does not map to a valid letter.")
                        self.showAlert(title: "Error", message: "Invalid prediction received.")
                    }
                case .failure(let error):
                    print("Prediction failed: \(error.localizedDescription)")
                    self.showAlert(title: "Prediction Failed", message: error.localizedDescription)
                }
            }
        }
    }

    
    func cropImageToBoundingBox(_ image: UIImage, boundingBox: CGRect) -> UIImage? {
        // Adjust the bounding box to slightly crop inside the green border
        let scale = UIScreen.main.scale
        let margin: CGFloat = 2.0
        let scaledBoundingBox = CGRect(
            x: (boundingBox.origin.x + margin) * scale,
            y: (boundingBox.origin.y + margin) * scale,
            width: (boundingBox.width - 2 * margin) * scale,
            height: (boundingBox.height - 2 * margin) * scale
        )
        
        // Ensure the bounding box is within the image bounds
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: scaledBoundingBox) else {
            print("Failed to crop image to bounding box")
            return nil
        }

        let targetSize = CGSize(width: 32, height: 32)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        UIImage(cgImage: croppedCGImage).draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }

    func extractFeatures(from image: UIImage) -> [Double] {
        guard let cgImage = image.cgImage else {
            print("Error: Could not extract CGImage.")
            return []
        }
        let width = Int(image.size.width)
        let height = Int(image.size.height)

        // Create a buffer for grayscale pixel data
        var pixelData = [UInt8](repeating: 0, count: width * height)

    
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let features = pixelData.map { Double($0) / 255.0 }
        if features.count != 1024 { 
            print("Warning: Feature vector has incorrect length \(features.count).")
        }
        return features
    }


    // MARK: - Clear
    @IBAction func clearButtonPressed(_ sender: UIButton) {
        resetDrawing()
    }

    // MARK: - Results
    func showResults() {
        let correctCount = quizResults.filter { $0.expected == $0.predicted }.count
        let totalQuestions = quizResults.count
        let message = "Correct Answers: \(correctCount)/\(totalQuestions)"
        showPostQuizOptions(message: message)
    }

    func showPostQuizOptions(message: String) {
        let alert = UIAlertController(title: "Quiz Complete", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Go Home", style: .default, handler: { _ in
            self.navigateToHome()
        }))
        alert.addAction(UIAlertAction(title: "Take Quiz Again", style: .default, handler: { _ in
            self.restartQuiz()
        }))
        present(alert, animated: true, completion: nil)
    }

    func navigateToHome() {
        navigationController?.popToRootViewController(animated: true)
    }

    func restartQuiz() {
        progressView.progress = 0.0
        quizResults.removeAll()
        currentIndex = 0
        loadNextQuestion()
    }

    func viewToImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 1.0)
        if let context = UIGraphicsGetCurrentContext() {
            // Fill the context with black
            context.setFillColor(UIColor.black.cgColor)
            context.fill(view.bounds)
        }
        // Draw the view hierarchy over the black background
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    func convertToGrayscale(image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        if let grayImage = context?.makeImage() {
            return UIImage(cgImage: grayImage)
        }
        return nil
    }


    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
        present(alert, animated: true)
    }
}
