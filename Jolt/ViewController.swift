//
//  ViewController.swift
//  Jolt
//
//  Created by Lee Danilek on 10/3/15.
//  Copyright © 2015 CAL. All rights reserved.
//

import UIKit
import CoreBluetooth
import AudioToolbox

class ViewController: UIViewController, MSBClientManagerDelegate, MSBClientTileDelegate {
    
    var client: MSBClient?
    var heartRateUpdating: Bool = false
    var gyroUpdating: Bool = false
    var lastAlert = NSDate(timeIntervalSince1970: 0);
    var dataPoints: Array<Double> = []
    var fiveRates: Array<Int> = []
    var fiveRatesForCompare: Array<Int> = []
    var lastMoved = NSDate(timeIntervalSince1970: 0);
    @IBOutlet weak var status_sleep: UILabel!
    @IBOutlet weak var moving: UILabel!
    var showingRooster = false
    
    var tileId: NSUUID?
    var tile: MSBTile!
    
    var highPriority: Bool = NSUserDefaults.standardUserDefaults().boolForKey("priority") {
        didSet {
            NSUserDefaults.standardUserDefaults().setBool(highPriority, forKey: "priority")
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    
    override func viewDidLoad() {
        MSBClientManager.sharedManager().delegate = self
        if let attachedClient = MSBClientManager.sharedManager().attachedClients().first as? MSBClient {
            MSBClientManager.sharedManager().connectClient(attachedClient)
            client = attachedClient
        }
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.prioritySwitch.on = self.highPriority
    }
    
    override func viewWillAppear(animated: Bool) {
        let consent: MSBUserConsent? = self.client?.sensorManager.heartRateUserConsent()
        if let theconsent = consent {
            switch theconsent {
            case .Declined:
                break
                //self.statusLabel.text = "heartrate consent declined"
            case .Granted:
                self.startHeartrateUpdates()
            case .NotSpecified:
                self.client?.sensorManager.requestHRUserConsentWithCompletion({ (requestedConsent, error) -> Void in
                    if requestedConsent {
                        self.startHeartrateUpdates()
                    } else {
                        //self.statusLabel.text = "heartrate requested, declined"
                    }
                })
            }
        }
        self.startGyroSensing()
        self.showingRooster = false
        
    }
    
    //@IBOutlet weak var statusLabel: UILabel!
    
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
        return retval / Double(array.count)
    }
    
    func storeData(point : Double) {
        if (self.dataPoints.count > 499) {
            self.dataPoints = Array(self.dataPoints.dropFirst())
        }
        self.dataPoints.append(point)
    }
    
    func calculateAverageAndStandardDeviation() -> (Double, Double) {
        var avg = Double(0)
        for a in self.dataPoints {
            avg += a
        }
        avg /= Double(self.dataPoints.count)
        
        var variance = Double(0)
        for a in self.dataPoints {
            variance += (a - avg)*(a - avg)
        }
        variance /= Double(self.dataPoints.count) - 1.0
        
        return (avg, sqrt(variance))
    }
    
    func startHeartrateUpdates() {
        status_sleep.text = "awake"
        if self.heartRateUpdating {
            return
        }
        do {
            self.heartRateUpdating = true
            try self.client?.sensorManager.startHeartRateUpdatesToQueue(NSOperationQueue(), withHandler: { (heartRateData, error) -> Void in
                if let e = error {
                    print("error \(e.description)")
                }
                
                //print information to the console
                let (avg, std) = self.calculateAverageAndStandardDeviation()
                print("standard deviation : \(std) average : \(avg)")
                
                let rate = heartRateData.heartRate
                if heartRateData.quality == MSBSensorHeartRateQuality.Acquiring {
                    return
                }
                
                //add the data to our storage
                let currentTime = NSDate()
                if currentTime.timeIntervalSinceDate(self.lastMoved) > 2 {
                    self.moving.text = "Still"
                }
                if !self.showingRooster {
                    if currentTime.timeIntervalSinceDate(self.lastMoved) < 10 {
                        self.status_sleep.text = "awake"
                        self.fiveRates.append(Int(rate))
                        print("store awake data \(rate)")
                        NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                            self.heartrateLabel.text = "\(rate)"
                        })
                        if (self.fiveRates.count > 4) {
                            let avg = self.average(self.fiveRates)
                            self.storeData(avg)
                            self.fiveRates = []
                        }
                    }
                    else
                    {
                        
                        self.fiveRatesForCompare.append(Int(rate))
                        if self.fiveRatesForCompare.count > 5 {
                            self.fiveRatesForCompare = Array(self.fiveRatesForCompare.dropFirst())
                        }
                        
                        NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                            self.moving.text = "Still"
                            self.heartrateLabel.text = "\(rate)"
                            let currentDate = NSDate()
                            print("Heart rate detected \(rate)")
                            if currentDate.timeIntervalSinceDate(self.lastAlert) > 20 {
                                let (avg, std) = self.calculateAverageAndStandardDeviation()
                                let testValue = self.average(self.fiveRatesForCompare)
                                let stdevs = self.highPriority ? 1.0 : 2.0;
                                var addMe = Float(currentDate.timeIntervalSinceDate(self.lastMoved))
                                addMe = addMe * 0.0001
                                let percentageCutoff = self.highPriority ? (addMe + 0.8) : (addMe + 0.75)
                                
                                print("percentage cutoff : \(percentageCutoff)")
                                
                                if (avg - std * stdevs) > testValue && percentageCutoff*Float(avg) > Float(testValue) && self.dataPoints.count > 3 {
                                    print("asleep!!! value is \(testValue), avg is \(avg), std is \(std)")
                                    self.sendVisualNotification()
                                    self.sendNotification(nil)
                                    self.lastAlert = currentDate
                                }
                            }
                            
                        })
                        
                    }
                } else {
                    if NSDate().timeIntervalSinceDate(self.lastAlert) > 2 {
                        NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                            self.sendNotification(nil)
                        })
                        self.lastAlert = NSDate()
                    }
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
    
