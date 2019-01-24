//
//  BeaconManager.swift
//  BeaconMonitor
//
//  Created by Dmitrii Ziablikov on 20/01/2019.
//  Copyright © 2019 chaopay. All rights reserved.
//

import CoreLocation
import CoreBluetooth

public protocol BeaconScannerDelegate: class {
    func receivedAllBeacons(_ monitor: BeaconManager, beacons: [CLBeacon])
    func receivedMatchingBeacons(_ monitor: BeaconManager, beacons: [CLBeacon])
    
    func didEnterRegion(_ region: CLRegion)
    func didExitRegion(_ region: CLRegion)
    
    func turnOnBluetooth()
}

extension BeaconScannerDelegate {
    func receivedAllBeacons(_ monitor: BeaconManager, beacons: [CLBeacon]) {}
    func receivedMatchingBeacons(_ monitor: BeaconManager, beacons: [CLBeacon]) {}
    
    func didEnterRegion(_ region: CLRegion) {}
    func didExitRegion(_ region: CLRegion) {}
}

/// Class to receive CLBeacons and notify the delegate.
open class BeaconManager: NSObject {
    
    open weak var delegate: BeaconScannerDelegate?
    
    fileprivate var centralManager: CBCentralManager? = nil
    
    /// Define if the BeaconScannerDelegate methods should also be called when the received list of beacons is empty.
    open var reportWhenEmpty = false
    
    // Name that is used as the prefix for the region identifier.
    fileprivate let regionIdentifier = "BeaconScanner"
    
    // CLLocationManager that will listen and react to Beacons.
    fileprivate var locationManager: CLLocationManager?
    
    fileprivate var regions = [String: CLBeaconRegion]()
    
    // List of Beacons the scanner should listen
    fileprivate var beaconsListening: [Beacon]?
    
    
    // MARK: - Init methods
    
    public init(uuid: UUID) {
        super.init()
        
        regions[uuid.uuidString] = self.regionForUUID(uuid)
    }
    
    public init(uuids: [UUID]) {
        super.init()
        
        uuids.forEach {
            regions[$0.uuidString] = self.regionForUUID($0)
        }
    }
    
    public init(beacons: [Beacon]) {
        super.init()
        
        beaconsListening = beacons
        
        // create a CLBeaconRegion for each different UUID
        distinctUnionOfUUIDs(beacons).forEach {
            regions[$0.uuidString] = self.regionForUUID($0)
        }
    }
    
    public init(beacon: Beacon) {
        super.init()
        
        beaconsListening = [beacon]
        
        regions[beacon.uuid.uuidString] = self.regionForBeacon(beacon)
    }
    
    
    // MARK: - Start/Stop listening
    
    //Start listening for Beacons.
    open func startListening() {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
        self.locationManager = locationManager
        centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    
    //Stop listening for all regions.
    open func stopListening() {
        regions.forEach {
            stopListening($0.value)
            regions[$0.key] = nil
        }
        
        locationManager = nil
        centralManager = nil
    }
    
    
    //Stop listening only for the region with the given UUID.
    open func stopListening(_ uuid: UUID) {
        guard let region = regions[uuid.uuidString] else { return }
        
        stopListening(region)
        regions[uuid.uuidString] = nil
    }
    
    
    // MARK: - Private Helper
    
    fileprivate func regionForUUID(_ uuid: UUID) -> CLBeaconRegion {
        let region = CLBeaconRegion(proximityUUID: uuid, identifier: "\(regionIdentifier)-\(uuid.uuidString)")
        region.notifyEntryStateOnDisplay = true
        return region
    }
    
    fileprivate func regionForBeacon(_ beacon: Beacon) -> CLBeaconRegion {
        let region = CLBeaconRegion(proximityUUID: beacon.uuid as UUID,
                                    major: CLBeaconMajorValue(beacon.major.int32Value),
                                    minor: CLBeaconMinorValue(beacon.minor.int32Value),
                                    identifier: "\(regionIdentifier)-\(beacon.uuid.uuidString)")
        region.notifyEntryStateOnDisplay = true
        return region
    }
    
    fileprivate func stopListening(_ region: CLBeaconRegion) {
        locationManager?.stopRangingBeacons(in: region)
        locationManager?.stopMonitoring(for: region)
    }
    
    fileprivate func distinctUnionOfUUIDs(_ beacons: [Beacon]) -> [UUID] {
        var dict = [UUID : Bool]()
        let filtered = beacons.filter { (element: Beacon) -> Bool in
            if dict[element.uuid as UUID] == nil {
                dict[element.uuid as UUID] = true
                return true
            }
            return false
        }
        
        return filtered.map { ($0.uuid as UUID)}
    }
}


// MARK: - CLLocationManagerDelegate

extension BeaconManager: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        
        let allBeacons = beacons.filter { $0.proximity != CLProximity.unknown }
        
