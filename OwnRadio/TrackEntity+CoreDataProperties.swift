//
//  TrackEntity+CoreDataProperties.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 12/1/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//

import Foundation
import CoreData


extension TrackEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TrackEntity> {
        return NSFetchRequest<TrackEntity>(entityName: "TrackEntity");
    }

    @NSManaged public var recId: String?
    @NSManaged public var recCreated: String?
    @NSManaged public var recUpdated: String?
    @NSManaged public var countPlay: Int32

}
