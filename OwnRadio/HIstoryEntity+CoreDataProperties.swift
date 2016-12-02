//
//  HIstoryEntity+CoreDataProperties.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 12/2/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//

import Foundation
import CoreData


extension HIstoryEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HIstoryEntity> {
        return NSFetchRequest<HIstoryEntity>(entityName: "HIstoryEntity");
    }

    @NSManaged public var recCreated: String?
    @NSManaged public var recId: String?
    @NSManaged public var trackId: String?
    @NSManaged public var isListen: Int32

}
