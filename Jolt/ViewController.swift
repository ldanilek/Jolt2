//
//  ViewController.swift
//  Jolt
//
//  Created by Lee Danilek on 10/3/15.
//  Copyright © 2015 CAL. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, MSBClientManagerDelegate {
    
    var client: MSBClient?
    var heartRateUpdating: Bool = false
    var gyroUpdating: Bool = false
    var lastAlert = NSDate(timeIntervalSince1970: 0);
    var dataPoints: Array<Int> = []
    var fiveRates: Array<Int> = []
    var lastMoved = NSDate(timeIntervalSince1970: 0);

    override func viewDidLoad() {
        MSBClientManager.sharedManager().delegate = self
        if let attachedClient = MSBClientManager.sharedManager().attachedClients().first as? MSBClient {
            MSBClientManager.sharedManager().connectClient(attachedClient)
            client = attachedClient
        }
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(animated: Bool) {
        let consent: MSBUserConsent? = self.client?.sensorManager.heartRateUserConsent()
        if let theconsent = consent {
            switch theconsent {
            case .Declined:
                self.statusLabel.text = "heartrate consent declined"
            case .Granted:
                self.startHeartrateUpdates()
            case .NotSpecified:
                self.client?.sensorManager.requestHRUserConsentWithCompletion({ (requestedConsent, error) -> Void in
                    if let e = error {
                        self.statusLabel.text = "error \(e.description)"
                    }
                    if requestedConsent {
                        self.startHeartrateUpdates()
                    } else {
                        self.statusLabel.text = "heartrate requested, declined"
                    }
                })
            }
        }
        self.startGyroSensing()
    }
    
    @IBOutlet weak var statusLabel: UILabel!

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func average(array : Array<Int>) -> Double {
        var sum = 0
        for a in array {
            sum += a
        }
        var retval: Double
        retval = Double(sum)
        return (retval/5)
    }
    
    func storeData(point : Double) {
        
    }
    
    func startHeartrateUpdates() {
        if self.heartRateUpdating {
            return
        }
        do {
            self.heartRateUpdating = true
            try self.client?.sensorManager.startHeartRateUpdatesToQueue(NSOperationQueue(), withHandler: { (heartRateData, error) -> Void in
                if let e = error {
                    print("error \(e.description)")
                }
                let rate = heartRateData.heartRate
                //add the data to our storage
                let currentTime = NSDate()
                if currentTime.timeIntervalSinceDate(self.lastMoved) < 10 {
                    self.fiveRates.append(Int(rate))
                    print("store awake data \(rate)")
                    if (self.fiveRates.count > 4) {
                        let avg = self.average(self.fiveRates)
                        self.storeData(avg)
                        self.fiveRates = []
                    }
                }
                else
                {
                    //var quality = heartRateData.quality
                    NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                        self.heartrateLabel.text = "\(rate)"
                        let currentDate = NSDate()
                        print("Heart rate detected \(rate)")
                        if rate < 70 && currentDate.timeIntervalSinceDate(self.lastAlert) > 20 {
                            self.sendNotification(nil)
                            self.lastAlert = currentDate
                        }
                    })
                }
            })
        } catch {
            heartRateUpdating = false
            print("Exceptin here")
        }
        
    }
    
    func stopHeartrateSensing() {
        do {
            try self.client?.sensorManager.stopHeartRateUpdatesErrorRef()
        } catch {
            print("Unexpected exception")
        }
        
    }

    @IBAction func sendNotification(sender: UIButton?) {
        if (client?.isDeviceConnected == true) {
            /*var e = "none"
            do {
                let id = NSUUID(UUIDString: "DCBABA9F-12FD-47A5-83A9-E7270A4399BB")
                e = "here"
                let image = try MSBIcon(UIImage: UIImage(contentsOfFile: "jolt-46.png"))
                e = "there"
                let smallImage = try MSBIcon(UIImage: UIImage(contentsOfFile: "Jolt-24.png"))
                e = "everywhere"
                var tileName = "Notification"
              
                let tile = try MSBTile(id: id, name: tileName, tileIcon: image, smallIcon: smallImage)
                e = "wtf?"
              
                client?.tileManager.addTile(tile, completionHandler: { (a) -> Void in})
                
                client?.notificationManager.sendMessageWithTileID(id, title: tileName, body: "Testing a notification", timeStamp: NSDate(), flags: MSBNotificationMessageFlags.ShowDialog, completionHandler: { (a) -> Void in
                    
                })
            } catch {
                print("except \(e) \(error)")
            }
            */
            self.client?.notificationManager.vibrateWithType(MSBNotificationVibrationType.Alarm, completionHandler: { (e) -> Void in
                
            })
        }
    }
    
    func startGyroSensing() {
        if gyroUpdating {
            gyroUpdating = true
        }
        do {
            try self.client?.sensorManager.startGyroscopeUpdatesToQueue(NSOperationQueue(), withHandler: { (gyroscopeData, error) -> Void in
                let newX = gyroscopeData.x
                let newY = gyroscopeData.y
                let newZ = gyroscopeData.z
                if abs(newX) > 20 || abs(newY) > 20 || abs(newZ) > 20 {
                    self.lastMoved = NSDate()
                    print("Movement detected");
                }
            })
        } catch {
            gyroUpdating = false
            print("gyro had exception")
        }
    }
    
    func clientManager(clientManager: MSBClientManager!, client: MSBClient!, didFailToConnectWithError error: NSError!) {
        self.statusLabel.text = "connection failed"
        self.heartRateUpdating = false
    }
    
    func clientManager(clientManager: MSBClientManager!, clientDidConnect client: MSBClient!) {
        self.statusLabel.text = "did connect"
        self.startHeartrateUpdates()
        self.startGyroSensing()
    }
    
    func clientManager(clientManager: MSBClientManager!, clientDidDisconnect client: MSBClient!) {
        self.statusLabel.text = "did disconnect"
        self.heartRateUpdating = false
    }

    @IBOutlet weak var heartrateLabel: UILabel!
}