        // Filter received Beacons with the provided Beacon array
        var matchingBeacons = [CLBeacon]()
        if let listening = beaconsListening {
            for b in allBeacons {
                if listening.contains(where: { $0.major == b.major && $0.minor == b.minor && $0.uuid as UUID == b.proximityUUID }) {
                    matchingBeacons.append(b)
                }
            }
        }
        
        /* Call the delegate methods and provide the CLBeacon array */
        
        if reportWhenEmpty && matchingBeacons.isEmpty {
            delegate?.receivedMatchingBeacons(self, beacons: matchingBeacons)
        } else if !matchingBeacons.isEmpty {
            delegate?.receivedMatchingBeacons(self, beacons: matchingBeacons)
        }
        
        if reportWhenEmpty && allBeacons.isEmpty {
            delegate?.receivedAllBeacons(self, beacons: allBeacons)
        } else if !allBeacons.isEmpty {
            delegate?.receivedAllBeacons(self, beacons: allBeacons)
        }
        
    }
    
    public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        
        print("did start monitoring")
        
        manager.requestState(for: region)
    }
    
    
    public func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        
        print("Did determine state")
        
        if state == .inside {
            manager.startRangingBeacons(in: region as! CLBeaconRegion)
        } else {
            manager.stopRangingBeacons(in: region as! CLBeaconRegion)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        switch status {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            
            for (_, region) in regions {
                print("start monitoring")
                manager.startMonitoring(for: region)
            }
            
        case .restricted:
            // restricted by e.g. parental controls. User can't enable Location Services
            break
        case .denied:
            // user denied your app access to Location Services, but can grant access from Settings.app
            break
        }
    }
        
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        
        print("Did Enter region \(region.identifier)")
        
        delegate?.didEnterRegion(region)
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        
        print("Did Exit region \(region.identifier)")
        
        delegate?.didExitRegion(region)
    }
    
    public func calculateDistance(_ beacon: CLBeacon) -> String {
        
        switch beacon.accuracy {
        case 0..<0.11 :
            return "Within 0.1 meter"
        case 0.11..<0.20:
            return "Within 0.2 meter"
        case 0.20..<0.30:
            return "Within 0.3 meter"
        case 0.30..<0.40:
            return "Within 0.4 meter"
        case 0.40..<0.50:
            return "Within 0.5 meter"
        case 0.50..<0.60:
            return "Within 0.6 meter"
        case 0.60..<0.70:
            return "Within 0.7 meter"
        case 0.70..<0.80:
            return "Within 0.8 meter"
        case 0.80..<0.90:
            return "Within 0.9 meter"
        case 0.90..<1:
            return "Within 1 meter"
        case 1..<2:
            return "Within 2 meter"
        case 2..<10:
            return "Beyond 2 meters"
        default:
            return "distance cant be found"
        }
    }
        
}

//MARK: CBCentralManagerDelegate

extension BeaconManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            delegate?.turnOnBluetooth()
        }
    }
}


