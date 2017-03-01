//
//  DiskStatus.swift
//  OwnRadio
//
//  Created by Roman Litoshko on 12/7/16.
//  Copyright © 2016 Roll'n'Code. All rights reserved.
//
//	Methods for check memmory

import Foundation

class DiskStatus {
	
	//MARK: Formatter MB only
	class func MBFormatter(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.allowedUnits = ByteCountFormatter.Units.useMB
		formatter.countStyle = ByteCountFormatter.CountStyle.decimal
		formatter.includesUnit = false
		return formatter.string(fromByteCount: bytes) as String
	}
	
	//MARK: Get String Value
	class var totalDiskSpace:String {
		get {
			return ByteCountFormatter.string(fromByteCount: Int64(totalDiskSpaceInBytes), countStyle: ByteCountFormatter.CountStyle.binary)
		}
	}
	
	class var freeDiskSpace:String {
		get {
			return ByteCountFormatter.string(fromByteCount: Int64(freeDiskSpaceInBytes), countStyle: ByteCountFormatter.CountStyle.binary)
		}
	}
	
	class var usedDiskSpace:String {
		get {
			return ByteCountFormatter.string(fromByteCount: Int64(usedDiskSpaceInBytes), countStyle: ByteCountFormatter.CountStyle.binary)
		}
	}

	//MARK: Get raw value
	//возвращает общее количество памяти
	class var totalDiskSpaceInBytes:UInt64 {
		get {
			do {
				let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
				let space = (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.uint64Value
				return space!
			} catch {
				return 0
			}
		}
	}
	
	//возвращает количество памяти, занимаемое треками
	class func folderSize(folderPath:String) -> UInt{

		let filesArray:[String]? = try? FileManager.default.subpathsOfDirectory(atPath: folderPath) as [String]
		var fileSize:UInt = 0
		
		for fileName in filesArray!{
			
			let folderUrl = NSURL(string: folderPath)
			let filePath = folderUrl?.appendingPathComponent(fileName)
			do {
				let fileDictionary:NSDictionary = try FileManager.default.attributesOfItem(atPath: (filePath?.absoluteString)!) as NSDictionary
				fileSize += UInt(fileDictionary.fileSize())
			} catch {
				print(error.localizedDescription)
			}
		}
		
		return fileSize
	}
	
	//возвращает количество свободной памяти
	class var freeDiskSpaceInBytes:UInt64 {
		get {
			do {
				let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
				let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.uintValue
				return freeSpace!
			} catch {
				return 0
			}
		}
	}
	
	
	//возвращает общее количество занятой памяти
	class var usedDiskSpaceInBytes:UInt64 {
		get {
			let usedSpace = totalDiskSpaceInBytes - freeDiskSpaceInBytes
			return usedSpace
		}
	}
	
}

