//
//  MlaasModel.swift
//  HTTPSwiftExample
//
//  Created by Eric Cooper Larson on 6/5/24.
//  Updated by Hamna Tameez on 11/25/24.
//

import UIKit

protocol ClientDelegate {
    func updateDsid(_ newDsid: Int) // Update the UI when DSID changes
    func receivedPrediction(_ prediction: [String: Any]) // Handle received prediction
}

enum RequestEnum: String {
    case get = "GET"
    case post = "POST"
}

enum NetworkError: Error {
    case invalidURL
    case serverError

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid server URL. Please contact support."
        case .serverError:
            return "Server error occurred. Please try again later."
        }
    }
}

class MlaasModel: NSObject, URLSessionDelegate {
    // MARK: - Properties
    var server_ip = "192.168.1.92" // zareenah's mac server ip
    // var server_ip = "172.20.10.2" // zareenah's mac on personal hotspot
    private var dsid: Int = 1 // Default DSID

    lazy var session = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 600.0
        sessionConfig.timeoutIntervalForResource = 1200.0
        return URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Upload PNG with Preprocessing
    func uploadPNG(image: UIImage, filename: String, completion: @escaping (Bool, String?) -> Void) {
        guard let pngData = image.pngData() else {
            completion(false, "Failed to convert image to PNG data")
            return
        }

        let serverURL = URL(string: "http://\(server_ip):8000/upload_png/")!
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(pngData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let task = session.uploadTask(with: request, from: body) { data, response, error in
            if let error = error {
                print("Upload failed: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error: Server responded with a non-200 status code.")
                completion(false, "Server responded with an error.")
                return
            }
            completion(true, nil)
        }
        task.resume()
    }


    // MARK: - Train Model (XGBoost Only)
    func trainModel(dsid: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "http://\(server_ip):8000/train_model/\(dsid)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 300
        sessionConfig.timeoutIntervalForResource = 600
        session = URLSession(configuration: sessionConfig)


        let session = URLSession(configuration: sessionConfig)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Handle the request
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Training error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // Check HTTP status
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(NetworkError.serverError))
                return
            }

            print("Training completed successfully.")
            completion(.success(()))
        }
        task.resume()
    }



    func predict(dsid: Int, feature: [Double], completion: @escaping (Result<String, Error>) -> Void) {
        let baseURL = "http://\(server_ip):8000/predict/"
        guard let url = URL(string: baseURL) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = RequestEnum.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = ["feature": feature, "dsid": dsid]


        // Serialize JSON payload
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            request.httpBody = jsonData
        } catch {
            print("Error serializing JSON payload: \(error)")
            completion(.failure(error))
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NetworkError.serverError))
                return
            }

            // Validate HTTP response
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("HTTP Error: \(httpResponse.statusCode)")
                completion(.failure(NetworkError.serverError))
                return
            }

            // Parse JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prediction = json["prediction"] as? Int {
                    completion(.success(String(prediction)))
                } else {
                    print("Invalid JSON structure: \(String(data: data, encoding: .utf8) ?? "Unknown")")
                    completion(.failure(NetworkError.serverError))
                }
            } catch {
                print("Error parsing JSON: \(error)")
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    
    // MARK: - Dataset Preparation
    func prepareDataset(dsid: Int, dataPath: String, completion: @escaping (Bool, String?) -> Void) {
        let baseURL = "http://\(server_ip):8000/prepare_dataset/"
        
        guard let url = URL(string: baseURL) else {
            completion(false, NetworkError.invalidURL.localizedDescription)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = RequestEnum.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = ["dsid": dsid, "data_path": dataPath]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(false, "Error serializing JSON: \(error.localizedDescription)")
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Error preparing dataset: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true, nil)
            } else {
                completion(false, "Unexpected server response: \(String(describing: response))")
            }
        }
        task.resume()
    }


    // MARK: - Upload User Data and Process
    func prepareUserDataAndUpload(tutorialData: [(features: [Double], label: String)],
                                   dsid: Int,
                                   completion: @escaping (Bool, String?) -> Void) {
        let baseURL = "http://\(server_ip):8000/prepare_user_data/"
        guard let url = URL(string: baseURL) else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST" // Use POST method for data upload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Validate tutorial data to ensure all feature vectors are consistent
        let validData = tutorialData.filter { $0.features.count == 1024 }
        if validData.isEmpty {
            completion(false, "No valid data points to upload. All feature vectors are invalid.")
            return
        }
        if validData.count != tutorialData.count {
            print("Warning: \(tutorialData.count - validData.count) invalid data points were removed.")
        }

        // Build the payload
        let payload: [String: Any] = [
            "dsid": dsid,
            "tutorial_data": validData.map { ["feature": $0.features, "label": $0.label] }
        ]

        do {
            let requestBody = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = requestBody
        } catch {
            completion(false, "Error serializing JSON")
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error preparing user data: \(error)")
                completion(false, "Error preparing user data")
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("User data prepared and uploaded successfully.")
                completion(true, nil)
            } else {
                let errorMessage = "Unexpected server response: \(String(describing: response))"
                print(errorMessage)
                completion(false, errorMessage)
            }
        }
        task.resume()
    }


}
