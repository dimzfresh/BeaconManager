//
//  ViewController.swift
//  BeaconMonitor
//
//  Created by Dmitrii Ziablikov on 23/01/2019.
//  Copyright © 2019 chaopay. All rights reserved.
//

import UIKit
import CoreLocation

class ListenViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var resultLabel: UILabel!
    
    private var scanner: BeaconManager?
    
    fileprivate var allBeacons: [CLBeacon]? {
        didSet {
            // logic here
            print("We found beacons")
            
            showResult()
        }
    }
    
    fileprivate var knownBeacons: [CLBeacon]? {
        didSet {
            // logic here
            print("We found beacons")
        }
    }
    
    // MARK: - lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScanner()
    }
    
    fileprivate func setupScanner() {
        guard let uuid = UIDevice.current.identifierForVendor else { return }
        
        titleLabel.text = "iBeacons for your UUID: \n\(uuid.uuidString)"
        
        scanner = BeaconManager(uuid: uuid)
        scanner?.delegate = self
        scanner?.startListening()
    }
    
    fileprivate func showResult() {
        var text = ""
        allBeacons?.forEach {
            text += "\n\($0.proximityUUID) \($0.rssi)"
        }
        self.resultLabel.text = text
    }
}
    
extension ListenViewController: BeaconScannerDelegate {

    func receivedAllBeacons(_ monitor: BeaconManager, beacons: [CLBeacon]) {
        
        print("All Beacons: \(beacons)")
        
        allBeacons = beacons
    }
    
    func receivedMatchingBeacons(_ monitor: BeaconManager, beacons: [CLBeacon]) {
        
        print("Matching Beacons: \(beacons)")
        
        knownBeacons = beacons
    }
    
    func turnOnBluetooth() {
        let alertController = UIAlertController(title: "Turn On Bluetooth", message: "Please turn on Bluetooth for iBeacon scanning", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true)
    }
}


