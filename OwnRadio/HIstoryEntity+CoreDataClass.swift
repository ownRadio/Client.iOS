//
//  HIstoryEntity+CoreDataClass.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 12/2/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//

import Foundation
import CoreData


public class HIstoryEntity: NSManagedObject {

	convenience init() {
		self.init(entity: CoreDataManager.instance.entityForName(entityName: "HIstoryEntity"), insertInto: CoreDataManager.instance.managedObjectContext)
	}
	
}
