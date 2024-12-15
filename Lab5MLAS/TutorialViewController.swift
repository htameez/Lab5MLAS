//
//  TutorialViewController.swift
//  Lab5MLAS
//
//  Created by Hamna Tameez on 11/25/24.
//  Updated on 11/27/24.
//

import UIKit
import AVFoundation

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

class TutorialViewController: UIViewController {

    // MARK: - Properties
    var touchCoordinates = [(x: Double, y: Double)]()
    let arabicLetters = ["ا", "ب", "ت", "ث", "ج"] // Example letters
    var currentLetterIndex = 0
    var drawnPath = UIBezierPath() // Path for user's drawing
    var drawnLayer = CAShapeLayer() // Layer for the user's drawing
    var tutorialData: [(features: [Double], label: String)] = [] // Collected tutorial data
    var isAnimatingText = false
    var audioPlayer: AVAudioPlayer? // Audio player for letter sounds
    let letterSounds = ["ا": "Alif.wav", "ب": "Ba.wav", "ت": "Ta.wav", "ث": "Sa.wav", "ج": "Jeem.wav"] // Map letters to .wav files

    var dashSegments: [(path: UIBezierPath, layer: CAShapeLayer)] = [] // Individual dash segments

    var boundingBoxLayer = CAShapeLayer()

    private let instructionsLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let progressLabel = UILabel()
    private let submitButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let playSoundButton = UIButton(type: .system) // Button to play the sound
    private let activityIndicator = UIActivityIndicatorView(style: .medium)


    let client = MlaasModel()

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black

        setupUI()
        setupConstraints()
        setupDrawingLayer()
        setupBoundingBox()
        
        progressView.progress = 0.0
        progressLabel.isHidden = true
        submitButton.isEnabled = false
        clearButton.isEnabled = false

        loadNextLetter()
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Activity Indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        view.bringSubviewToFront(activityIndicator)
        
        // Instructions Label
        instructionsLabel.text = "Instructions Label"
        instructionsLabel.font = UIFont.boldSystemFont(ofSize: 22)
        instructionsLabel.textColor = .white
        instructionsLabel.textAlignment = .center
        instructionsLabel.numberOfLines = 0
        view.addSubview(instructionsLabel)

        // Progress View
        progressView.tintColor = .systemBlue
        view.addSubview(progressView)

        // Progress Label
        progressLabel.text = "Progress Label"
        progressLabel.font = UIFont.systemFont(ofSize: 16)
        progressLabel.textColor = .white
        progressLabel.textAlignment = .center
        progressLabel.numberOfLines = 0
        view.addSubview(progressLabel)
        
