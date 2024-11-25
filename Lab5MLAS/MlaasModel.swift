//
//  MlaasModel.swift
//  HTTPSwiftExample
//
//  Created by Eric Cooper Larson on 6/5/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//




/// This model uses delegation to interact with the main controller. The two functions below are for notifying the user that an update was completed successfully on the server. They must be implemented.
protocol ClientDelegate{
    func updateDsid(_ newDsid:Int) // if the delegate needs to update UI
    func receivedPrediction(_ prediction:[String:Any])
}

enum RequestEnum:String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

import UIKit

class MlaasModel: NSObject, URLSessionDelegate{
    
    //MARK: Properties and Delegation
    private let operationQueue = OperationQueue()
    // default ip, if you are unsure try: ifconfig |grep "inet "
    // to see what your public facing IP address is
    var server_ip = "10.9.182.106" // this will be the default ip
    // create a delegate for using the protocol
    var delegate:ClientDelegate?
    private var dsid:Int = 5
    
    // public access methods
    func updateDsid(_ newDsid:Int){
        dsid = newDsid
    }
    func getDsid()->(Int){
        return dsid
    }
    
    lazy var session = {
        let sessionConfig = URLSessionConfiguration.ephemeral
        
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 8.0
        sessionConfig.httpMaximumConnectionsPerHost = 1
        
        let tmp = URLSession(configuration: sessionConfig,
            delegate: self,
            delegateQueue:self.operationQueue)
        
        return tmp
        
    }()
    
    //MARK: Setters and Getters
    func setServerIp(ip:String)->(Bool){
        // user is trying to set ip: make sure that it is valid ip address
        if matchIp(for:"((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.|$)){4}", in: ip){
            server_ip = ip
            // return success
            return true
        }else{
            return false
        }
    }
    
    
    //MARK: Main Functions
    func sendData(_ array:[Double], withLabel label:String){
        let baseURL = "http://\(server_ip):8000/labeled_data/"
        
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        // utility method to use from below
        let requestBody:Data = try! JSONSerialization.data(withJSONObject: ["feature":array,
            "label":"\(label)",
            "dsid":self.dsid])
        
        // The Type of the request is given here
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody
        
        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                        completionHandler:{(data, response, error) in
            //TODO: notify delegate?
            if(error != nil){
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
                let jsonDictionary = self.convertDataToDictionary(with: data)
                
                print(jsonDictionary["feature"]!)
                print(jsonDictionary["label"]!)
            }
        })
        postTask.resume() // start the task
    }
    
    // post data without a label (updated for no turi)
    func sendData(_ array:[Double]){
        let baseURL = "http://\(server_ip):8000/predict_sklearn/"
        let postUrl = URL(string: "\(baseURL)")

        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)

        // utility method to use from below
        let requestBody:Data = try! JSONSerialization.data(withJSONObject: ["feature":array,
            "dsid":self.dsid])

        // The Type of the request is given here
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody

        let postTask : URLSessionDataTask = self.session.dataTask(with: request,
                            completionHandler:{(data, response, error) in
            
            if(error != nil){
                print("Error from server")
                if let res = response{
                    print("Response:\n",res)
                }
            }
            else{
                
                if let delegate = self.delegate {
                    let jsonDictionary = self.convertDataToDictionary(with: data)
                    delegate.receivedPrediction(jsonDictionary)
                }
            }
        })
        
        postTask.resume() // start the task
    }

    
    // get and store a new DSID
    func getNewDsid(){
        let baseURL = "http://\(server_ip):8000/max_dsid/"
        let postUrl = URL(string: "\(baseURL)")
        
        // create a custom HTTP POST request
        var request = URLRequest(url: postUrl!)
        
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let getTask : URLSessionDataTask = self.session.dataTask(with: request,
                        completionHandler:{(data, response, error) in
            // TODO: handle error!
            let jsonDictionary = self.convertDataToDictionary(with: data)
                            
            if let delegate = self.delegate, 
                let resp=response,
                let dsid = jsonDictionary["dsid"] as? Int {
                // tell delegate to update interface for the Dsid
                self.dsid = dsid+1
                delegate.updateDsid(self.dsid)
                
                print(resp)
            }

        })
        
        getTask.resume() // start the task
        
    }
    
    // updated for no turi
    func trainModel(){
        let baseURL = "http://\(server_ip):8000/train_model_sklearn/\(dsid)"
        let postUrl = URL(string: "\(baseURL)")

        // create a custom HTTP GET request
        var request = URLRequest(url: postUrl!)

        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let getTask : URLSessionDataTask = self.session.dataTask(with: request,
                            completionHandler:{(data, response, error) in
            // TODO: handle error!
            let jsonDictionary = self.convertDataToDictionary(with: data)
                            
            if let summary = jsonDictionary["summary"] as? String {
                // tell delegate to update interface for the Dsid
                print(summary)
            }

        })
        
        getTask.resume() // start the task
    }

    
    //MARK: Utility Functions
    private func matchIp(for regex:String, in text:String)->(Bool){
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            if results.count > 0{return true}
            
        } catch _{
            return false
        }
        return false
    }
    
    private func convertDataToDictionary(with data:Data?)->[String:Any]{
        // convenience function for getting Dictionary from server data
        do { // try to parse JSON and deal with errors using do/catch block
            let jsonDictionary: [String:Any] =
                try JSONSerialization.jsonObject(with: data!,
                                                 options: JSONSerialization.ReadingOptions.mutableContainers) as! [String : Any]
            
            return jsonDictionary
            
        } catch {
            print("json error: \(error.localizedDescription)")
            if let strData = String(data:data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue)){
                print("printing JSON received as string: "+strData)
            }
            return [String:Any]() // just return empty
        }
    }
    
    func testConnection(completion: @escaping (Bool) -> Void) {
        let baseURL = "http://\(server_ip):8000/max_dsid/"
        guard let url = URL(string: baseURL) else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("Connection error: \(error.localizedDescription)")
                completion(false)
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Connected to server")
                completion(true)
            } else {
                print("Failed to connect, status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                completion(false)
            }
        }
        task.resume()
    }




}
