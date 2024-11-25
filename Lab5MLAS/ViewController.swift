//
//  ViewController.swift
//  HTTPSwiftExample
//
//  Created by Eric Larson on 3/30/15.
//  Copyright (c) 2015 Eric Larson. All rights reserved.
//  Updated 2024

// This example is meant to be run with the python example:
//              fastapi_turicreate.py
//              from the course GitHub repository



import UIKit
import CoreMotion

class ViewController: UIViewController, ClientDelegate, UITextFieldDelegate {
    
    // MARK: Class Properties
    
    // interacting with server
    let client = MlaasModel() // how we will interact with the server
    
    
    // operation queues
    let motionOperationQueue = OperationQueue()
    let calibrationOperationQueue = OperationQueue()
    
    // motion data properties
    var ringBuffer = RingBuffer()
    let motion = CMMotionManager()
    var magThreshold = 0.1
    
    // state variables
    var isCalibrating = false
    var isWaitingForMotionData = false
    
    // User Interface properties
    let animation = CATransition()
    @IBOutlet weak var dsidLabel: UILabel!
    @IBOutlet weak var upArrow: UILabel!
    @IBOutlet weak var rightArrow: UILabel!
    @IBOutlet weak var downArrow: UILabel!
    @IBOutlet weak var leftArrow: UILabel!
    @IBOutlet weak var largeMotionMagnitude: UIProgressView!
    @IBOutlet weak var enterURL: UITextField!
    
    // MARK: Class Properties with Observers
    enum CalibrationStage:String {
        case notCalibrating = "notCalibrating"
        case up = "up"
        case right = "right"
        case down = "down"
        case left = "left"
    }
    
    var calibrationStage:CalibrationStage = .notCalibrating {
        didSet{
            self.setInterfaceForCalibrationStage()
        }
    }
        
    @IBAction func magnitudeChanged(_ sender: UISlider) {
        self.magThreshold = Double(sender.value)
    }
       
    
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        client.testConnection { isConnected in
                    DispatchQueue.main.async {
                        if isConnected {
                            print("Successfully connected to the server.")
                        } else {
                            print("Failed to connect to the server.")
                        }
                    }
                }
        
        enterURL.delegate = self


        // create reusable animation
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        animation.type = CATransitionType.fade
        animation.duration = 0.5
        
        // setup core motion handlers
        startMotionUpdates()
        
        // use delegation for interacting with client 
        client.delegate = self
        client.updateDsid(5) // set default dsid to start with

    }
    
    // UITextFieldDelegate method to handle "Return" key press
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Dismiss the keyboard
        textField.resignFirstResponder()
        
        // Update the IP in the model
        if let ipText = textField.text {
            _ = client.setServerIp(ip: ipText)
            print("Server IP updated to: \(ipText)")
        }
            
        return true
    }
    
    //MARK: UI Buttons
    @IBAction func getDataSetId(_ sender: AnyObject) {
        client.getNewDsid() // protocol used to update dsid
    }
    
    @IBAction func startCalibration(_ sender: AnyObject) {
        self.isWaitingForMotionData = false // dont do anything yet
        nextCalibrationStage() // kick off the calibration stages
        
    }
    
    @IBAction func makeModel(_ sender: AnyObject) {
        client.trainModel()
    }

}

//MARK: Protocol Required Functions
extension ViewController {
    func updateDsid(_ newDsid:Int){
        // delegate function completion handler
        DispatchQueue.main.async{
            // update label when set
            self.dsidLabel.layer.add(self.animation, forKey: nil)
            self.dsidLabel.text = "Current DSID: \(newDsid)"
        }
    }
    
    func receivedPrediction(_ prediction:[String:Any]){
        if let labelResponse = prediction["prediction"] as? String{
                print(labelResponse)
                self.displayLabelResponse(labelResponse)
            }
            else{
                print("Received prediction data without label.")
            }
        }
}


//MARK: Motion Extension Functions
extension ViewController {
    // Core Motion Updates
    func startMotionUpdates(){
        // some internal inconsistency here: we need to ask the device manager for device
        
        if self.motion.isDeviceMotionAvailable{
            self.motion.deviceMotionUpdateInterval = 1.0/200
            self.motion.startDeviceMotionUpdates(to: motionOperationQueue, withHandler: self.handleMotion )
        }
    }
    
