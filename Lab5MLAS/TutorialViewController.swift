//
//  TutorialViewController.swift
//  Lab5MLAS
//
//  Created by Hamna Tameez on 11/25/24.
//  Updated on 11/27/24.
//

import UIKit

class TutorialViewController: UIViewController {

    // MARK: - Properties
    var touchCoordinates = [(x: Double, y: Double)]()
    let arabicLetters = ["ا", "ب", "ت", "ث", "ج"] // Example letters
    var currentLetterIndex = 0
    var drawnPath = UIBezierPath() // Path for user's drawing
    var drawnLayer = CAShapeLayer() // Layer for the user's drawing
    var tutorialData: [(features: [Double], label: String)] = [] // Collected tutorial data

    var dashSegments: [(path: UIBezierPath, layer: CAShapeLayer)] = [] // Individual dash segments
    var tracedDashes: [Bool] = [] // Track which dashes are traced
    let proximityThreshold: CGFloat = 10.0 // Leeway for tracing accuracy

    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var quizButton: UIButton!
    @IBOutlet weak var progressLabel: UILabel!
    
    // Instance of MlaasModel
    let client = MlaasModel()

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure the user's drawing layer
        drawnLayer.strokeColor = UIColor.red.cgColor
        drawnLayer.lineWidth = 5.0
        drawnLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(drawnLayer)

        // Initialize the progress bar
        progressView.progress = 0.0
        
        quizButton.alpha = 0

