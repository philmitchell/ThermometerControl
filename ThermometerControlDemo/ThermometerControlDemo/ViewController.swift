//
//  ViewController.swift
//  ThermometerControlDemo
//
//  Created by PHILIP MITCHELL on 5/16/18.
//  Copyright © 2018 NONE. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var thermometerLabel: UILabel!
    
    @IBOutlet weak var thermometerControl: ThermometerControl!

    override func viewDidLoad() {
        super.viewDidLoad()

        thermometerControl.isContinuous = true
        thermometerControl.addTarget(self, action: #selector(thermometerChanged), for: .valueChanged)
        thermometerControl.showsWaypoints = true
    }

    @objc func thermometerChanged() {

        let degrees = String(format: "%0.1f", thermometerControl.degrees)
        thermometerLabel.text = "\(degrees) \(thermometerControl.baseUnit.abbreviation)"

    }

}