        // Submit Button
        submitButton.setTitle("Submit", for: .normal)
        submitButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.backgroundColor = .systemBlue
        submitButton.layer.cornerRadius = 10
        submitButton.addTarget(self, action: #selector(submitButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(submitButton)

        // Clear Button
        clearButton.setTitle("Clear", for: .normal)
        clearButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.backgroundColor = .systemYellow
        clearButton.layer.cornerRadius = 10
        clearButton.addTarget(self, action: #selector(clearButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(clearButton)

        // Play Sound Button
        playSoundButton.setTitle("Play Sound", for: .normal)
        playSoundButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        playSoundButton.setTitleColor(.white, for: .normal)
        playSoundButton.backgroundColor = .systemPurple
        playSoundButton.layer.cornerRadius = 10
        playSoundButton.addTarget(self, action: #selector(playSoundButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(playSoundButton)
    }

    // MARK: - Constraints
    private func setupConstraints() {
        // Disable autoresizing masks for all UI components
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        playSoundButton.translatesAutoresizingMaskIntoConstraints = false

        // Add Description Label
        let descriptionLabel = UILabel()
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = "Trace each letter carefully, listen to its sound, and prepare to be quizzed later to unlock the next level!"
        descriptionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        descriptionLabel.textColor = .white
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        view.addSubview(descriptionLabel)

        NSLayoutConstraint.activate([
            // Progress View
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            progressView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            progressView.heightAnchor.constraint(equalToConstant: 10),

            // Instructions Label
            instructionsLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            instructionsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Description Label
            descriptionLabel.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Progress Label
            progressLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Activity Indicator
            activityIndicator.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 8), // Close to progressLabel
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            
            // Play Sound Button
            playSoundButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playSoundButton.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -20),
            playSoundButton.widthAnchor.constraint(equalToConstant: 160),
            playSoundButton.heightAnchor.constraint(equalToConstant: 60), // Increased button height

            // Clear Button
            clearButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            clearButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -16),
            clearButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            clearButton.heightAnchor.constraint(equalToConstant: 60), // Increased button height

            // Submit Button
            submitButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 16),
            submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            submitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            submitButton.heightAnchor.constraint(equalToConstant: 60), // Increased button height
        ])
        view.bringSubviewToFront(activityIndicator)
    }


    // MARK: - Play Sound
    @objc private func playSoundButtonTapped(_ sender: UIButton) {
        guard let currentLetter = arabicLetters[safe: currentLetterIndex],
              let soundFile = letterSounds[currentLetter],
              let soundURL = Bundle.main.url(forResource: soundFile, withExtension: nil) else {
            print("Sound file not found for letter: \(arabicLetters[currentLetterIndex])")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }


    func setupDrawingLayer() {
        drawnLayer.strokeColor = UIColor.white.cgColor
        drawnLayer.lineWidth = 19.0
        drawnLayer.fillColor = UIColor.clear.cgColor

        // Ensure drawnLayer is only added once and stays in place
        if !view.layer.sublayers!.contains(drawnLayer) {
            view.layer.addSublayer(drawnLayer)
        }
        
        // Bring the drawnLayer to the front
        view.layer.insertSublayer(drawnLayer, at: UInt32(view.layer.sublayers?.count ?? 0))
        
    }

    func setupBoundingBox() {
        let boxWidth: CGFloat = 300 // Adjust width
        let boxHeight: CGFloat = 300 // Adjust height
        let centerX = view.bounds.midX
        let centerY = view.bounds.midY

        // Create the bounding box
        let boundingBox = CGRect(x: centerX - boxWidth / 2, y: centerY - boxHeight / 2, width: boxWidth, height: boxHeight)
        boundingBoxLayer.path = UIBezierPath(rect: boundingBox).cgPath
        boundingBoxLayer.strokeColor = UIColor.blue.cgColor
        boundingBoxLayer.lineWidth = 2.0
        boundingBoxLayer.fillColor = UIColor.clear.cgColor

        // Add the bounding box back to the view after clearing other layers
        if view.layer.sublayers?.contains(boundingBoxLayer) == false {
            view.layer.addSublayer(boundingBoxLayer)
        }
    }

    func createLetterPath(for letter: String) {
        // Clear previous dashed lines
        for segment in dashSegments {
            segment.layer.removeFromSuperlayer()
        }
        dashSegments.removeAll()

        switch letter {
        case "ا":
            let centerX = view.bounds.midX
            let centerY = view.bounds.midY
            let verticalOffset: CGFloat = -20
            createDashedLine(
                from: CGPoint(x: centerX, y: centerY + verticalOffset - 100),
                to: CGPoint(x: centerX, y: centerY + verticalOffset + 100)
            )
        case "ب":
            createDashedCurve(from: CGPoint(x: 100, y: 360), to: CGPoint(x: 300, y: 360),
                                controlPoint1: CGPoint(x: 50, y: 456), controlPoint2: CGPoint(x: 350, y: 456))
            createDot(at: CGPoint(x: 200, y: 480))
        case "ت":
            createDashedCurve(from: CGPoint(x: 100, y: 380), to: CGPoint(x: 300, y: 380),
                                  controlPoint1: CGPoint(x: 50, y: 476), controlPoint2: CGPoint(x: 350, y: 476))
            createDot(at: CGPoint(x: 180, y: 350))
            createDot(at: CGPoint(x: 220, y: 350))
        case "ث":
            createDashedCurve(from: CGPoint(x: 100, y: 380), to: CGPoint(x: 300, y: 380),
                                  controlPoint1: CGPoint(x: 50, y: 476), controlPoint2: CGPoint(x: 350, y: 476))
            createDot(at: CGPoint(x: 180, y: 355))
            createDot(at: CGPoint(x: 220, y: 355))
            createDot(at: CGPoint(x: 200, y: 335))
        case "ج":
            createDashedCurve(
                from: CGPoint(x: 139, y: 348),
                to: CGPoint(x: 254, y: 341),
                controlPoint1: CGPoint(x: 193, y: 289),
                controlPoint2: CGPoint(x: 192, y: 378)
            )
            createDashedCurve(
                from: CGPoint(x: 254, y: 341),
                to: CGPoint(x: 254, y: 471),
                controlPoint1: CGPoint(x: 117, y: 365),
                controlPoint2: CGPoint(x: 117, y: 527)
            )
            createDot(at: CGPoint(x: 208, y: 428))
        default:
            break
        }
    }

    func createDashedLine(from start: CGPoint, to end: CGPoint) {
        let segment = UIBezierPath()
        segment.move(to: start)
        segment.addLine(to: end)

        let layer = createDashedLayer(for: segment)
        dashSegments.append((path: segment, layer: layer))
    }

    func createDashedCurve(from start: CGPoint, to end: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {
        let curve = UIBezierPath()
        curve.move(to: start)
        curve.addCurve(to: end, controlPoint1: controlPoint1, controlPoint2: controlPoint2)

        let layer = createDashedLayer(for: curve)
        dashSegments.append((path: curve, layer: layer))
    }

    func createDot(at point: CGPoint) {
        let dot = UIBezierPath()
        dot.addArc(withCenter: point, radius: 6.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)

        let layer = CAShapeLayer()
        layer.path = dot.cgPath
        layer.strokeColor = UIColor.label.cgColor
        layer.fillColor = UIColor.label.cgColor
        view.layer.addSublayer(layer)
        
        view.layer.insertSublayer(drawnLayer, at: UInt32(view.layer.sublayers?.count ?? 0))
    }

    func createDashedLayer(for path: UIBezierPath) -> CAShapeLayer {
        let dashedLayer = CAShapeLayer()
        dashedLayer.path = path.cgPath
        dashedLayer.strokeColor = UIColor.label.cgColor
        dashedLayer.lineWidth = 9.0
        dashedLayer.lineDashPattern = [8, 4]
        dashedLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(dashedLayer)
        
        view.layer.insertSublayer(drawnLayer, above: dashedLayer)

        return dashedLayer
    }

    func loadNextLetter() {
        submitButton.isEnabled = false
        if currentLetterIndex < arabicLetters.count {
            resetDrawing()
            instructionsLabel.text = "Trace the letter: \(arabicLetters[currentLetterIndex])"
            createLetterPath(for: arabicLetters[currentLetterIndex])
            progressView.progress = Float(currentLetterIndex) / Float(arabicLetters.count)
        } else {
            progressView.progress = 1.0
            fadeInLabel(progressLabel)
            typewriterEffect(progressLabel, text: "Learning your handwriting style...", characterDelay: 0.1)
            progressLabel.isHidden = false
            handleTutorialCompletion()
        }
    }

    func resetDrawing() {
        // Clear the drawn path
        drawnPath = UIBezierPath()
        touchCoordinates.removeAll()
        drawnLayer.path = nil
        
        // Remove all dashed line layers
        for segment in dashSegments {
            segment.layer.removeFromSuperlayer()
        }
        dashSegments.removeAll()

        // Remove all sublayers (this includes the dots and other shape layers)
        for layer in view.layer.sublayers ?? [] {
            if let shapeLayer = layer as? CAShapeLayer, shapeLayer != drawnLayer {
                shapeLayer.removeFromSuperlayer()  // Keep drawnLayer intact
            }
        }

        // Recreate the bounding box to ensure it stays visible
        setupBoundingBox()

        // Reset button states
        submitButton.isEnabled = false
        clearButton.isEnabled = false
    }



    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)
        drawnPath.move(to: point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)

        // Ensure the point is inside the bounding box before adding it to the path
        if let boundingBoxPath = boundingBoxLayer.path, boundingBoxPath.contains(point) {
            // Add to the drawn path
            drawnPath.addLine(to: point)
            
            // Update the drawn layer with the new path
            drawnLayer.path = drawnPath.cgPath
            
            // Append the coordinates for future use
            touchCoordinates.append((x: Double(point.x), y: Double(point.y)))

            // Enable buttons after drawing starts
            if !submitButton.isEnabled {
                submitButton.isEnabled = true
                clearButton.isEnabled = true
            }
        }
    }
    
    func viewToImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0.0)
        if let context = UIGraphicsGetCurrentContext() {
            // Fill the entire context with black color
            context.setFillColor(UIColor.black.cgColor)
            context.fill(view.bounds)
        }
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
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



    @objc private func submitButtonTapped(_ sender: UIButton) {
        guard let boundingBox = boundingBoxLayer.path?.boundingBox else {
            print("Bounding box is not available")
            return
        }
        
        hideDashedLines()
        
        // Add a short delay so dashed lines are fully hidden before capturing png
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let capturedImage = self.viewToImage() else {
                print("Failed to capture image")
                self.showDashedLines()
                return
            }
            
            guard let croppedImage = self.cropImageToBoundingBox(capturedImage, boundingBox: boundingBox) else {
                print("Failed to crop image to bounding box")
                self.showDashedLines()
                return
            }
            
            self.showDashedLines()
            
            let features = self.extractFeatures(from: croppedImage)
            print("Extracted features: \(features)")
            
            let label = self.arabicLetters[self.currentLetterIndex]
            self.tutorialData.append((features: features, label: label))
            
            let filename = "user_letter_\(self.currentLetterIndex).png"
            self.client.uploadPNG(image: croppedImage, filename: filename) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Successfully uploaded cropped image for letter \(label)")
                    } else {
                        print("Failed to upload cropped image for letter \(label): \(error ?? "Unknown error")")
                        self.showAlert(title: "Upload Failed", message: error ?? "Unknown error")
                    }
                }
            }
            
            self.currentLetterIndex += 1
            self.loadNextLetter()
        }
    }

    func cropImageToBoundingBox(_ image: UIImage, boundingBox: CGRect) -> UIImage? {
        // Adjust the bounding box to slightly crop inside the green border
        let scale = UIScreen.main.scale
        let margin: CGFloat = 2.0 // Adjust this to fine-tune how much inside the border you crop
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

    @objc private func clearButtonTapped(_ sender: UIButton) {
        drawnPath = UIBezierPath()
        touchCoordinates.removeAll()
        drawnLayer.path = nil
        submitButton.isEnabled = false
        clearButton.isEnabled = false
    }

    func showPostTutorialOptions() {
        let alert = UIAlertController(title: "Tutorial Complete", message: "What would you like to do next?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Learn Again", style: .default, handler: { _ in
            self.restartTutorial()
        }))

        alert.addAction(UIAlertAction(title: "Take Quiz", style: .default, handler: { _ in
            self.navigateToQuiz()
        }))

        alert.addAction(UIAlertAction(title: "Go Home", style: .cancel, handler: { _ in
            self.navigationController?.popToRootViewController(animated: true)
        }))

        self.present(alert, animated: true)
    }

    func navigateToQuiz() {
        if let quizViewController = storyboard?.instantiateViewController(withIdentifier: "QuizViewController") {
            navigationController?.pushViewController(quizViewController, animated: true)
        }
    }

    func restartTutorial() {
        currentLetterIndex = 0
        progressView.progress = 0.0
        progressLabel.text = ""
        loadNextLetter()
    }

    func handleTutorialCompletion() {
        // Update the UI to indicate progress
        progressView.isHidden = true
        submitButton.isEnabled = false
        clearButton.isEnabled = false
        progressLabel.isHidden = false

        fadeInLabel(progressLabel)
        typewriterEffect(progressLabel, text: "Learning your handwriting style...", characterDelay: 0.1)

        // Start the activity indicator
        activityIndicator.startAnimating()

        // Step 1: Prepare user data
        client.prepareUserDataAndUpload(tutorialData: tutorialData, dsid: 1) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Data uploaded successfully. Training model...")

                    // Step 2: Train the model after successful upload
                    self.trainModel(dsid: 1)
                } else {
                    // Handle upload failure
                    print("Failed to upload user data: \(error ?? "Unknown error")")
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Data Upload Failed", message: error ?? "Unknown error")
                }
            }
        }
    }

    private func trainModel(dsid: Int) {
        // Simulate longer processing time (if necessary for debugging)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            self.client.trainModel(dsid: dsid, completion: { result in
                DispatchQueue.main.async {
                    // Stop the activity indicator only after training is complete
                    self.activityIndicator.stopAnimating()

                    switch result {
                    case .success:
                        print("Model trained successfully.")
                        self.progressLabel.text = "Model trained successfully!"
                        self.showPostTutorialOptions()
                    case .failure(let error):
                        print("Model training failed: \(error.localizedDescription)")
                        self.showAlert(title: "Training Failed", message: error.localizedDescription)
                    }
                }
            })
        }
    }


    func hideDashedLines() {
        for segment in dashSegments {
            segment.layer.isHidden = true
        }
    }

    func showDashedLines() {
        for segment in dashSegments {
            segment.layer.isHidden = false
        }
    }
    

    func typewriterEffect(_ label: UILabel, text: String, characterDelay: TimeInterval) {
        guard !isAnimatingText else { return } // Prevent overlapping animations
        isAnimatingText = true

        label.text = ""
        var charIndex = 0.0
        for letter in text {
            DispatchQueue.main.asyncAfter(deadline: .now() + charIndex * characterDelay) {
                DispatchQueue.main.async {
                    label.text?.append(letter)
                    if charIndex == Double(text.count - 1) {
                        self.isAnimatingText = false // Reset flag when done
                    }
                }
            }
            charIndex += 1
        }
    }
    
    func fadeInLabel(_ label: UILabel, duration: TimeInterval = 1.0) {
        label.alpha = 0.0
        UIView.animate(withDuration: duration) {
            label.alpha = 1.0
        }
    }
    

    func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
        present(alert, animated: true)
    }
}




   

    