        loadNextLetter()
    }

    func loadNextLetter() {
        resetDrawing()

        if currentLetterIndex < arabicLetters.count {
            instructionsLabel.text = "Trace the letter: \(arabicLetters[currentLetterIndex])"
            createLetterPath(for: arabicLetters[currentLetterIndex])

            // Update progress bar for current letter
            progressView.progress = Float(currentLetterIndex) / Float(arabicLetters.count)
        } else {
            // Tutorial complete, progress bar should show full progress
            progressView.progress = 1.0

            UserDefaults.standard.set(true, forKey: "HasCompletedTutorial")
            
            // Prepare user data, upload to dsid 1, and train the model
            client.prepareUserDataAndUpload(tutorialData: tutorialData, dsid: 1) { [weak self] success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        print("Tutorial data processed and uploaded. Training the model...")
                        self?.updateProgressLabel(with: "Tutorial data processed and uploaded. Training the model...")
                        
                        self?.client.trainModel(dsid: 1) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    print("Model trained successfully.")
                                    self?.updateProgressLabel(with: "Model trained successfully.")
                                    UIView.animate(withDuration: 0.5) {
                                        self?.quizButton.alpha = 1.0
                                        self?.quizButton.isHidden = false
                                    }
                                case .failure(let error):
                                    let errorMessage = error.localizedDescription
                                    print("Training Failed: \(errorMessage)")
                                    self?.updateProgressLabel(with: "Training Failed: \(errorMessage)")
                                    self?.showAlert(title: "Training Failed", message: errorMessage)
                                }
                            }
                        }
                    } else {
                        let errorMessage = errorMessage ?? "Unknown error"
                        print("Data Preparation Failed: \(errorMessage)")
                        self?.updateProgressLabel(with: "Data Preparation Failed: \(errorMessage)")
                        self?.showAlert(title: "Data Preparation Failed", message: errorMessage)
                    }
                }
            }
        }
    }

    func resetDrawing() {
        drawnPath = UIBezierPath()
        touchCoordinates.removeAll()
        drawnLayer.path = nil
        dashSegments.forEach { $0.layer.removeFromSuperlayer() } // Remove existing dash layers
        dashSegments.removeAll()
        tracedDashes.removeAll()
    }

    // MARK: - Data Collection
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

        for (index, segment) in dashSegments.enumerated() where !tracedDashes[index] {
            if isPointCloseToPath(point, path: segment.path) {
                tracedDashes[index] = true
                markDashAsTraced(index: index)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if tracedDashes.allSatisfy({ $0 }) {
            // Collect the feature vector and save it locally
            let normalizedCoordinates = normalizeCoordinates(touchCoordinates)
            let featureVector = flattenCoordinates(normalizedCoordinates)
            tutorialData.append((features: featureVector, label: arabicLetters[currentLetterIndex]))
            
            // Move to the next letter
            currentLetterIndex += 1
            
            // Update progress bar
            progressView.progress = Float(currentLetterIndex) / Float(arabicLetters.count)
            
            loadNextLetter()
        }
    }

    // MARK: - Normalization Helpers
    func normalizeCoordinates(_ coordinates: [(x: Double, y: Double)]) -> [(x: Double, y: Double)] {
        let screenWidth = Double(UIScreen.main.bounds.width)
        let screenHeight = Double(UIScreen.main.bounds.height)
        return coordinates.map { (x: $0.x / screenWidth * 32.0, y: $0.y / screenHeight * 32.0) }
    }

    func flattenCoordinates(_ coordinates: [(x: Double, y: Double)]) -> [Double] {
        return coordinates.flatMap { [$0.x, $0.y] }
    }

    // MARK: - UI Helpers
    func createLetterPath(for letter: String) {
        switch letter {
        case "ا":
            createDashedLine(from: CGPoint(x: 150, y: 200), to: CGPoint(x: 150, y: 400))
        case "ب":
            createDashedCurve(from: CGPoint(x: 70, y: 360), to: CGPoint(x: 350, y: 360),
                              controlPoint1: CGPoint(x: 33, y: 456), controlPoint2: CGPoint(x: 379, y: 456))
            createDot(at: CGPoint(x: 200, y: 480))
        case "ت":
            createDashedCurve(from: CGPoint(x: 70, y: 360), to: CGPoint(x: 350, y: 360),
                              controlPoint1: CGPoint(x: 33, y: 456), controlPoint2: CGPoint(x: 379, y: 456))
            createDot(at: CGPoint(x: 180, y: 300))
            createDot(at: CGPoint(x: 220, y: 300))
        case "ث":
            createDashedCurve(from: CGPoint(x: 70, y: 360), to: CGPoint(x: 350, y: 360),
                              controlPoint1: CGPoint(x: 33, y: 456), controlPoint2: CGPoint(x: 379, y: 456))
            createDot(at: CGPoint(x: 190, y: 340))
            createDot(at: CGPoint(x: 230, y: 340))
            createDot(at: CGPoint(x: 210, y: 320))
        case "ج":
            createDashedCurve(from: CGPoint(x: 139, y: 278), to: CGPoint(x: 254, y: 271),
                              controlPoint1: CGPoint(x: 193, y: 219), controlPoint2: CGPoint(x: 192, y: 328))
            createDashedCurve(from: CGPoint(x: 254, y: 271), to: CGPoint(x: 297, y: 421),
                              controlPoint1: CGPoint(x: 117, y: 305), controlPoint2: CGPoint(x: 117, y: 487))
            createDot(at: CGPoint(x: 190, y: 340))
        default:
            break
        }
    }
    
    func createDashedCurve(from start: CGPoint, to end: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint, segments: Int = 20) {
        let fullCurve = UIBezierPath()
        fullCurve.move(to: start)
        fullCurve.addCurve(to: end, controlPoint1: controlPoint1, controlPoint2: controlPoint2)

        // Divide the curve into smaller segments
        for i in 0..<segments {
            let t1 = CGFloat(i) / CGFloat(segments)
            let t2 = CGFloat(i + 1) / CGFloat(segments)
            
            // Compute the points for the segment using cubic Bézier interpolation
            let segmentStart = pointOnCubicCurve(t: t1, start: start, controlPoint1: controlPoint1, controlPoint2: controlPoint2, end: end)
            let segmentEnd = pointOnCubicCurve(t: t2, start: start, controlPoint1: controlPoint1, controlPoint2: controlPoint2, end: end)
            
            // Create a path for this segment
            createDashedLine(from: segmentStart, to: segmentEnd)
        }
    }

    func pointOnCubicCurve(t: CGFloat, start: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint, end: CGPoint) -> CGPoint {
        let x = cubicInterpolation(t: t, p0: start.x, p1: controlPoint1.x, p2: controlPoint2.x, p3: end.x)
        let y = cubicInterpolation(t: t, p0: start.y, p1: controlPoint1.y, p2: controlPoint2.y, p3: end.y)
        return CGPoint(x: x, y: y)
    }

    func cubicInterpolation(t: CGFloat, p0: CGFloat, p1: CGFloat, p2: CGFloat, p3: CGFloat) -> CGFloat {
        let oneMinusT = 1 - t
        return pow(oneMinusT, 3) * p0 +
               3 * pow(oneMinusT, 2) * t * p1 +
               3 * oneMinusT * pow(t, 2) * p2 +
               pow(t, 3) * p3
    }

    func createDot(at point: CGPoint) {
        let dot = UIBezierPath()
        dot.addArc(withCenter: point, radius: 5.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        
        let layer = CAShapeLayer()
        layer.path = dot.cgPath
        layer.strokeColor = UIColor.label.cgColor
        layer.fillColor = UIColor.label.cgColor // Solid fill
        layer.lineWidth = 1.0
        view.layer.addSublayer(layer)

        dashSegments.append((path: dot, layer: layer))
        tracedDashes.append(false)
    }
    
    func createDashedLine(from start: CGPoint, to end: CGPoint) {
        let segment = UIBezierPath()
        segment.move(to: start)
        segment.addLine(to: end)
        
        let layer = createDashedLayer(for: segment)
        dashSegments.append((path: segment, layer: layer))
        tracedDashes.append(false)
    }

    func createDashedLayer(for path: UIBezierPath) -> CAShapeLayer {
        let dashedLayer = CAShapeLayer()
        dashedLayer.path = path.cgPath
        dashedLayer.strokeColor = UIColor.label.cgColor
        dashedLayer.lineWidth = 5.0
        dashedLayer.lineDashPattern = [8, 4] // Dash and gap lengths
        dashedLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(dashedLayer)
        
        return dashedLayer
    }

    func markDashAsTraced(index: Int) {
        let dashLayer = dashSegments[index].layer
        dashLayer.strokeColor = UIColor.green.cgColor
        dashLayer.fillColor = UIColor.green.cgColor
    }

    func isPointCloseToPath(_ point: CGPoint, path: UIBezierPath) -> Bool {
        let pathBounds = path.cgPath.boundingBox.insetBy(dx: -proximityThreshold, dy: -proximityThreshold)
        return pathBounds.contains(point)
    }
    
    private func updateProgressLabel(with text: String) {
        UIView.transition(with: progressLabel,
                          duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: { [weak self] in
                              self?.progressLabel.text = text
                              self?.progressLabel.isHidden = false
                          },
                          completion: nil)
    }
    
}

extension UIViewController {
    func showAlert(title: String, message: String, actionTitle: String = "OK", completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: actionTitle, style: .default) { _ in
                completion?()
            })
            self.present(alert, animated: true)
        }
    }
}










