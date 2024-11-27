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
    var server_ip = "192.168.1.92"
    private var dsid: Int = 1 // Default DSID

    lazy var session = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 60.0
        sessionConfig.timeoutIntervalForResource = 200.0
        return URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
    }()
    
    func compareModels(dsid: Int, completion: @escaping (Result<[String: Double], Error>) -> Void) {
            let urlString = "http://\(server_ip):8000/compare_models/\(dsid)"
            guard let url = URL(string: urlString) else {
                completion(.failure(NetworkError.invalidURL))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = RequestEnum.get.rawValue
            
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                      let comparisonResults = json["comparison_results"] as? [String: Double] else {
                    completion(.failure(NetworkError.serverError))
                    return
                }
                
                completion(.success(comparisonResults))
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

    // MARK: - Train Model
    func trainModel(dsid: Int, modelType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlString = "http://\(server_ip):8000/train_model_sklearn/\(dsid)?model_type=\(modelType)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = RequestEnum.get.rawValue

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Training error: \(error.localizedDescription)")  // Log the error
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Unexpected server response during training.")  // Log if the server didn't respond as expected
                completion(.failure(NetworkError.serverError))
                return
            }

            // If training is successful, set the flag to true
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: "isTrained")
                print("Training completed successfully.")
                completion(.success(()))  // Confirm completion
            }
        }.resume()
    }


    // MARK: - Predict
    func predict(dsid: Int, feature: [Double], modelType: String, completion: @escaping (Result<String, Error>) -> Void) {
        let baseURL = "http://\(server_ip):8000/predict_sklearn/"
        guard let url = URL(string: baseURL) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = RequestEnum.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "dsid": dsid,
            "feature": feature,
            "model_type": modelType
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
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

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prediction = json["prediction"] as? String {
                    completion(.success(prediction))
                } else {
                    completion(.failure(NetworkError.serverError))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    
    // MARK: - Upload Individual PNG
    func uploadPNG(data: Data, filename: String, completion: @escaping (Bool, String?) -> Void) {
        let serverURL = URL(string: "http://\(server_ip):8000/upload_png/")! // Replace with your server IP
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let task = session.uploadTask(with: request, from: body) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(false, "Server responded with an error")
                return
            }
            completion(true, nil)
        }
        task.resume()
    }
    
    func prepareUserDataAndUpload(tutorialData: [(features: [Double], label: String)],
                                   dsid: Int,
                                   modelType: String,
                                   completion: @escaping (Bool, String?) -> Void) {
        let baseURL = "http://\(server_ip):8000/prepare_user_data/"
        guard let url = URL(string: baseURL) else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build the payload
        let payload: [String: Any] = [
            "tutorial_data": tutorialData.map { ["feature": $0.features, "label": $0.label] },
            "dsid": dsid
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


    // MARK: - Inform Server to Process Uploaded PNGs
    func prepareUserDataAndProcess(dsid: Int, dataPath: String, completion: @escaping (Bool, String?) -> Void) {
        let baseURL = "http://\(server_ip):8000/prepare_user_data/"
        guard let url = URL(string: baseURL) else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Payload with dsid and data_path
        let payload: [String: Any] = ["dsid": dsid, "data_path": dataPath]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(false, "Error serializing JSON: \(error.localizedDescription)")
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true, nil)
            } else {
                completion(false, "Unexpected server response")
            }
        }
        task.resume()
    }
}
