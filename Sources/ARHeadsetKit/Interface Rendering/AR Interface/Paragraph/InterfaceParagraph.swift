//
//  InterfaceParagraph.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/12/21.
//

import Foundation

public protocol ARParagraph {
    @inlinable static var parameters: Parameters { get }
    @inlinable static var label: String { get }
}

public extension ARParagraph {
    typealias Parameters = (stringSegments: [InterfaceRenderer.StringSegment], width: Float, pixelSize: Float)
    typealias StringSegment = InterfaceRenderer.StringSegment
}

extension InterfaceRenderer {
    
    typealias ParagraphParameters = ARParagraph.Parameters
    
    private static var pendingParagraphParameters: [ParagraphParameters] = []
    private static let cachingQueueName = "Interface Renderer Cached Paragraph Caching Queue"
    private static let cachingQueue = DispatchQueue(label: cachingQueueName, qos: .userInitiated)
    
    private static var _fontHandles: [FontHandle] = []
    static var fontHandles: [FontHandle] {
        get { _fontHandles }
        set {
            var paragraphsToCache: [ParagraphParameters]!
            
            cachingQueue.sync {
                _fontHandles = newValue
                paragraphsToCache = pendingParagraphParameters
                pendingParagraphParameters = []
            }
            
            for parameters in paragraphsToCache {
                _ = createParagraph(stringSegments: parameters.stringSegments,
                                    width:          parameters.width,
                                    pixelSize:      parameters.pixelSize)
            }
        }
    }
    
    private struct Key: Hashable {
        var strings: [String]
        var fontIDs: [Int]
        
        var width: Float
        var pixelSize: Float
        
        init(parameters: ParagraphParameters) {
            strings = parameters.stringSegments.map{ $0.string }
            fontIDs = parameters.stringSegments.map{ $0.fontID }
            
            width = parameters.width
            pixelSize = parameters.pixelSize
        }
    }
    
    private static var cachedParagraphs: [Key : ParagraphReturn] = [:]
    private static let registryQueueName = "Interface Renderer Cached Paragraph Registry Queue"
    private static let registryQueue = DispatchQueue(label: registryQueueName, qos: .userInitiated)
    
    static func searchForParagraph(_ parameters: ParagraphParameters) -> ParagraphReturn? {
        registryQueue.sync{ cachedParagraphs[Key(parameters: parameters)] }
    }
    
    static func registerParagraphReturn(_ parameters: ParagraphParameters, _ paragraphReturn: ParagraphReturn) {
        registryQueue.sync{ cachedParagraphs[Key(parameters: parameters)] = paragraphReturn }
    }
    
    fileprivate static func cacheParagraph(_ parameters: ParagraphParameters) {
        var fontHandlesExist = false
        
        cachingQueue.sync {
            if fontHandles.count == 0 {
                pendingParagraphParameters.append(parameters)
            } else {
                fontHandlesExist = true
            }
        }
        
        if fontHandlesExist {
            _ = createParagraph(stringSegments: parameters.stringSegments,
                                width:          parameters.width,
                                pixelSize:      parameters.pixelSize)
        }
    }
    
    static func resetCachedTextData() {
        pendingParagraphParameters = []
        _fontHandles = []
        cachedParagraphs = [:]
    }
    
}



public protocol ARParagraphListElement: Equatable, CaseIterable {
    @inlinable var rawValue: Int { get }
    @inlinable init?(rawValue: Int)
    
    @inlinable var parameters: Parameters { get }
    @inlinable var interfaceElement: ARInterfaceElement { get }
}

public protocol ARParagraphContainer {
    associatedtype CachedParagraph: ARParagraphListElement
}

public extension ARParagraphListElement {
    typealias Parameters = ARParagraph.Parameters
}

public extension ARParagraphContainer {
    static func cacheParagraphs() {
        for paragraph in CachedParagraph.allCases {
            InterfaceRenderer.cacheParagraph(paragraph.parameters)
        }
    }
    
    @inlinable
    static func createParagraph(_ paragraph: CachedParagraph) -> InterfaceRenderer.ParagraphReturn {
        let parameters = paragraph.parameters
        return InterfaceRenderer.createParagraph(stringSegments: parameters.stringSegments,
                                                 width:          parameters.width,
                                                 pixelSize:      parameters.pixelSize)
    }
}



public protocol ARTraceableParagraphContainer: ARParagraphContainer {
    subscript(index: CachedParagraph) -> ARInterfaceElement { get set }
}

public extension ARTraceableParagraphContainer {
    func trace(ray worldSpaceRay: RayTracing.Ray) -> (elementID: CachedParagraph, progress: Float)? {
        var elementID: CachedParagraph?
        var minProgress: Float = .greatestFiniteMagnitude

        for element in CachedParagraph.allCases where !self[element].hidden {
            if let progress = self[element].trace(ray: worldSpaceRay), progress < minProgress {
                minProgress = progress
                elementID   = element
            }
        }

        if let elementID = elementID {
            return (elementID, minProgress)
        } else {
            return nil
        }
    }
}
