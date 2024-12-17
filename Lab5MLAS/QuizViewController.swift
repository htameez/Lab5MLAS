//
//  QuizViewController.swift
//  Lab5MLAS
//
//  Created by Hamna Tameez on 11/26/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class QuizViewController: UIViewController, AVAudioPlayerDelegate {

    // MARK: - Properties
    var touchCoordinates = [(x: Double, y: Double)]()
    var drawnPath = UIBezierPath()
    var drawnLayer = CAShapeLayer()
    var boundingBoxLayer = CAShapeLayer()
    var currentLetter = ""
    var quizResults: [(expected: String, predicted: String)] = []
    let lessonLetters: [[String]] = [
        ["ا", "ب", "ت", "ث", "ج", "ح", "خ"], // Lesson 1
        ["د", "ذ", "ر", "ز", "س", "ش", "ص"], // Lesson 2
        ["ض", "ط", "ظ", "ع", "غ", "ف", "ق"], // Lesson 3
        ["ك", "ل", "م", "ن", "ه", "و", "ي"]  // Lesson 4
    ]
    
    var customLetterList: [String]? // For custom quizzes like missed letters
    var currentIndex = 0
    var currentLesson: Int = 1 // Default to Lesson 1
    var currentLetterList: [String] {
        // If custom list is provided, use it. Otherwise, use the lesson list.
        return customLetterList ?? lessonLetters[currentLesson - 1]
    }

    let client = MlaasModel()
   
    // MARK: - IBOutlets
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    
    private let submitButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let replayButton = UIButton(type: .system)
    let buttonWidthMultiplier: CGFloat = 0.6 // 60% of the bounding box width


    
    // MARK: - Properties
    var arabicLettersMapping: [Int: String] = [
        0: "ا", 1: "ب", 2: "ت", 3: "ث", 4: "ج", 5: "ح", 6: "خ",
        7: "د", 8: "ذ", 9: "ر", 10: "ز", 11: "س", 12: "ش",
        13: "ص", 14: "ض", 15: "ط", 16: "ظ", 17: "ع", 18: "غ",
        19: "ف", 20: "ق", 21: "ك", 22: "ل", 23: "م", 24: "ن",
        25: "ه", 26: "و", 27: "ي"
    ]
    
    var audioPlayer: AVAudioPlayer? // For audio playback
    
    let letterSounds: [String: String] = [
        "ا": "Alif.wav",
        "ب": "Ba.wav",
        "ت": "Ta.wav",
        "ث": "Sa.wav",
        "ج": "Jeem.wav",
        "ح": "Hha.wav",
        "خ": "Kha.wav",
        "د": "Dal.wav",
        "ذ": "Taj Zhal.wav",
        "ر": "Raa.wav",
        "ز": "Taj Zaa.wav",
        "س": "Seen.wav",
        "ش": "Sheen.wav",
        "ص": "Saud.wav",
        "ض": "Duad.wav",
        "ط": "Taj Tua.wav",
        "ظ": "Taj Zua.wav",
        "ع": "Aain.wav",
        "غ": "Ghain.wav",
        "ف": "Faa.wav",
        "ق": "Qauf.wav",
        "ك": "Kaif.wav",
        "ل": "Laam.wav",
        "م": "Meem.wav",
        "ن": "Noon.wav",
        "ه": "Haa.wav",
        "و": "Taj wao.wav",
        "ي": "Taj Yaa.wav"
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
        // Configure Submit Button
        configureButton(
            button: submitButton,
            title: "Submit",
            backgroundColor: UIColor(red: 0.0, green: 0.1, blue: 0.4, alpha: 1.0),
            titleColor: .white,
            action: #selector(submitButtonPressed)
        )
        submitButton.isEnabled = false
        view.addSubview(submitButton)

        // Configure Clear Button
        configureButton(
            button: clearButton,
            title: "Clear",
            backgroundColor: UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0),
            titleColor: .white,
            action: #selector(clearButtonPressed)
        )
        clearButton.isEnabled = false
        view.addSubview(clearButton)

        // Configure Replay Button
        configureButton(
            button: replayButton,
            title: "Replay",
            backgroundColor: UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1.0),
            titleColor: .black, // Title color specific to Replay button
            action: #selector(replayButtonTapped)
        )
        replayButton.isEnabled = false
        view.addSubview(replayButton)

        // Add Constraints
        applyButtonConstraints()
    }

    private func configureButton(button: UIButton, title: String, backgroundColor: UIColor, titleColor: UIColor, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal) // Allow dynamic title color
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func applyButtonConstraints() {
        let boundingBoxWidth: CGFloat = 300 * buttonWidthMultiplier

        NSLayoutConstraint.activate([
            // Play Sound Button
            replayButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            replayButton.widthAnchor.constraint(equalToConstant: boundingBoxWidth),
            replayButton.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -16),
            replayButton.heightAnchor.constraint(equalToConstant: 50),

            // Clear Button
            clearButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: boundingBoxWidth),
            clearButton.bottomAnchor.constraint(equalTo: submitButton.topAnchor, constant: -16),
            clearButton.heightAnchor.constraint(equalToConstant: 50),

            // Submit Button
            submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: boundingBoxWidth),
            submitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            submitButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }


    // MARK: - Load Question
    func loadNextQuestion() {
        resetDrawing()
        if currentIndex < currentLetterList.count {
            currentLetter = currentLetterList[currentIndex]
            instructionsLabel.font = UIFont.systemFont(ofSize: 20)
            instructionsLabel.text = "Listen and write the letter!"
            progressView.progress = Float(currentIndex) / Float(currentLetterList.count)
            playSound(for: currentLetter)
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
        replayButton.isHidden = true // Hide the play button during reset
        replayButton.isEnabled = false // Disable the play button during reset
    }
    
    // MARK: - Play Sound Automatically
    func playSound(for letter: String) {
        guard let soundFile = letterSounds[letter],
              let soundURL = Bundle.main.url(forResource: soundFile, withExtension: nil) else {
            print("Sound file not found for letter: \(letter)")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Enable and show the play button after the audio finishes
        replayButton.isHidden = false
        replayButton.isEnabled = true
    }

    // MARK: - Replay Sound
    @IBAction func replayButtonTapped(_ sender: Any) {
        playSound(for: currentLetter)
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
            // Update the user's drawn path (normal tracing)
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

        let features = extractFeatures(from: croppedImage)

        // Predict using the model
        client.predict(dsid: 1, feature: features) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let predictedLabel):
                    if let predictedInt = Int(predictedLabel),
                       let mappedLetter = self.arabicLettersMapping[predictedInt] {

                        // Append to quiz results
                        self.quizResults.append((expected: self.currentLetter, predicted: mappedLetter))

                        // Check if the current index is the last letter for the lesson
                        if self.currentIndex == self.currentLetterList.count - 1 {
                            // Feedback for the last question
                            let feedbackMessage = (mappedLetter == self.currentLetter)
                                ? "You wrote \(mappedLetter) correctly!"
                                : "Expected \(self.currentLetter), but got \(mappedLetter)."

                            self.showAlert(title: (mappedLetter == self.currentLetter) ? "Correct!" : "Incorrect!",
                                           message: feedbackMessage) {
                                // Delay before showing results
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // 1-second delay
                                    self.showResults()
                                }
                            }
                        } else {
                            // Provide feedback and load the next letter
                            let feedbackMessage = (mappedLetter == self.currentLetter)
                                ? "You wrote \(mappedLetter) correctly!"
                                : "Expected \(self.currentLetter), but got \(mappedLetter)."

                            self.showAlert(title: (mappedLetter == self.currentLetter) ? "Correct!" : "Incorrect!",
                                           message: feedbackMessage) {
                                self.resetDrawing()
                                self.currentIndex += 1
                                self.loadNextQuestion()
                            }
                        }
                    } else {
                        print("Prediction \(predictedLabel) is invalid.")
                        self.showAlert(title: "Error", message: "Invalid prediction.")
                    }
                case .failure(let error):
                    print("Prediction failed: \(error.localizedDescription)")
                    self.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    func cropImageToBoundingBox(_ image: UIImage, boundingBox: CGRect) -> UIImage? {
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
        
        // Map pixel values to a normalized [0, 1] range
        let features = pixelData.map { Double($0) }
        if features.count != pixelCount {
            print("Warning: Feature vector length is \(features.count), expected \(pixelCount).")
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
        
        // Save missed letters
        let missedLetters = quizResults.filter { $0.expected != $0.predicted }.map { $0.expected }
        saveMissedLetters(missedLetters)
        
        showPostQuizOptions(message: message)
    }


    private func saveMissedLetters(_ letters: [String]) {
        var existingLetters = UserDefaults.standard.array(forKey: "missedLetters") as? [String] ?? []
        existingLetters.append(contentsOf: letters)
        let uniqueLetters = Array(Set(existingLetters)) // Ensure no duplicates
        UserDefaults.standard.setValue(uniqueLetters, forKey: "missedLetters")
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

