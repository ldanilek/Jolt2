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
    var lastAlert = NSDate(timeIntervalSince1970: 0);

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
    }
    
    @IBOutlet weak var statusLabel: UILabel!

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
                //var quality = heartRateData.quality
                NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                    self.heartrateLabel.text = "\(rate)"
                    let currentDate = NSDate()
                    if rate < 70 && currentDate.timeIntervalSinceDate(self.lastAlert) > 20 {
                        self.sendNotification(nil)
                        self.lastAlert = currentDate
                    }
                })
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
    
    /*func startGyroSensing() {
        do {
            try self.client?.sensorManager.startGyroscopeUpdatesToQueue(NSOperationQueue(), withHandler: { (gyroscopeData, error) -> Void in
                let newX = gyroscopeData.x
                let newY = gyroscopeData.y
                let newZ = gyroscopeData.z
                
            })
        } catch {
            print("gyro had exception")
        }
    }*/
    
    func clientManager(clientManager: MSBClientManager!, client: MSBClient!, didFailToConnectWithError error: NSError!) {
        self.statusLabel.text = "connection failed"
        self.heartRateUpdating = false
    }
    
    func clientManager(clientManager: MSBClientManager!, clientDidConnect client: MSBClient!) {
        self.statusLabel.text = "did connect"
        self.startHeartrateUpdates()
    }
    
    func clientManager(clientManager: MSBClientManager!, clientDidDisconnect client: MSBClient!) {
        self.statusLabel.text = "did disconnect"
        self.heartRateUpdating = false
    }

    @IBOutlet weak var heartrateLabel: UILabel!
}