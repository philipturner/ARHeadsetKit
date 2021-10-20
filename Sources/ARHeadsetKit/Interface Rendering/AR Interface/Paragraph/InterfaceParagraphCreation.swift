//
//  InterfaceParagraphCreation.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/12/21.
//

#if !os(macOS)
import SwiftUI
import simd

public extension InterfaceRenderer {
    
    typealias StringSegment = (string: String, fontID: Int)
    typealias CharacterGroup = (boundingRects: [simd_float4], glyphIndices: [UInt16])
    typealias ParagraphReturn = (characterGroups: [CharacterGroup?], suggestedHeight: Float)
    
    static func scaleParagraph(_ input: inout ParagraphReturn, scale: Float) {
        input.suggestedHeight *= scale
        
        for i in 0..<input.characterGroups.count {
            if let originalBoundingRects = input.characterGroups[i]?.boundingRects {
                input.characterGroups[i]!.boundingRects = originalBoundingRects.map{ $0 * scale }
            }
        }
    }
    
    static func createParagraph(stringSegments: [StringSegment], width: Float, pixelSize: Float) -> ParagraphReturn {
        guard stringSegments.count > 0 else {
            return (characterGroups: [nil, nil, nil], suggestedHeight: 0)
        }
        
        if let cachedParagraph = Self.searchForParagraph((stringSegments, width, pixelSize)) {
            return cachedParagraph
        }
        
        let (string0, fontID0) = stringSegments[0]
        let attrString = NSMutableAttributedString(string: string0, attributes: fontHandles[fontID0].attributes)
        
        for (string, fontID) in stringSegments[1..<stringSegments.count] {
            attrString.append(.init(string: string, attributes: fontHandles[fontID].attributes))
        }
        
        let framesetter = CTFramesetter?(attrString as CFAttributedString)!
        let frameWidth = CGFloat(width) / CGFloat(pixelSize)
        
        let pathRect = CGRect(origin: .zero, size: .init(width: frameWidth, height: 1_000_000))
        let path = CGPath(rect: pathRect, transform: nil)
        let frame = framesetter.createFrame(0..<0, path, [:])
        
        
        
        let stringSize = frame.stringRange.endIndex
        guard stringSize > 0 else {
            return (characterGroups: [nil, nil, nil], suggestedHeight: 0)
        }
        
        var characterGroups = [CharacterGroup](capacity: fontHandles.count)
        
        for _ in 0..<3 {
            characterGroups.append((boundingRects: Array(capacity: stringSize),
                                     glyphIndices: Array(capacity: stringSize)))
        }
        
        let lines = frame.lines
        var origins = [CGPoint](unsafeUninitializedCount: lines.count)
        frame.getLineOrigins(0..<lines.count, origins: &origins)
        
        let fonts = fontHandles.map{ $0.attributes.values.first! as! UIFont }
        let frameWidthHalf = 0.5 * frameWidth
        var lastLineDescent: CGFloat?
        
        for i in 0..<lines.count {
            let line = lines[i]
            let bounds = line.getBounds(CTLineBoundsOptions())
            lastLineDescent = bounds.minY
            
            let leftAlignedOrigin = origins[i]
            let sideMargin = fma(bounds.width, -0.5, frameWidthHalf)
            let origin = CGPoint(x: leftAlignedOrigin.x + sideMargin, y: leftAlignedOrigin.y - 1_000_000)
            
            for run in line.glyphRuns {
                let font = run.attributes.values.first! as! UIFont
                let fontID = fonts.firstIndex(where: { $0 === font })!
                
                let numGlyphs       = run.glyphCount
                let positionPointer = run.positionsPtr!
                let glyphPointer    = run.glyphsPtr!
                
                let fontHandle = fontHandles[fontID]
                
                for i in 0..<numGlyphs {
                    let glyph = glyphPointer[i]
                    let glyphID = fontHandle.glyphMap[Int(glyph)]
                    guard glyphID != 65535 else { continue }
                    
                    characterGroups[fontID].glyphIndices.append(glyphID)
                    
                    let position = positionPointer[i]
                    var boundingRect = fontHandle.boundingRects[Int(glyphID)]
                    
                    let adjustedPosition = simd_float2(.init(position.x + origin.x),
                                                       .init(position.y + origin.y))
                    boundingRect.lowHalf  += adjustedPosition
                    boundingRect.highHalf += adjustedPosition
                    characterGroups[fontID].boundingRects.append(boundingRect)
                }
            }
        }
        
        let height = Float(1_000_000 - lastLineDescent! - origins.last!.y) * pixelSize
        let translation = simd_float4(-width, height, -width, height) * 0.5
        
        let output: [CharacterGroup?] = (0..<3).map { i in
            let glyphIndices = characterGroups[i].glyphIndices
            guard glyphIndices.count > 0 else { return nil }
            
            let boundingRectPointer = characterGroups[i].boundingRects.withUnsafeMutableBufferPointer{ $0.baseAddress! }
            
            for j in 0..<glyphIndices.count {
                boundingRectPointer[j] = fma(boundingRectPointer[j], pixelSize, translation)
            }
            
            return (boundingRects: characterGroups[i].boundingRects, glyphIndices: glyphIndices)
        }
        
        Self.registerParagraphReturn((stringSegments, width, pixelSize), (output, height))
        
        return (characterGroups: output, suggestedHeight: height)
    }
    
}
#endif