    func sendVisualNotification() {
        // only gets called once
        if let id = tileId {
            self.client?.notificationManager.sendMessageWithTileID(id, title: "Wake Up!", body: "You fell asleep", timeStamp: NSDate(), flags: MSBNotificationMessageFlags.ShowDialog, completionHandler: { (err) -> Void in
                print("tile notification error \(err)")
            })
        }
    }
    
    @IBAction func sendNotification(sender: UIButton?) {
        if sender != nil {
            self.sendVisualNotification()
        }
        if client?.isDeviceConnected == true {
            if !showingRooster {
                self.performSegueWithIdentifier("rooster", sender: nil)
                showingRooster = true
            }
            status_sleep.text = "asleep"
            self.client?.notificationManager.vibrateWithType(MSBNotificationVibrationType.Timer, completionHandler: { (e) -> Void in
                
            })
            //self.NSString *path = [[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] pathForResource:@"Ascending" ofType:@"aiff"]
            //let path = NSBundle(identifier: "com.apple.UIKit")?.URLForResource("Ascending", withExtension: "aiff")
            //var systemSoundId: SystemSoundID = 0
            //AudioServicesCreateSystemSoundID(path!, &systemSoundId)
            //AudioServicesPlayAlertSoundWithCompletion(systemSoundId, { () -> Void in
                
            //})
            //self.AudioServicesCreateSystemSoundID("Ascending", &path)
            //self.AudioServicesPlayAlertSound(alarum) //players gonna play
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
                    NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                        self.moving.text = "Moving"
                    })
                    
                }
            })
        } catch {
            gyroUpdating = false
            print("gyro had exception")
        }
    }
    
    func clientManager(clientManager: MSBClientManager!, client: MSBClient!, didFailToConnectWithError error: NSError!) {
        //self.statusLabel.text = "connection failed"
        self.heartRateUpdating = false
    }
    
    func addTile() {
        //send a tile
        var e = "none"
        do {
            client?.tileManager.tilesWithCompletionHandler({ (tiles, error) -> Void in
                if let e = error {
                    print("error is \(e)")
                    //handle error
                }
                print("printing all tiles")
                for t in tiles {
                    let tile = t as! MSBTile
                    print("tileName : \(tile.name)")
                }
                
            })
            
            tileId = NSUUID(UUIDString: "DCBABA9F-12FD-47A5-83A9-E7270A4399BA")
            e = "here"
            let img = UIImage(named: "jolt-46-3.png")
            e = "who?"
            let image = try MSBIcon(UIImage: img)
            e = "there"
            let smallImage = try MSBIcon(UIImage: UIImage(named: "Jolt-24-3.png"))
            e = "everywhere"
            let tileName = "Jolt"
            
            let tile = try MSBTile(id: tileId!, name: tileName, tileIcon: image, smallIcon: smallImage)
            e = "wtf?"
            
            let panel = MSBPageFlowPanel(rect: MSBPageRect(x: 0, y: 0, width: 243, height: 102))
            panel.horizontalAlignment = MSBPageHorizontalAlignment.Left
            panel.verticalAlignment = MSBPageVerticalAlignment.Top
            let textButton = MSBPageTextButton(rect: MSBPageRect(x: 0, y: 0, width: 240, height: 102))
            textButton.elementId = 1;
            textButton.margins = MSBPageMargins(left: 15, top: 0, right: 15, bottom: 0)
            //5420A4
            textButton.pressedColor = MSBColor(red: 0x54, green: 0x20, blue: 0xA4)
            panel.addElement(textButton)
            let layout = MSBPageLayout()
            // create the page layout
            layout.root = panel;
            tile.pageLayouts.addObject(layout)
            self.tile = tile
            
            client?.tileManager.addTile(tile, completionHandler: { (a) -> Void in})
            client?.tileDelegate = self
            
            let buttonPageId = NSUUID()
            do {
                let textButtonData = try MSBPageTextButtonData(elementId: 1, text: "Awake Now")
                let pageData = MSBPageData(id: buttonPageId, layoutIndex: 0, value: [textButtonData])
                self.client?.tileManager.setPages([pageData], tileId: tileId!, completionHandler: { (err) -> Void in
                    
                })
            } catch {
                print("error making button data \(error)")
            }
            
        } catch {
            print("except \(e) \(error)")
        }
    }
    
    func clientManager(clientManager: MSBClientManager!, clientDidConnect client: MSBClient!) {
        //self.statusLabel.text = "did connect"
        self.startHeartrateUpdates()
        self.startGyroSensing()
        self.addTile()
    }
    
    func clientManager(clientManager: MSBClientManager!, clientDidDisconnect client: MSBClient!) {
        //self.statusLabel.text = "did disconnect"
        self.heartRateUpdating = false
    }
    
    func client(client: MSBClient!, tileDidClose event: MSBTileEvent!) {
        print("tile closed")
    }
    
    func client(client: MSBClient!, buttonDidPress event: MSBTileButtonEvent!) {
        if self.showingRooster {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    func client(client: MSBClient!, tileDidOpen event: MSBTileEvent!) {
        print("tile opened")
    }
    @IBAction func priorityChanged(sender: UISwitch) {
        self.highPriority = sender.on
    }
    
    @IBOutlet weak var prioritySwitch: UISwitch!
    @IBOutlet weak var heartrateLabel: UILabel!
}