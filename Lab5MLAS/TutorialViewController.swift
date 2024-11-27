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
            
            // prepare for the next action
            DispatchQueue.main.async {
                // Perform navigation back to the home screen
                self.navigationController?.popViewController(animated: true) // This will go back to the previous screen (HomeScreen)
            }
            
            let selectedModel = UserDefaults.standard.string(forKey: "SelectedModelType") ?? "KNN"
            client.prepareUserDataAndProcess(dsid: 1, dataPath: "/Users/zareenahmurad/Desktop/CS/CS5323/Lab5Python/datasets/userdata") { [weak self] success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        print("Tutorial data processed and uploaded. Training the model...")
                        self?.updateProgressLabel(with: "Tutorial data processed and uploaded. Training the model...")
                        
                        // Train the model
                        self?.client.trainModel(dsid: 1, modelType: selectedModel) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    print("Model trained successfully.")
                                    self?.updateProgressLabel(with: "Model trained successfully.")
                                case .failure(let error):
                                    print("Training Failed: \(error.localizedDescription)")
                                    self?.updateProgressLabel(with: "Training Failed: \(error.localizedDescription)")
                                    self?.showAlert(title: "Training Failed", message: error.localizedDescription)
                                }
                            }
                        }
                    } else {
                        // Handle failure if the tutorial data was not processed successfully
                        let errorMessage = errorMessage ?? "Unknown error"
                        self?.updateProgressLabel(with: errorMessage)
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
            // Save the drawing as a PNG file and upload it
            saveDrawingAsPNG()
            
            // Move to the next letter
            currentLetterIndex += 1
            
            // Update progress bar
            progressView.progress = Float(currentLetterIndex) / Float(arabicLetters.count)
            
            loadNextLetter()
        }
    }
    
    // MARK: - Save Drawing as PNG
    func saveDrawingAsPNG() {
        let size = CGSize(width: 32, height: 32)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let scaleTransform = CGAffineTransform(scaleX: size.width / view.bounds.width,
                                               y: size.height / view.bounds.height)
        drawnPath.apply(scaleTransform)
        drawnPath.stroke()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        drawnPath.apply(scaleTransform.inverted())
        
        if let pngData = image?.pngData() {
            let filename = "id_\(currentLetterIndex)_label_\(currentLetterIndex + 1).png"
            client.uploadPNG(data: pngData, filename: filename) { success, error in
                if success {
                    print("Successfully uploaded \(filename) to the server.")
                } else {
                    print("Error uploading \(filename): \(error ?? "Unknown error")")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
    
    func createDashedLine(from start: CGPoint, to end: CGPoint) {
        let segment = UIBezierPath()
        segment.move(to: start)
        segment.addLine(to: end)
        
        let layer = createDashedLayer(for: segment)
        dashSegments.append((path: segment, layer: layer))
        tracedDashes.append(false)
    }
    
    func createDashedCurve(from start: CGPoint, to end: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {
        let curve = UIBezierPath()
        curve.move(to: start)
        curve.addCurve(to: end, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
        
        let layer = createDashedLayer(for: curve)
        dashSegments.append((path: curve, layer: layer))
        tracedDashes.append(false)
    }
    
    func createDot(at point: CGPoint) {
        let dot = UIBezierPath()
        dot.addArc(withCenter: point, radius: 5.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        
        let layer = CAShapeLayer()
        layer.path = dot.cgPath
        layer.strokeColor = UIColor.label.cgColor
        layer.fillColor = UIColor.label.cgColor
        layer.lineWidth = 1.0
        view.layer.addSublayer(layer)
        
        dashSegments.append((path: dot, layer: layer))
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
