//
//  MissedLettersTutorialViewController.swift
//  Lab5MLAS
//
//  Created by Zareenah Murad on 12/16/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class MissedLettersTutorialViewController: UIViewController {

    // MARK: - Properties
    var missedLetters: [String] = []  // Letters to practice
    private var currentIndex = 0      // Tracks current letter index
    
    // UI Components
    private let instructionsLabel = UILabel()
    private let progressLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let clearButton = UIButton(type: .system)
    private let playSoundButton = UIButton(type: .system)
    private let submitButton = UIButton(type: .system)
    private var audioPlayer: AVAudioPlayer?
    let buttonWidthMultiplier: CGFloat = 0.6 // 60% of the bounding box width

    private var drawnPath = UIBezierPath()
    private var drawnLayer = CAShapeLayer()
    private var boundingBoxLayer = CAShapeLayer()
    private var dashSegments: [(path: UIBezierPath, layer: CAShapeLayer)] = []

    let letterSounds: [String: String] = [
        "ا": "Alif.wav", "ب": "Ba.wav", "ت": "Ta.wav", "ث": "Sa.wav",
        "ج": "Jeem.wav", "ح": "Hha.wav", "خ": "Kha.wav", "د": "Dal.wav",
        "ذ": "Taj Zhal.wav", "ر": "Raa.wav", "ز": "Taj Zaa.wav", "س": "Seen.wav",
        "ش": "Sheen.wav", "ص": "Saud.wav", "ض": "Duad.wav", "ط": "Taj Tua.wav",
        "ظ": "Taj Zua.wav", "ع": "Aain.wav", "غ": "Ghain.wav", "ف": "Faa.wav",
        "ق": "Qauf.wav", "ك": "Kaif.wav", "ل": "Laam.wav", "م": "Meem.wav",
        "ن": "Noon.wav", "ه": "Haa.wav", "و": "Taj wao.wav", "ي": "Taj Yaa.wav"
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        missedLetters = Array(Set(missedLetters)) // Ensure no duplicates
        setupUI()
        setupDrawingLayer()
        setupBoundingBox()
        loadNextLetter()
    }

    // MARK: - UI Setup
    private func setupUI() {
        configureLabel(instructionsLabel, text: "Trace the letter carefully", fontSize: 22)
        configureLabel(progressLabel, text: "Progress: 0 / \(missedLetters.count)", fontSize: 16)
        
        configureProgressView()
        setupButtons()
        
        applyConstraints()
        applyButtonConstraints()
    }
    
    private func setupButtons() {
        configureButton(
            button: playSoundButton,
            title: "Play Sound",
            backgroundColor: UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1.0),
            titleColor: .black,
            action: #selector(playSoundTapped)
        )

        configureButton(
            button: clearButton,
            title: "Clear",
            backgroundColor: UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0),
            titleColor: .white,
            action: #selector(clearButtonTapped)
        )

        configureButton(
            button: submitButton,
            title: "Done",
            backgroundColor: UIColor(red: 0.0, green: 0.1, blue: 0.4, alpha: 1.0),
            titleColor: .white,
            action: #selector(submitButtonTapped)
        )

        view.addSubview(playSoundButton)
        view.addSubview(clearButton)
        view.addSubview(submitButton)
    }

    
    private func applyConstraints() {
        let views = [instructionsLabel, progressView, progressLabel, playSoundButton, clearButton, submitButton]
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            instructionsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            instructionsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            progressView.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 16),
            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),

            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func applyButtonConstraints() {
        let boundingBoxWidth: CGFloat = 300 * buttonWidthMultiplier

        NSLayoutConstraint.activate([
            // Play Sound Button
            playSoundButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playSoundButton.widthAnchor.constraint(equalToConstant: boundingBoxWidth),
            playSoundButton.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -16),
            playSoundButton.heightAnchor.constraint(equalToConstant: 50),

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


    private func configureLabel(_ label: UILabel, text: String, fontSize: CGFloat) {
        label.text = text
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: fontSize)
        label.textAlignment = .center
        view.addSubview(label)
    }

    private func configureProgressView() {
        progressView.progress = 0.0
        progressView.tintColor = .systemBlue
        view.addSubview(progressView)
    }
    
    private func configureButton(button: UIButton, title: String, backgroundColor: UIColor, titleColor: UIColor, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
    }


    private func setupDrawingLayer() {
        drawnLayer.strokeColor = UIColor.white.cgColor
        drawnLayer.lineWidth = 19.0
        drawnLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(drawnLayer)
    }
    
    private func setupBoundingBox() {
        let size: CGFloat = 300
        let boundingBox = CGRect(x: view.bounds.midX - size / 2, y: view.bounds.midY - size / 2, width: size, height: size)
        boundingBoxLayer.path = UIBezierPath(rect: boundingBox).cgPath
        boundingBoxLayer.strokeColor = UIColor.blue.cgColor
        boundingBoxLayer.lineWidth = 2.0
        boundingBoxLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(boundingBoxLayer)
    }
    
    // MARK: - Load Next Letter
    private func loadNextLetter() {
        guard currentIndex < missedLetters.count else {
            showCompletionAlert()
            return
        }
        
        resetDrawing()
        progressLabel.text = "Progress: \(currentIndex + 1) / \(missedLetters.count)"
        progressView.progress = Float(currentIndex) / Float(missedLetters.count)
        
        let letter = missedLetters[currentIndex]
        instructionsLabel.text = "Trace the letter \(letter)"
        createLetterPath(for: letter)
    }


    func resetDrawing() {
        // Clear the drawn path
        drawnPath = UIBezierPath()
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

    // MARK: - Drawing Path
    func createLetterPath(for letter: String) {
        // Clear previous dashed lines
        for segment in dashSegments {
            segment.layer.removeFromSuperlayer()
        }
        dashSegments.removeAll()

        switch letter {
        // Lesson 1 Letters
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
        case "ح":
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
        case "خ":
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
            createDot(at: CGPoint(x: 200, y: 300))
        case "س":
            createDashedCurve(from: CGPoint(x: 125.8, y: 415.9),
                to: CGPoint(x: 190.6, y: 415.9),
                controlPoint1: CGPoint(x: 44.8, y: 545.5),
                controlPoint2: CGPoint(x: 271.6, y: 545.5))
                    
            createDashedCurve(from: CGPoint(x: 198.9, y: 427.95),
                to: CGPoint(x: 254.1, y: 417.95),
                controlPoint1: CGPoint(x: 198.4, y: 482.75),
                controlPoint2: CGPoint(x: 270.8, y: 482.75))
                    
             createDashedCurve(from: CGPoint(x: 254.1, y: 417.95),
                to: CGPoint(x: 295.3, y: 417.95),
                controlPoint1: CGPoint(x: 237.4, y: 482.75),
                controlPoint2: CGPoint(x: 335.8, y: 482.75))

        case "ش":
            createDashedCurve(from: CGPoint(x: 125.8, y: 415.9),
                to: CGPoint(x: 190.6, y: 415.9),
                controlPoint1: CGPoint(x: 44.8, y: 545.5),
                controlPoint2: CGPoint(x: 271.6, y: 545.5))
                    
            createDashedCurve(from: CGPoint(x: 198.9, y: 427.95),
                to: CGPoint(x: 254.1, y: 417.95),
                controlPoint1: CGPoint(x: 198.4, y: 482.75),
                controlPoint2: CGPoint(x: 270.8, y: 482.75))
                    
            createDashedCurve(from: CGPoint(x: 254.1, y: 417.95),
                to: CGPoint(x: 295.3, y: 417.95),
                controlPoint1: CGPoint(x: 237.4, y: 482.75),
                controlPoint2: CGPoint(x: 335.8, y: 482.75))

                    
            createDot(at: CGPoint(x: 275, y: 400))
            createDot(at: CGPoint(x: 220, y: 400))
            createDot(at: CGPoint(x: 247.5, y: 370))
                
        case "ز":
            createDashedCurve(from: CGPoint(x: 150, y: 500),
                to: CGPoint(x: 240, y: 390),
                controlPoint1: CGPoint(x: 150, y: 510),
                controlPoint2: CGPoint(x: 300, y: 535))
            
            createDot(at: CGPoint(x: 235, y: 360))
            
        case "ر":
            createDashedCurve(from: CGPoint(x: 150, y: 500),
                to: CGPoint(x: 240, y: 390),
                controlPoint1: CGPoint(x: 150, y: 510),
                controlPoint2: CGPoint(x: 300, y: 535))
            
        case "ذ":
            createDashedCurve(from: CGPoint(x: 130, y: 490),
                to: CGPoint(x: 240, y: 390),
                controlPoint1: CGPoint(x: 120, y: 550),
                controlPoint2: CGPoint(x: 360, y: 535))
            
            createDot(at: CGPoint(x: 240, y: 360))
            
        case "د":
            createDashedCurve(from: CGPoint(x: 130, y: 490),
                to: CGPoint(x: 240, y: 390),
                controlPoint1: CGPoint(x: 120, y: 550),
                controlPoint2: CGPoint(x: 360, y: 535))
            
        case "ف":
            createDashedCurve(from: CGPoint(x: 240, y: 400),
                              to: CGPoint(x: 300, y: 460),
                              controlPoint1: CGPoint(x: 170, y: 400),
                              controlPoint2: CGPoint(x: 170, y: 550))
                            
            createDashedCurve(from: CGPoint(x: 150, y: 540),
                              to: CGPoint(x: 240, y: 400),
                              controlPoint1: CGPoint(x: 360, y: 600),
                              controlPoint2: CGPoint(x: 310, y: 395))
                            
            createDashedCurve(from: CGPoint(x: 150, y: 540),
                              to: CGPoint(x: 140, y: 460),
                              controlPoint1: CGPoint(x: 110, y: 520),
                              controlPoint2: CGPoint(x: 140, y: 460))

            createDot(at: CGPoint(x: 240, y: 370))
                    
        case "ق":
            createDashedCurve(from: CGPoint(x: 240, y: 380),
                              to: CGPoint(x: 300, y: 440),
                              controlPoint1: CGPoint(x: 170, y: 380),
                              controlPoint2: CGPoint(x: 170, y: 530))
                            
            createDashedCurve(from: CGPoint(x: 145, y: 520),
                              to: CGPoint(x: 240, y: 380),
                              controlPoint1: CGPoint(x: 370, y: 580),
                              controlPoint2: CGPoint(x: 310, y: 375))
                            
            createDashedCurve(from: CGPoint(x: 145, y: 520),
                              to: CGPoint(x: 140, y: 440),
                              controlPoint1: CGPoint(x: 105, y: 500),
                              controlPoint2: CGPoint(x: 140, y: 440))

            createDot(at: CGPoint(x: 220, y: 350))
            createDot(at: CGPoint(x: 260, y: 350))

            
        case "ك":
            createDashedCurve(from: CGPoint(x: 150, y: 450),
                to: CGPoint(x: 250, y: 480),
                controlPoint1: CGPoint(x: 90, y: 530),
                controlPoint2: CGPoint(x: 260, y: 540))
                    
            createDashedLine(from: CGPoint(x: 250, y: 370),
                to: CGPoint(x: 250, y: 480))
                    
            createDashedCurve(from: CGPoint(x: 215.1, y: 438.75),
                to: CGPoint(x: 202.5, y: 454.5),
                controlPoint1: CGPoint(x: 191.25, y: 432.75),
                controlPoint2: CGPoint(x: 175.5, y: 452))

            createDashedCurve(from: CGPoint(x: 185.5, y: 470.25),
                to: CGPoint(x: 198.1, y: 454.5),
                controlPoint1: CGPoint(x: 209.35, y: 479.25),
                controlPoint2: CGPoint(x: 225.1, y: 459))
            
        case "ل":
            createDashedCurve(from: CGPoint(x: 170, y: 450),
                to: CGPoint(x: 250, y: 460),
                controlPoint1: CGPoint(x: 120, y: 550),
                controlPoint2: CGPoint(x: 265, y: 560))
                        
            createDashedLine(from: CGPoint(x: 250, y: 340),
                to: CGPoint(x: 250, y: 460))

        case "م":
            createDashedCurve(from: CGPoint(x: 240, y: 430),
                to: CGPoint(x: 190, y: 380),
                controlPoint1: CGPoint(x: 320, y: 430),
                controlPoint2: CGPoint(x: 230, y: 290))
                            
            createDashedLine(from: CGPoint(x: 180, y: 430),
                to: CGPoint(x: 240, y: 430))
            
            createDashedLine(from: CGPoint(x: 180, y: 430),
                to: CGPoint(x: 180, y: 550))

        case "ن":
            createDashedCurve(from: CGPoint(x: 160, y: 390),
                to: CGPoint(x: 240, y: 390),
                controlPoint1: CGPoint(x: 60, y: 550),
                controlPoint2: CGPoint(x: 340, y: 550))
            
            createDot(at: CGPoint(x: 200, y: 360))
    
        case "ه":
            createDashedCurve(from: CGPoint(x: 197, y: 370),
                to: CGPoint(x: 200, y: 370),
                controlPoint1: CGPoint(x: 60, y: 530),
                controlPoint2: CGPoint(x: 340, y: 530))
        
        case "و":
            createDashedCurve(from: CGPoint(x: 230, y: 350),
                to: CGPoint(x: 280, y: 420),
                controlPoint1: CGPoint(x: 160, y: 350),
                controlPoint2: CGPoint(x: 160, y: 500))
                        
            createDashedCurve(from: CGPoint(x: 130, y: 510),
                to: CGPoint(x: 230, y: 350),
                controlPoint1: CGPoint(x: 320, y: 530),
                controlPoint2: CGPoint(x: 300, y: 345))

        
        case "ي":
            // Create the main curve for "ي"
            createDashedCurve(from: CGPoint(x: 290, y: 350),
                to: CGPoint(x: 250, y: 420),
                controlPoint1: CGPoint(x: 210, y: 310),
                controlPoint2: CGPoint(x: 130, y: 400))
                    
            createDashedCurve(from: CGPoint(x: 130, y: 420),
                to: CGPoint(x: 250, y: 420),
                controlPoint1: CGPoint(x: 60, y: 560),
                controlPoint2: CGPoint(x: 400, y: 475))
            // Add two dots below the curve
            createDot(at: CGPoint(x: 190, y: 520))
            createDot(at: CGPoint(x: 230, y: 520))
        
        case "ص":
            // Center of the screen
            let centerX = view.bounds.midX
            let centerY = view.bounds.midY

            // Offset to center the points relative to the screen
            let offsetX = -337.0 + centerX
            let offsetY = -201.0 + centerY

            // First curve
            createDashedCurve(
                from: CGPoint(x: 344 + offsetX, y: 195 + offsetY),
                to: CGPoint(x: 344 + offsetX, y: 195 + offsetY),
                controlPoint1: CGPoint(x: 409 + offsetX, y: 110 + offsetY),
                controlPoint2: CGPoint(x: 491 + offsetX, y: 219 + offsetY)
            )

            createDashedCurve(
                from: CGPoint(x: 343 + offsetX, y: 177 + offsetY),
                to: CGPoint(x: 248 + offsetX, y: 194 + offsetY),
                controlPoint1: CGPoint(x: 358 + offsetX, y: 272 + offsetY),
                controlPoint2: CGPoint(x: 213 + offsetX, y: 259 + offsetY)
            )
                    
        case "ض":
            // Center of the screen
            let centerX = view.bounds.midX
            let centerY = view.bounds.midY
            // Offset to center the points relative to the screen
            let offsetX = -337.0 + centerX
            let offsetY = -201.0 + centerY

            createDashedCurve(
                from: CGPoint(x: 344 + offsetX, y: 195 + offsetY),
                to: CGPoint(x: 344 + offsetX, y: 195 + offsetY),
                controlPoint1: CGPoint(x: 409 + offsetX, y: 110 + offsetY),
                controlPoint2: CGPoint(x: 491 + offsetX, y: 219 + offsetY)
            )

            createDashedCurve(
                from: CGPoint(x: 343 + offsetX, y: 177 + offsetY),
                to: CGPoint(x: 248 + offsetX, y: 194 + offsetY),
                controlPoint1: CGPoint(x: 358 + offsetX, y: 272 + offsetY),
                controlPoint2: CGPoint(x: 213 + offsetX, y: 259 + offsetY)
            )
            createDot(at: CGPoint(x: 385 + offsetX, y: 135 + offsetY))
                    
        case "غ":
            // Bounding box dimensions and center
            let boundingBox = boundingBoxLayer.path?.boundingBox ?? CGRect.zero
            let centerX = boundingBox.midX
            let centerY = boundingBox.midY

            let offsetX = centerX - 337.0
            let offsetY = centerY - 267.0

            // Adjusted curves for "غ"
            createDashedCurve(
                from: CGPoint(x: 357 + offsetX, y: 197 + offsetY),
                to: CGPoint(x: 357 + offsetX, y: 234 + offsetY),
                controlPoint1: CGPoint(x: 303 + offsetX, y: 121 + offsetY),
                controlPoint2: CGPoint(x: 268 + offsetX, y: 254 + offsetY)
            )
                    
            createDashedCurve(
                from: CGPoint(x: 357 + offsetX, y: 234 + offsetY),
                to: CGPoint(x: 396 + offsetX, y: 360 + offsetY),
                controlPoint1: CGPoint(x: 259 + offsetX, y: 243 + offsetY),
                controlPoint2: CGPoint(x: 256 + offsetX, y: 401 + offsetY)
            )

            // Dot for "غ" moved up slightly
            createDot(at: CGPoint(x: 326 + offsetX, y: 145 + offsetY))

        case "ع":
            // Bounding box dimensions and center
            let boundingBox = boundingBoxLayer.path?.boundingBox ?? CGRect.zero
            let centerX = boundingBox.midX
            let centerY = boundingBox.midY

            let offsetX = centerX - 337.0
            let offsetY = centerY - 267.0

            // Adjusted curves for "ع"
            createDashedCurve(
                from: CGPoint(x: 357 + offsetX, y: 197 + offsetY),
                to: CGPoint(x: 357 + offsetX, y: 234 + offsetY),
                controlPoint1: CGPoint(x: 303 + offsetX, y: 121 + offsetY),
                controlPoint2: CGPoint(x: 268 + offsetX, y: 254 + offsetY)
            )
                    
            createDashedCurve(
                from: CGPoint(x: 357 + offsetX, y: 234 + offsetY),
                to: CGPoint(x: 396 + offsetX, y: 360 + offsetY),
                controlPoint1: CGPoint(x: 259 + offsetX, y: 243 + offsetY),
                controlPoint2: CGPoint(x: 256 + offsetX, y: 401 + offsetY)
            )

        case "ظ":
            // Bounding box dimensions and center
            let boundingBox = boundingBoxLayer.path?.boundingBox ?? CGRect.zero
            let centerX = boundingBox.midX
            let centerY = boundingBox.midY

            // Scaling factor to make the letter slightly bigger
            let scale: CGFloat = 1.5 // Scale up by 10%

            // Original center of the points
            let originalCenterX: CGFloat = 284.0
            let originalCenterY: CGFloat = 210.0

            // Offsets to center the letter and adjust position
            let offsetX = centerX - originalCenterX - 30.0 // Shift 10 points to the left
            let offsetY = centerY - originalCenterY + 40.0 // Move 10 points lower

            // Helper function to scale points relative to original center
            func scalePoint(x: CGFloat, y: CGFloat) -> CGPoint {
                let scaledX = ((x - originalCenterX) * scale) + originalCenterX + offsetX
                let scaledY = ((y - originalCenterY) * scale) + originalCenterY + offsetY
                return CGPoint(x: scaledX, y: scaledY)
            }

            // Adjusted curves and lines for "ظ" with scaling and shifting
            createDashedCurve(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 284, y: 210),
                controlPoint1: scalePoint(x: 332, y: 133),
                controlPoint2: scalePoint(x: 437, y: 239)
            )
                    
            createDashedLine(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 267, y: 210)
            )
                    
            createDashedLine(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 284, y: 110)
            )
                    
            // Adjusted dot position with scaling and shifting
            createDot(at: scalePoint(x: 328, y: 156))

        case "ط":
            // Bounding box dimensions and center
            let boundingBox = boundingBoxLayer.path?.boundingBox ?? CGRect.zero
            let centerX = boundingBox.midX
            let centerY = boundingBox.midY

            // Scaling factor to make the letter slightly bigger
            let scale: CGFloat = 1.5 // Scale up by 10%

            // Original center of the points
            let originalCenterX: CGFloat = 284.0
            let originalCenterY: CGFloat = 210.0

            // Offsets to center the letter and adjust position
            let offsetX = centerX - originalCenterX - 30.0 // Shift 10 points to the left
            let offsetY = centerY - originalCenterY + 40.0 // Move 10 points lower

            // Helper function to scale points relative to original center
            func scalePoint(x: CGFloat, y: CGFloat) -> CGPoint {
                let scaledX = ((x - originalCenterX) * scale) + originalCenterX + offsetX
                let scaledY = ((y - originalCenterY) * scale) + originalCenterY + offsetY
                return CGPoint(x: scaledX, y: scaledY)
            }

            // Adjusted curves and lines for "ظ" with scaling and shifting
            createDashedCurve(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 284, y: 210),
                controlPoint1: scalePoint(x: 332, y: 133),
                controlPoint2: scalePoint(x: 437, y: 239)
            )
                    
            createDashedLine(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 267, y: 210)
            )
                    
            createDashedLine(
                from: scalePoint(x: 284, y: 210),
                to: scalePoint(x: 284, y: 110)
            )
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


    // MARK: - Button Actions
    @objc private func playSoundTapped() {
        guard let soundFile = letterSounds[missedLetters[safe: currentIndex] ?? ""],
              let url = Bundle.main.url(forResource: soundFile, withExtension: nil) else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }

    @objc private func clearButtonTapped(_ sender: UIButton) {
        // Reset the user's drawing path
        drawnPath = UIBezierPath()
        drawnLayer.path = nil

        // Reset dashed lines to original state (color)
        for segment in dashSegments {
            segment.layer.strokeColor = UIColor.label.cgColor
        }

        // Disable buttons after clearing
        submitButton.isEnabled = false
        clearButton.isEnabled = false
    }



    @objc private func submitButtonTapped() {
        currentIndex += 1
        loadNextLetter()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)
        drawnPath.move(to: point)
        drawnLayer.path = drawnPath.cgPath

        // Enable buttons immediately on first touch
        submitButton.isEnabled = true
        clearButton.isEnabled = true
    }


    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self.view)

        // Ensure the point is within the bounding box
        if let boundingBoxPath = boundingBoxLayer.path, boundingBoxPath.contains(point) {
            // Update the drawn path
            drawnPath.addLine(to: point)
            drawnLayer.path = drawnPath.cgPath

            // Check all segments for touch and change color to green
            for segment in dashSegments {
                let segmentPath = segment.path.cgPath
                if segmentPath.contains(point) {
                    segment.layer.strokeColor = UIColor.green.cgColor
                }
            }

            // Enable buttons only if drawing has started
            if !drawnPath.isEmpty {
                submitButton.isEnabled = true
                clearButton.isEnabled = true
            }
        }
    }


    private func showCompletionAlert() {
        progressView.progress = Float(currentIndex + 1) / Float(missedLetters.count)
        let alert = UIAlertController(title: "Practice Complete", message: "You've practiced all missed letters!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Go Home", style: .default, handler: { _ in
            self.navigationController?.popToRootViewController(animated: true)
        }))
        present(alert, animated: true)
    }
}
