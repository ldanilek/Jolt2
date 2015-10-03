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

    override func viewDidLoad() {
        MSBClientManager.sharedManager().delegate = self
        if let attachedClient = MSBClientManager.sharedManager().attachedClients().first as? MSBClient {
            MSBClientManager.sharedManager().connectClient(attachedClient)
        }
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    @IBOutlet weak var statusLabel: UILabel!

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func sendNotification(sender: UIButton) {
        
    }
    
    func clientManager(clientManager: MSBClientManager!, client: MSBClient!, didFailToConnectWithError error: NSError!) {
        self.statusLabel.text = "connection failed"
    }
    
    func clientManager(clientManager: MSBClientManager!, clientDidConnect client: MSBClient!) {
        self.statusLabel.text = "did connect"
    }
    
    func clientManager(clientManager: MSBClientManager!, clientDidDisconnect client: MSBClient!) {
        self.statusLabel.text = "did disconnect"
    }

    @IBOutlet weak var heartrateLabel: UILabel!
}