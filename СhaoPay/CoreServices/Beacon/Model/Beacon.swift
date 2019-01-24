//
//  Beacon.swift
//  BeaconMonitor
//
//  Created by Dmitrii Ziablikov on 23/01/2019.
//  Copyright © 2019 chaopay. All rights reserved.
//

import UIKit

public struct Beacon {
    
    public var uuid: UUID
    public var minor: NSNumber
    public var major: NSNumber
    
    public init(uuid: UUID, minor: NSNumber, major: NSNumber) {
        self.uuid = uuid
        self.minor = minor
        self.major = major
    }
}
