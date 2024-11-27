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
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
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
    // Existing properties and initializations remain the same
    var server_ip = "192.168.1.234" // Replace with your server IP
    private var dsid: Int = 1 // Default dsid for training
    
    lazy var session = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 60.0 // Increased from 5.0
        sessionConfig.timeoutIntervalForResource = 200.0 // Increased from 8.0
        return URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
    }()
    
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

    
    func prepareUserDataAndUpload(tutorialData: [(features: [Double], label: String)],
                                  dsid: Int,
                                  completion: @escaping (Bool, String?) -> Void) {
        let baseURL = "http://\(server_ip):8000/prepare_user_data/"
        guard let url = URL(string: baseURL) else {
            print("Invalid URL")
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
            print("Error serializing JSON: \(error)")
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
    
    // MARK: - Train Model
    
    func trainModel(dsid: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "http://\(server_ip):8000/train_model_sklearn/\(dsid)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(NetworkError.serverError))
                return
            }

            DispatchQueue.main.async {
                completion(.success(()))
            }
        }.resume()
    }

    
    func initializeOldDataset(dataPath: String, dsid: Int, completion: @escaping (Bool) -> Void) {
        let baseURL = "http://\(server_ip):8000/initialize_dataset/"
        guard let url = URL(string: baseURL) else {
            print("Invalid URL")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = ["data_path": dataPath, "dsid": dsid]
        do {
            let requestBody = try JSONSerialization.data(withJSONObject: payload)
            request.httpBody = requestBody
        } catch {
            print("Error serializing JSON: \(error)")
            completion(false)
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error initializing dataset: \(error)")
                completion(false)
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Old dataset initialized successfully.")
                completion(true)
            } else {
                print("Unexpected server response: \(String(describing: response))")
                completion(false)
            }
        }
        task.resume()
    }
    
    // MARK: - Generic Dataset Upload
    
    private func uploadDataset(dataset: [(features: [Double], label: String)],
                               weight: Double,
                               completion: @escaping (Bool) -> Void) {
        var successCount = 0
        
        for data in dataset {
            sendData(data.features, withLabel: data.label, weight: weight) { success in
                if success {
                    successCount += 1
                }
                
                if successCount == dataset.count {
                    completion(true) // All items uploaded successfully
                } else if successCount + (dataset.count - successCount) == dataset.count {
                    completion(false) // Some or all items failed
                }
            }
        }
    }
    
    // MARK: - Send Data Helper
    
    private func sendData(_ array: [Double], withLabel label: String, weight: Double,
                          completion: @escaping (Bool) -> Void) {
        let baseURL = "http://\(server_ip):8000/labeled_data/"
        guard let postUrl = URL(string: baseURL) else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: postUrl)
        do {
            let requestBody: Data = try JSONSerialization.data(withJSONObject: [
                "feature": array,
                "label": label,
                "dsid": self.dsid,
                "weight": weight
            ])
            
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = requestBody
            
            let postTask: URLSessionDataTask = self.session.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error sending data: \(error)")
                    completion(false)
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("Feature vector sent successfully.")
                    completion(true)
                } else {
                    print("Unexpected server response: \(String(describing: response))")
                    completion(false)
                }
            }
            postTask.resume()
        } catch {
            print("Error serializing JSON: \(error)")
            completion(false)
        }
    }
}