    func handleMotion(_ motionData:CMDeviceMotion?, error:Error?){
        if let accel = motionData?.userAcceleration {
            self.ringBuffer.addNewData(xData: accel.x, yData: accel.y, zData: accel.z)
            let mag = fabs(accel.x)+fabs(accel.y)+fabs(accel.z)
            
            DispatchQueue.main.async{
                //show magnitude via indicator
                self.largeMotionMagnitude.progress = Float(mag)/0.2
            }
            
            if mag > self.magThreshold {
                // buffer up a bit more data and then notify of occurrence
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
                    self.calibrationOperationQueue.addOperation {
                        // something large enough happened to warrant
                        self.largeMotionEventOccurred()
                    }
                })
            }
        }
    }
    
    // Calibration event has occurred, send to server
    func largeMotionEventOccurred(){
        if(self.isCalibrating){
            //send a labeled example
            if(self.calibrationStage != .notCalibrating && self.isWaitingForMotionData)
            {
                self.isWaitingForMotionData = false
                
                // send data to the server with label
                self.client.sendData(self.ringBuffer.getDataAsVector(),
                                     withLabel: self.calibrationStage.rawValue)
                
                self.nextCalibrationStage()
            }
        }
        else
        {
            if(self.isWaitingForMotionData)
            {
                self.isWaitingForMotionData = false
                //predict a label
                self.client.sendData(self.ringBuffer.getDataAsVector())
                // dont predict again for a bit
                setDelayedWaitingToTrue(2.0)
                
            }
        }
    }
}

//MARK: Calibration UI Functions
extension ViewController {
    
    func setDelayedWaitingToTrue(_ time:Double){
        DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: {
            self.isWaitingForMotionData = true
        })
    }
    
    func setAsCalibrating(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.red
    }
    
    func setAsNormal(_ label: UILabel){
        label.layer.add(animation, forKey:nil)
        label.backgroundColor = UIColor.white
    }
    
    // blink the UILabel
    func blinkLabel(_ label:UILabel){
        DispatchQueue.main.async {
            self.setAsCalibrating(label)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                self.setAsNormal(label)
            })
        }
    }
    
    func displayLabelResponse(_ response:String){
        switch response {
        case "['up']","up":
            blinkLabel(upArrow)
            break
        case "['down']","down":
            blinkLabel(downArrow)
            break
        case "['left']","left":
            blinkLabel(leftArrow)
            break
        case "['right']","right":
            blinkLabel(rightArrow)
            break
        default:
            print("Unknown")
            break
        }
    }
    
    func setInterfaceForCalibrationStage(){
        switch calibrationStage {
        case .up:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsCalibrating(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        case .left:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsCalibrating(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        case .down:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsCalibrating(self.downArrow)
            }
            break
            
        case .right:
            self.isCalibrating = true
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsCalibrating(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        case .notCalibrating:
            self.isCalibrating = false
            DispatchQueue.main.async{
                self.setAsNormal(self.upArrow)
                self.setAsNormal(self.rightArrow)
                self.setAsNormal(self.leftArrow)
                self.setAsNormal(self.downArrow)
            }
            break
        }
    }
    
    func nextCalibrationStage(){
        switch self.calibrationStage {
        case .notCalibrating:
            //start with up arrow
            self.calibrationStage = .up
            setDelayedWaitingToTrue(1.0)
            break
        case .up:
            //go to right arrow
            self.calibrationStage = .right
            setDelayedWaitingToTrue(1.0)
            break
        case .right:
            //go to down arrow
            self.calibrationStage = .down
            setDelayedWaitingToTrue(1.0)
            break
        case .down:
            //go to left arrow
            self.calibrationStage = .left
            setDelayedWaitingToTrue(1.0)
            break
            
        case .left:
            //end calibration
            self.calibrationStage = .notCalibrating
            setDelayedWaitingToTrue(1.0)
            break
        }
    }
    
    
}

