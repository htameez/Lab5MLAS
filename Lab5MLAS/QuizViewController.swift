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
        0: "ا", 1: "ب", 2: "ت", 3: "ث", 4: "ج", 5: "ح", 6: "خ",
        7: "د", 8: "ذ", 9: "ر", 10: "ز", 11: "س", 12: "ش",
        13: "ص", 14: "ض", 15: "ط", 16: "ظ", 17: "ع", 18: "غ",
        19: "ف", 20: "ق", 21: "ك", 22: "ل", 23: "م", 24: "ن",
        25: "ه", 26: "و", 27: "ي"
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

        // Ensure the point is within the bounding box
        if let boundingBoxPath = boundingBoxLayer.path, boundingBoxPath.contains(point) {
            drawnPath.addLine(to: point)
            drawnLayer.path = drawnPath.cgPath
            touchCoordinates.append((x: Double(point.x), y: Double(point.y)))

            if !submitButton.isEnabled {
                submitButton.isEnabled = true
                clearButton.isEnabled = true
            }
        } else {
            print("Touch point is outside the bounding box:", point)
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
        
        print("Captured and cropped image: \(croppedImage.size)")

        // Extract features from the cropped image
        let features = extractFeatures(from: croppedImage)
        print("Extracted Features: \(features)")
        
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
        // Log bounding box dimensions
        print("Original Bounding Box:", boundingBox)

        let scale = UIScreen.main.scale
        let margin: CGFloat = 2.0
        let scaledBoundingBox = CGRect(
            x: (boundingBox.origin.x + margin) * scale,
            y: (boundingBox.origin.y + margin) * scale,
            width: (boundingBox.width - 2 * margin) * scale,
            height: (boundingBox.height - 2 * margin) * scale
        )

        // Log scaled bounding box dimensions
        print("Scaled Bounding Box:", scaledBoundingBox)
        print("Image Size:", image.size)

        // Ensure the bounding box is within the image bounds
        guard let cgImage = image.cgImage,
              scaledBoundingBox.origin.x >= 0,
              scaledBoundingBox.origin.y >= 0,
              scaledBoundingBox.maxX <= CGFloat(cgImage.width),
              scaledBoundingBox.maxY <= CGFloat(cgImage.height) else {
            print("Error: Scaled bounding box is out of image bounds")
            return nil
        }

        guard let croppedCGImage = cgImage.cropping(to: scaledBoundingBox) else {
            print("Failed to crop image to bounding box")
            return nil
        }

        // Resize the cropped image to 32x32
        let targetSize = CGSize(width: 32, height: 32)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        UIImage(cgImage: croppedCGImage).draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }


    func extractFeatures(from image: UIImage) -> [Double] {
        guard let cgImage = image.cgImage else {
            print("Error: CGImage is nil.")
            return []
        }

        let targetWidth = 32
        let targetHeight = 32
        let pixelCount = targetWidth * targetHeight

        // Ensure the image has the correct dimensions
        if Int(image.size.width) != targetWidth || Int(image.size.height) != targetHeight {
            print("Warning: Image dimensions are incorrect. Expected \(targetWidth)x\(targetHeight), got \(Int(image.size.width))x\(Int(image.size.height)).")
            return []
        }
        
        // Create a buffer for grayscale pixel data
        var pixelData = [UInt8](repeating: 0, count: pixelCount)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixelData,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            print("Error: Could not create CGContext for feature extraction.")
            return []
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        print("Pixel data count: \(pixelData.count), Expected: \(pixelCount)")
        print("Raw pixel data: \(pixelData)")
        
        // Map pixel values to a normalized [0, 1] range
        let features = pixelData.map { Double($0) }
        if features.count != pixelCount {
            print("Warning: Feature vector length is \(features.count), expected \(pixelCount).")
        }
        
        print("Final feature vector: \(features)")
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
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)
        if let context = UIGraphicsGetCurrentContext() {
            // Fill with black
            context.setFillColor(UIColor.black.cgColor)
            context.fill(view.bounds)
        }
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let image = image {
            print("Captured Image Size:", image.size)
        } else {
            print("Error: Failed to capture the image from the view")
        }
        return image
    }

    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
        present(alert, animated: true)
    }
}
