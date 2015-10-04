//
//  RoosterViewController.swift
//  Jolt
//
//  Created by Lee Danilek on 10/3/15.
//  Copyright © 2015 CAL. All rights reserved.
//

import UIKit

class RoosterViewController: UIViewController {

    @IBOutlet weak var turnOffButton: UIButton!
    @IBAction func turnOff(sender: UIButton) {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.turnOffButton.layer.cornerRadius = 20
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
