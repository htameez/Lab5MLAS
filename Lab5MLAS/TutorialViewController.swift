//
//  TutorialViewController.swift
//  Lab5MLAS
//
//  Created by Hamna Tameez on 11/25/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit

class TutorialViewController: UIViewController {

    // MARK: Properties
    var touchCoordinates = [(x: Double, y: Double)]()
    let arabicLetters = ["ا", "ب", "ت", "ث", "ج"] // Example letters
    var currentLetterIndex = 0
    var drawnPath = UIBezierPath() // Path for user's drawing
    var drawnLayer = CAShapeLayer() // Layer for the user's drawing

    var dashSegments: [(path: UIBezierPath, layer: CAShapeLayer)] = [] // Individual dash segments
    var tracedDashes: [Bool] = [] // Track which dashes are traced

    let proximityThreshold: CGFloat = 20.0 // Leeway for tracing accuracy

    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure the user's drawing layer
        drawnLayer.strokeColor = UIColor.red.cgColor
        drawnLayer.lineWidth = 5.0
        drawnLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(drawnLayer)

        loadNextLetter()
    }

    func loadNextLetter() {
        // Reset paths and layers
        drawnPath = UIBezierPath()
        touchCoordinates.removeAll()
        drawnLayer.path = nil
        dashSegments.forEach { $0.layer.removeFromSuperlayer() } // Remove existing dash layers
        dashSegments.removeAll()
        tracedDashes.removeAll()

        if currentLetterIndex < arabicLetters.count {
            instructionsLabel.text = "Trace the letter: \(arabicLetters[currentLetterIndex])"
            createLetterPath(for: arabicLetters[currentLetterIndex])
        } else {
            // Tutorial complete
            UserDefaults.standard.set(true, forKey: "HasCompletedTutorial")
            performSegue(withIdentifier: "ToMainViewController", sender: nil)
        }
    }

    func createLetterPath(for letter: String) {
        switch letter {
        case "ا":
            createDashedLine(from: CGPoint(x: 150, y: 200), to: CGPoint(x: 150, y: 400))
        case "ب":
            // Create the curved main shape for ب by breaking it into smaller segments
            let totalSegments = 20 // Number of dashed segments for the curve
            let start = CGPoint(x: 70, y: 360)
            let end = CGPoint(x: 350, y: 360)
            let controlPoint1 = CGPoint(x: 33, y: 456)
            let controlPoint2 = CGPoint(x: 379, y: 456)

            // Divide the curve into smaller dashed segments
            createDashedCurve(from: start, to: end, controlPoint1: controlPoint1, controlPoint2: controlPoint2, segments: totalSegments)
            
            // Add a dot below the line
            createDot(at: CGPoint(x: 200, y: 480))
        case "ت":
            let totalSegments = 20 // Number of dashed segments for the curve
            let start = CGPoint(x: 70, y: 360)
            let end = CGPoint(x: 350, y: 360)
            let controlPoint1 = CGPoint(x: 33, y: 456)
            let controlPoint2 = CGPoint(x: 379, y: 456)

            // Divide the curve into smaller dashed segments
            createDashedCurve(from: start, to: end, controlPoint1: controlPoint1, controlPoint2: controlPoint2, segments: totalSegments)
            
            createDot(at: CGPoint(x: 180, y: 300))
            createDot(at: CGPoint(x: 220, y: 300))
        case "ث":
            let totalSegments = 20 // Number of dashed segments for the curve
            let start = CGPoint(x: 70, y: 360)
            let end = CGPoint(x: 350, y: 360)
            let controlPoint1 = CGPoint(x: 33, y: 456)
            let controlPoint2 = CGPoint(x: 379, y: 456)

            // Divide the curve into smaller dashed segments
            createDashedCurve(from: start, to: end, controlPoint1: controlPoint1, controlPoint2: controlPoint2, segments: totalSegments)
            
            createDot(at: CGPoint(x: 190, y: 340))
            createDot(at: CGPoint(x: 230, y: 340))
            createDot(at: CGPoint(x: 210, y: 320))
            
        case "ج":
            var totalSegments = 20 // Number of dashed segments for the curve
            var start = CGPoint(x: 139, y: 278)
            var end = CGPoint(x: 254, y: 271)
            var controlPoint1 = CGPoint(x: 193, y: 219)
            var controlPoint2 = CGPoint(x: 192, y: 328)
            
            // Divide the curve into smaller dashed segments
            createDashedCurve(from: start, to: end, controlPoint1: controlPoint1, controlPoint2: controlPoint2, segments: totalSegments)
            
            totalSegments = 20 // Number of dashed segments for the curve
            start = CGPoint(x: 254, y: 271)
            end = CGPoint(x: 297, y: 421)
            controlPoint1 = CGPoint(x: 117, y: 305)
            controlPoint2 = CGPoint(x: 117, y: 487)

//            // Divide the curve into smaller dashed segments
            createDashedCurve(from: start, to: end, controlPoint1: controlPoint1, controlPoint2: controlPoint2, segments: totalSegments)
            
            createDot(at: CGPoint(x: 190, y: 340))
            
        default:
            break
        }
    }
    
    func createCurvedPath(start: CGPoint, control: CGPoint, end: CGPoint) {
        let curve = UIBezierPath()
        curve.move(to: start)
        curve.addQuadCurve(to: end, controlPoint: control)
        
        let layer = createDashedLayer(for: curve)
        dashSegments.append((path: curve, layer: layer))
        tracedDashes.append(false)
    }

    func createDashedCurve(from start: CGPoint, to end: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint, segments: Int) {
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

    func createDashedLine(from start: CGPoint, to end: CGPoint) {
        let segment = UIBezierPath()
        segment.move(to: start)
        segment.addLine(to: end)
        
        let layer = createDashedLayer(for: segment) // Returns a CAShapeLayer
        dashSegments.append((path: segment, layer: layer)) // Correctly appends to dashSegments
        tracedDashes.append(false) // Track this segment as untraced initially
    }

    func createDashedLayer(for path: UIBezierPath) -> CAShapeLayer {
        let dashedLayer = CAShapeLayer()
        dashedLayer.path = path.cgPath
        dashedLayer.strokeColor = UIColor.black.cgColor
        dashedLayer.lineWidth = 5.0
        dashedLayer.lineDashPattern = [8, 4] // Dash and gap lengths
        dashedLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(dashedLayer)
        
        return dashedLayer // Correctly return the dashedLayer
    }

    func createDot(at point: CGPoint) {
        let dot = UIBezierPath()
        dot.addArc(withCenter: point, radius: 5.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        
        let layer = CAShapeLayer()
        layer.path = dot.cgPath
        layer.strokeColor = UIColor.black.cgColor
        layer.fillColor = UIColor.black.cgColor // Solid fill
        layer.lineWidth = 1.0
        view.layer.addSublayer(layer)

        dashSegments.append((path: dot, layer: layer))
        tracedDashes.append(false)
    }

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

        // Check if the drawn line is close enough to any segment
        for (index, segment) in dashSegments.enumerated() where !tracedDashes[index] {
            if isPointCloseToPath(point, path: segment.path) {
                tracedDashes[index] = true
                markDashAsTraced(index: index)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Check if all dashes are traced
        if tracedDashes.allSatisfy({ $0 }) {
            // Capture and upload feature vector for the current letter
            captureFeatureVector(letter: arabicLetters[currentLetterIndex])
            
            // Move to the next letter
            currentLetterIndex += 1
            progressView.progress = Float(currentLetterIndex) / Float(arabicLetters.count)
            loadNextLetter()
        }
    }

    func markDashAsTraced(index: Int) {
        let dashLayer = dashSegments[index].layer
        dashLayer.strokeColor = UIColor.green.cgColor
        dashLayer.fillColor = UIColor.green.cgColor // For dots
    }

    func isPointCloseToPath(_ point: CGPoint, path: UIBezierPath) -> Bool {
        let pathBounds = path.cgPath.boundingBox.insetBy(dx: -proximityThreshold, dy: -proximityThreshold)
        return pathBounds.contains(point)
    }
    
    func captureFeatureVector(letter: String) {
        // 1. Normalize coordinates
        let normalizedCoordinates = normalizeCoordinates(touchCoordinates)
        // 2. Flatten into feature vector
        let featureVector = flattenCoordinates(normalizedCoordinates)
        // 3. Upload feature vector
        sendFeatureVectorToServer(features: featureVector, letter: letter)
    }

    func normalizeCoordinates(_ coordinates: [(x: Double, y: Double)]) -> [(x: Double, y: Double)] {
        // Get screen dimensions
        let screenWidth = Double(UIScreen.main.bounds.width)
        let screenHeight = Double(UIScreen.main.bounds.height)
        
        return coordinates.map { (x: $0.x / screenWidth, y: $0.y / screenHeight) }
    }

    func flattenCoordinates(_ coordinates: [(x: Double, y: Double)]) -> [Double] {
        return coordinates.flatMap { [$0.x, $0.y] }
    }

    func sendFeatureVectorToServer(features: [Double], letter: String) {
        let json: [String: Any] = ["feature": features, "label": letter, "dsid": 1]
        guard let url = URL(string: "http://192.168.1.240:8000/labeled_data/") else {
            print("Invalid URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json)
            request.httpBody = jsonData
        } catch {
            print("Error encoding JSON: \(error)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending feature vector: \(error)")
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Feature vector sent successfully.")
            } else {
                print("Unexpected server response: \(String(describing: response))")
            }
        }
        task.resume()
    }
}








