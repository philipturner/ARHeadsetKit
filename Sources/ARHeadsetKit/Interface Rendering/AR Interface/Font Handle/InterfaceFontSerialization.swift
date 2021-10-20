//
//  InterfaceFontSerialization.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/29/21.
//

#if !os(macOS)
import Foundation
import ZippyJSON

extension InterfaceRenderer {
    
    static func readSignedDistanceFieldData<T: BinaryFloatingPoint>(fontName: String,
                                                                    fontSize: T) -> (compressedData: Data, uncompressedSize: Int)? {
        objc_sync_enter(Self.self)
        let (directory, _, descriptors) = retrieveSignedDistanceFieldDescriptors()
        objc_sync_exit(Self.self)
        
        let descriptor = FieldDescriptor(fontName: fontName, fontSize: Double(fontSize), uncompressedDataSize: -1)
        
        guard let matchingElement = descriptors.first(where: {
            $0.descriptor.fontName == descriptor.fontName &&
            $0.descriptor.fontSize == descriptor.fontSize
        }) else {
            return nil
        }
        
        let fileURL = directory.appendingPathComponent("\(matchingElement.fileID).data", isDirectory: false)
        let fileHandle = try! FileHandle(forReadingFrom: fileURL)
        let output = fileHandle.availableData
        
        try! fileHandle.close()
        return (output, matchingElement.descriptor.uncompressedDataSize)
    }
    
    static func writeSignedDistanceFieldData<T: BinaryFloatingPoint>(fontName: String, fontSize: T,
                                                                     compressedData: Data, uncompressedDataSize: Int) {
        objc_sync_enter(Self.self)
        let (directory, descriptorURL, descriptors) = retrieveSignedDistanceFieldDescriptors()
        let descriptor = FieldDescriptor(fontName: fontName, fontSize: Double(fontSize), uncompressedDataSize: uncompressedDataSize)
        
        guard !descriptors.contains(where: { $0.descriptor == descriptor }) else {
            objc_sync_exit(Self.self)
            debugLabel { print("Attempted to write to a signed distance field that was already present!") }
            return
        }
        
        var fileID = arc4random()
        
        while descriptors.contains(where: { $0.fileID == fileID }) {
            fileID = arc4random()
        }
        
        let newDescriptors = descriptors + [.init(descriptor: descriptor, fileID: fileID)]
        let newDescriptorData = serializeFieldDescriptors(newDescriptors)
        try! newDescriptorData.write(to: descriptorURL, options: .atomic)
        objc_sync_exit(Self.self)
        
        let fileURL = directory.appendingPathComponent("\(fileID).data", isDirectory: false)
        try! compressedData.write(to: fileURL, options: .atomic)
    }
    
}

extension InterfaceRenderer {
    
    fileprivate struct FieldDescriptor: Codable, Equatable {
        var fontName: String
        var fontSize: Double
        var uncompressedDataSize: Int
    }
    
    fileprivate struct DescriptorElement: Codable {
        var descriptor: FieldDescriptor
        var fileID: UInt32
    }
    
    fileprivate static func serializeFieldDescriptors(_ descriptors: [DescriptorElement]) -> Data {
        do {
            return try JSONEncoder().encode(descriptors)
        } catch {
            debugLabel { print("Error serializing descriptors: \(error.localizedDescription)") }
            return Data()
        }
    }
    
    fileprivate static func deserializeFieldDescriptors(_ data: Data) -> [DescriptorElement] {
        do {
            return try ZippyJSONDecoder().decode([DescriptorElement].self, from: data)
        } catch {
            debugLabel { print("Error deserializing descriptors: \(error.localizedDescription)") }
            return []
        }
    }
    
    fileprivate static func retrieveSignedDistanceFieldDescriptors() -> (directory: URL,
                                                                         descriptorURL: URL,
                                                                         descriptors: [DescriptorElement])
    {
        var directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory.appendPathComponent("ARHeadsetKit/Interface Renderer/Signed Distance Fields", isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let descriptorURL = directory.appendingPathComponent("descriptors.json", isDirectory: false)
        var descriptors: [DescriptorElement]
        
        if let data = try? Data(contentsOf: descriptorURL) {
            descriptors = deserializeFieldDescriptors(data)
        } else {
            descriptors = []
        }
        
        return (directory, descriptorURL, descriptors)
    }
    
}
#endif
