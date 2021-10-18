//
//  CoreTextExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/22/21.
//

import Foundation
import CoreText

// High-level wrappers around the entire CoreText framework

public extension Optional where Wrapped == CTFont {
    @inlinable @inline(__always)
    init<T: BinaryFloatingPoint>(_ name: String, _ size: T, _ matrix: UnsafePointer<CGAffineTransform>?, _ options: CTFontOptions? = nil) {
        if let options = options {
            self = CTFontCreateWithNameAndOptions(name as CFString, CGFloat(size), matrix, options)
        } else {
            self = CTFontCreateWithName(name as CFString, CGFloat(size), matrix)
        }
    }
    
    @inlinable @inline(__always)
    init<T: BinaryFloatingPoint>(_ descriptor: CTFontDescriptor, _ size: T, _ matrix: UnsafePointer<CGAffineTransform>?,
                                 _ options: CTFontOptions? = nil) {
        if let options = options {
            self = CTFontCreateWithFontDescriptorAndOptions(descriptor, CGFloat(size), matrix, options)
        } else {
            self = CTFontCreateWithFontDescriptor(descriptor, CGFloat(size), matrix)
        }
    }
    
    @inlinable @inline(__always)
    init<T: BinaryFloatingPoint>(_ uiType: CTFontUIFontType, _ size: T, _ language: String?) {
        self = CTFontCreateUIFontForLanguage(uiType, CGFloat(size), language as CFString?)
    }
    
    @inlinable @inline(__always)
    init(_ currentFont: CTFont, _ string: String, _ range: Range<Int>, _ language: String? = nil) {
        if let language = language {
            self = CTFontCreateForStringWithLanguage(currentFont, string as CFString, range.asCFRange, language as CFString)
        } else {
            self = CTFontCreateForString(currentFont, string as CFString, range.asCFRange)
        }
    }
    
    @inlinable @inline(__always)
    init<T: BinaryFloatingPoint>(_ graphicsFont: CGFont, _ size: T, _ matrix: UnsafePointer<CGAffineTransform>?,
                                 _ attributes: CTFontDescriptor?) {
        self = CTFontCreateWithGraphicsFont(graphicsFont, CGFloat(size), matrix, attributes)
    }
}

public extension Optional where Wrapped == CTFontDescriptor {
    @inlinable @inline(__always)
    init<T: BinaryFloatingPoint>(_ name: String, _ size: T) {
        self = CTFontDescriptorCreateWithNameAndSize(name as CFString, CGFloat(size))
    }
    
    @inlinable @inline(__always)
    init(_ attributes: [CFString : Any]) {
        self = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
    }
}

public extension Optional where Wrapped == CTLine {
    @inlinable @inline(__always)
    init(_ attrString: NSAttributedString) {
        self = CTLineCreateWithAttributedString(attrString as CFAttributedString)
    }
}

public extension Optional where Wrapped == CTParagraphStyle {
    @inlinable @inline(__always)
    init(_ settings: UnsafePointer<CTParagraphStyleSetting>?, _ settingCount: Int) {
        self = CTParagraphStyleCreate(settings, settingCount)
    }
}

public extension Optional where Wrapped == CTFontCollection {
    @inlinable @inline(__always)
    init(_ options: [CFString : Any]) {
        self = CTFontCollectionCreateFromAvailableFonts(options as CFDictionary)
    }
    
    @inlinable @inline(__always)
    init(_ queryDescriptors: [CTFontDescriptor]?, _ options: [CFString : Any]) {
        self = CTFontCollectionCreateWithFontDescriptors(queryDescriptors as CFArray?, options as CFDictionary)
    }
}

public extension Optional where Wrapped == CTRubyAnnotation {
    @inlinable @inline(__always)
    init<T: BinaryFloatingPoint>(_ alignment: CTRubyAlignment, _ overhang: CTRubyOverhang, _ sizeFactor: T,
                                 _ text: UnsafeMutablePointer<Unmanaged<CFString>?>) {
        self = CTRubyAnnotationCreate(alignment, overhang, CGFloat(sizeFactor), text)
    }
    
    @inlinable @inline(__always)
    init(_ alignment: CTRubyAlignment, _ overhang: CTRubyOverhang, _ position: CTRubyPosition,
         _ string: String, _ attributes: [CFString : Any]) {
        self = CTRubyAnnotationCreateWithAttributes(alignment, overhang, position, string as CFString, attributes as CFDictionary)
    }
}

public extension Optional where Wrapped == CTTypesetter {
    @inlinable @inline(__always)
    init(_ string: NSAttributedString) {
        self = CTTypesetterCreateWithAttributedString(string as CFAttributedString)
    }
    
    @inlinable @inline(__always)
    init(_ string: NSAttributedString, _ options: [CFString : Any]) {
        self = CTTypesetterCreateWithAttributedStringAndOptions(string as CFAttributedString, options as CFDictionary)
    }
}

public extension Optional where Wrapped == CTGlyphInfo {
    @inlinable @inline(__always)
    init(_ glyphName: String, _ font: CTFont, _ baseString: String) {
        self = CTGlyphInfoCreateWithGlyphName(glyphName as CFString, font, baseString as CFString)
    }
    
    @inlinable @inline(__always)
    init(_ glyph: CGGlyph, _ font: CTFont, _ baseString: String) {
        self = CTGlyphInfoCreateWithGlyph(glyph, font, baseString as CFString)
    }
    
    @inlinable @inline(__always)
    init(_ cid: CGFontIndex, _ collection: CTCharacterCollection, _ baseString: CFString) {
        self = CTGlyphInfoCreateWithCharacterIdentifier(cid, collection, baseString as CFString)
    }
}

public extension Optional where Wrapped == CTFramesetter {
    @inlinable @inline(__always)
    init(_ typesetter: CTTypesetter) {
        self = CTFramesetterCreateWithTypesetter(typesetter)
    }
    
    @inlinable @inline(__always)
    init(_ attrString: NSAttributedString) {
        self = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
    }
}

public extension Optional where Wrapped == CTRunDelegate {
    @inlinable @inline(__always)
    init(_ callbacks: UnsafePointer<CTRunDelegateCallbacks>, _ refCon: UnsafeMutableRawPointer?) {
        self = CTRunDelegateCreate(callbacks, refCon)
    }
}

public extension Optional where Wrapped == CTTextTab {
    @inlinable @inline(__always)
    init<T: BinaryFloatingPoint>(_ alignment: CTTextAlignment, _ location: T, _ options: [CFString : Any]?) {
        self = CTTextTabCreate(alignment, Double(location), options as CFDictionary?)
    }
}



public extension CTFont {
    @inlinable @inline(__always)
    func createCopy<T: BinaryFloatingPoint>(_ size: T, _ matrix: UnsafePointer<CGAffineTransform>?,
                                            _ attributes: CTFontDescriptor?) -> CTFont {
        CTFontCreateCopyWithAttributes(self, CGFloat(size), matrix, attributes)
    }
    
    @inlinable @inline(__always)
    func createCopy<T: BinaryFloatingPoint>(_ size: T, _ matrix: UnsafePointer<CGAffineTransform>?,
                                            _ symTraitValue: CTFontSymbolicTraits, _ symTraitMask: CTFontSymbolicTraits) -> CTFont? {
        CTFontCreateCopyWithSymbolicTraits(self, CGFloat(size), matrix, symTraitValue, symTraitMask)
    }
    
    @inlinable @inline(__always)
    func createCopy<T: BinaryFloatingPoint>(_ size: T, _ matrix: UnsafePointer<CGAffineTransform>?, _ family: String) -> CTFont? {
        CTFontCreateCopyWithFamily(self, CGFloat(size), matrix, family as CFString)
    }
    
    @inlinable @inline(__always)
    var fontDescriptor: CTFontDescriptor { CTFontCopyFontDescriptor(self) }
    
    @inlinable @inline(__always)
    func copyAttribute(_ attribute: CFString) -> CFTypeRef? {
        CTFontCopyAttribute(self, attribute as CFString)
    }
    
    @inlinable @inline(__always) var size: CGFloat { CTFontGetSize(self) }
    @inlinable @inline(__always) var matrix: CGAffineTransform { CTFontGetMatrix(self) }
    @inlinable @inline(__always) var symbolicTraits: CTFontSymbolicTraits { CTFontGetSymbolicTraits(self) }
    @inlinable @inline(__always) var traits: [CFString : Any] { CTFontCopyTraits(self) as! Dictionary }
    
    @inlinable @inline(__always) var postScriptName: String { CTFontCopyPostScriptName(self) as String }
    @inlinable @inline(__always) var familyName: String { CTFontCopyFamilyName(self) as String }
    @inlinable @inline(__always) var fullName: String { CTFontCopyFullName(self) as String }
    @inlinable @inline(__always) var displayName: String { CTFontCopyDisplayName(self) as String }
    
    @inlinable @inline(__always)
    func copyName(_ nameKey: String) -> String? {
        CTFontCopyName(self, nameKey as CFString) as String?
    }
    
    @inlinable @inline(__always)
    func copyLocalizedName(_ nameKey: String, _ actualLanguage: UnsafeMutablePointer<Unmanaged<CFString>?>?) -> String? {
        CTFontCopyLocalizedName(self, nameKey as CFString, actualLanguage) as String?
    }
    
    @inlinable @inline(__always) var characterSet: CFCharacterSet { CTFontCopyCharacterSet(self) }
    @inlinable @inline(__always) var stringEncoding: CFStringEncoding { CTFontGetStringEncoding(self) }
    @inlinable @inline(__always) var supportedLanguages: [String] { CTFontCopySupportedLanguages(self) as! Array }
    
    @inlinable @inline(__always)
    func getGlyphs(_ characters: UnsafePointer<UniChar>, _ glyphs: UnsafeMutablePointer<CGGlyph>, _ count: Int) -> Bool {
        CTFontGetGlyphsForCharacters(self, characters, glyphs, count)
    }
    
    @inlinable @inline(__always) var ascent: CGFloat { CTFontGetAscent(self) }
    @inlinable @inline(__always) var descent: CGFloat { CTFontGetDescent(self) }
    @inlinable @inline(__always) var leading: CGFloat { CTFontGetLeading(self) }
    @inlinable @inline(__always) var unitsPerEm: UInt32 { CTFontGetUnitsPerEm(self) }
    @inlinable @inline(__always) var glyphCount: Int { CTFontGetGlyphCount(self) }
    
    @inlinable @inline(__always) var boundingBox: CGRect { CTFontGetBoundingBox(self) }
    @inlinable @inline(__always) var underlinePosition: CGFloat { CTFontGetUnderlinePosition(self) }
    @inlinable @inline(__always) var underlineThickness: CGFloat { CTFontGetUnderlineThickness(self) }
    @inlinable @inline(__always) var slantAngle: CGFloat { CTFontGetSlantAngle(self) }
    @inlinable @inline(__always) var capHeight: CGFloat { CTFontGetCapHeight(self) }
    @inlinable @inline(__always) var xHeight: CGFloat { CTFontGetXHeight(self) }
    
    @inlinable @inline(__always) func getGlyph(_ glyphName: String) -> CGGlyph { CTFontGetGlyphWithName(self, glyphName as CFString) }
    @inlinable @inline(__always) func getName(_ glyph: CGGlyph) -> String? { CTFontCopyNameForGlyph(self, glyph) as String? }
    
    @inlinable @inline(__always)
    func getBoundingRects(_ orientation: CTFontOrientation, _ glyphs: UnsafePointer<CGGlyph>,
                          _ boundingRects: UnsafeMutablePointer<CGRect>?, _ count: Int) -> CGRect {
        CTFontGetBoundingRectsForGlyphs(self, orientation, glyphs, boundingRects, count)
    }
    
    @inlinable @inline(__always)
    func getOpticalBounds(_ glyphs: UnsafePointer<CGGlyph>, _ boundingRects: UnsafeMutablePointer<CGRect>?,
                          _ count: Int, _ options: CFOptionFlags) -> CGRect {
        CTFontGetOpticalBoundsForGlyphs(self, glyphs, boundingRects, count, options)
    }
    
    @inlinable @inline(__always)
    func getAdvances(_ orientation: CTFontOrientation, _ glyphs: UnsafePointer<CGGlyph>,
                     _ advances: UnsafeMutablePointer<CGSize>?, _ count: Int) -> Double {
        CTFontGetAdvancesForGlyphs(self, orientation, glyphs, advances, count)
    }
    
    @inlinable @inline(__always)
    func getVerticalTranslations(_ glyphs: UnsafePointer<CGGlyph>, _ translations: UnsafeMutablePointer<CGSize>, _ count: Int) {
        CTFontGetVerticalTranslationsForGlyphs(self, glyphs, translations, count)
    }
    
    @inlinable @inline(__always)
    func createPath(_ glyph: CGGlyph, _ matrix: UnsafePointer<CGAffineTransform>?) -> CGPath? {
        CTFontCreatePathForGlyph(self, glyph, matrix)
    }
    
    @inlinable @inline(__always) var variationAxes: [[CFString : Any]] { CTFontCopyVariationAxes(self) as! Array }
    @inlinable @inline(__always) var variation: [CFString : Any] { CTFontCopyVariation(self) as! Dictionary }
    @inlinable @inline(__always) var features: [[CFString : Any]] { CTFontCopyFeatures(self) as! Array }
    @inlinable @inline(__always) var featureSettings: [[CFString : Any ]] { CTFontCopyFeatureSettings(self) as! Array }
    
    @inlinable @inline(__always)
    func copyGraphicsFont(_ attributes: UnsafeMutablePointer<Unmanaged<CTFontDescriptor>?>?) -> CGFont {
        CTFontCopyGraphicsFont(self, attributes)
    }
    
    @inlinable @inline(__always)
    func copyAvailableTables(_ options: CTFontTableOptions) -> [CTFontTableTag]? {
        CTFontCopyAvailableTables(self, options) as! Array?
    }
    
    @inlinable @inline(__always)
    func copyTable(_ table: CTFontTableTag, _ options: CTFontTableOptions) -> Data? {
        CTFontCopyTable(self, table, options) as Data?
    }
    
    @inlinable @inline(__always)
    func drawGlyphs(_ glyphs: UnsafePointer<CGGlyph>, _ positions: UnsafePointer<CGPoint>, _ count: Int, _ context: CGContext) {
        CTFontDrawGlyphs(self, glyphs, positions, count, context)
    }
    
    @inlinable @inline(__always)
    func getLigatureCaretPositions(_ glyph: CGGlyph, _ positions: UnsafeMutablePointer<CGFloat>?, _ maxPositions: Int) -> Int {
        CTFontGetLigatureCaretPositions(self, glyph, positions, maxPositions)
    }
    
    @inlinable @inline(__always)
    func copyDefaultCascadeList(_ languagePrefList: [String]?) -> [CTFontDescriptor]? {
        CTFontCopyDefaultCascadeListForLanguages(self, languagePrefList as CFArray?) as! Array?
    }
}

public extension CTFontDescriptor {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTFontDescriptorGetTypeID() }
    
    @inlinable @inline(__always)
    func createCopy(_ attributes: [CFString : Any]) -> CTFontDescriptor {
        CTFontDescriptorCreateCopyWithAttributes(self, attributes as CFDictionary)
    }
    
    @inlinable @inline(__always)
    func createCopy(_ family: String) -> CTFontDescriptor? {
        CTFontDescriptorCreateCopyWithFamily(self, family as CFString)
    }
    
    @inlinable @inline(__always)
    func createCopy(_ symTraitValue: CTFontSymbolicTraits, _ symTraitMask: CTFontSymbolicTraits) -> CTFontDescriptor? {
        CTFontDescriptorCreateCopyWithSymbolicTraits(self, symTraitValue, symTraitMask)
    }
    
    @inlinable @inline(__always)
    func createCopy<T: BinaryFloatingPoint>(_ variationIdentifier: CFNumber, _ variationValue: T) -> CTFontDescriptor {
        CTFontDescriptorCreateCopyWithVariation(self, variationIdentifier, CGFloat(variationValue))
    }
    
    @inlinable @inline(__always)
    func createCopy(_ featureTypeIdentifier: CFNumber, _ featureSelectorIdentifier: CFNumber) -> CTFontDescriptor {
        CTFontDescriptorCreateCopyWithFeature(self, featureTypeIdentifier, featureSelectorIdentifier)
    }
    
    @inlinable @inline(__always)
    func createMatchingFontDescriptors(_ mandatoryAttributes: Set<CFString>?) -> [CTFontDescriptor]? {
        CTFontDescriptorCreateMatchingFontDescriptors(self, mandatoryAttributes as CFSet?) as! Array?
    }
    
    @inlinable @inline(__always)
    func createMatchingFontDescriptor(_ mandatoryAttributes: Set<CFString>?) -> CTFontDescriptor? {
        CTFontDescriptorCreateMatchingFontDescriptor(self, mandatoryAttributes as CFSet?)
    }
    
    @inlinable @inline(__always)
    static func matchFontDescriptors(_ descriptors: [CTFontDescriptor], _ mandatoryAttributes: Set<CFString>?,
                                     _ progressBlock: @escaping CTFontDescriptorProgressHandler) -> Bool {
        CTFontDescriptorMatchFontDescriptorsWithProgressHandler(descriptors as CFArray, mandatoryAttributes as CFSet?, progressBlock)
    }
    
    @inlinable @inline(__always)
    var attributes: [CFString : Any] { CTFontDescriptorCopyAttributes(self) as! Dictionary }
    
    @inlinable @inline(__always)
    func copyAttribute(_ attribute: CFString) -> CFTypeRef? {
        CTFontDescriptorCopyAttribute(self, attribute)
    }
    
    @inlinable @inline(__always)
    func copyLocalizedAttribute(_ attribute: CFString, _ language: UnsafeMutablePointer<Unmanaged<CFString>?>?) -> CFTypeRef? {
        CTFontDescriptorCopyLocalizedAttribute(self, attribute, language)
    }
}

public enum CTFontManager {
    @inlinable @inline(__always)
    public static var availablePostScriptNames: [String] { CTFontManagerCopyAvailablePostScriptNames() as! Array }
    @inlinable @inline(__always)
    public static var availableFontFamilyNames: [String] { CTFontManagerCopyAvailableFontFamilyNames() as! Array }
    
    @inlinable @inline(__always)
    public static func createFontDescriptors(_ fileURL: URL) -> [CTFontDescriptor]? {
        CTFontManagerCreateFontDescriptorsFromURL(fileURL as CFURL) as! Array?
    }
    
    @inlinable @inline(__always)
    public static func createFontDescriptor(_ data: Data) -> CTFontDescriptor? {
        CTFontManagerCreateFontDescriptorFromData(data as CFData)
    }
    
    @inlinable @inline(__always)
    public static func createFontDescriptors(_ data: Data) -> [CTFontDescriptor] {
        CTFontManagerCreateFontDescriptorsFromData(data as CFData) as! Array
    }
    
    @inlinable @inline(__always)
    public static func registerFonts(_ fontURL: URL, _ scope: CTFontManagerScope, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool {
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, scope, error)
    }
    
    @inlinable @inline(__always)
    public static func unregisterFonts(_ fontURL: URL, _ scope: CTFontManagerScope, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool {
        CTFontManagerUnregisterFontsForURL(fontURL as CFURL, scope, error)
    }
    
    @inlinable @inline(__always)
    public static func registerGraphicsFont(_ font: CGFont, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool {
        CTFontManagerRegisterGraphicsFont(font, error)
    }
    
    @inlinable @inline(__always)
    public static func unregisterGraphicsFont(_ font: CGFont, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Bool {
        CTFontManagerUnregisterGraphicsFont(font, error)
    }
    
    @inlinable @inline(__always)
    public static func registerFontURLs(_ fontURLs: [URL], _ scope: CTFontManagerScope, _ enabled: Bool,
                                        _ registrationHandler: ((CFArray, Bool) -> Bool)?) {
        CTFontManagerRegisterFontURLs(fontURLs as CFArray, scope, enabled, registrationHandler)
    }
    
    @inlinable @inline(__always)
    public static func unregisterFontURLs(_ fontURLs: [URL], _ scope: CTFontManagerScope, _ registrationHandler: ((CFArray, Bool) -> Bool)?) {
        CTFontManagerUnregisterFontURLs(fontURLs as CFArray, scope, registrationHandler)
    }
    
    @inlinable @inline(__always)
    public static func registerFontDescriptors(_ fontDescriptors: [CTFontDescriptor], _ scope: CTFontManagerScope, _ enabled: Bool,
                                               _ registrationHandler: ((CFArray, Bool) -> Bool)?) {
        CTFontManagerRegisterFontDescriptors(fontDescriptors as CFArray, scope, enabled, registrationHandler)
    }
    
    @inlinable @inline(__always)
    public static func unregisterFontDescriptors(_ fontDescriptors: [CTFontDescriptor], _ scope: CTFontManagerScope,
                                                 _ registrationHandler: ((CFArray, Bool) -> Bool)?) {
        CTFontManagerUnregisterFontDescriptors(fontDescriptors as CFArray, scope, registrationHandler)
    }
    
    #if os(iOS)
    @inlinable @inline(__always)
    public static func registerFonts(_ fontAssetNames: [String], _ bundle: CFBundle?, _ scope: CTFontManagerScope, _ enabled: Bool,
                                     _ registrationHandler: ((CFArray, Bool) -> Bool)?) {
        CTFontManagerRegisterFontsWithAssetNames(fontAssetNames as CFArray, bundle, scope, enabled, registrationHandler)
    }
    
    @inlinable @inline(__always)
    public static func registeredFontDescriptors(_ scope: CTFontManagerScope, _ enabled: Bool) -> [CTFontDescriptor] {
        CTFontManagerCopyRegisteredFontDescriptors(scope, enabled) as! Array
    }
    
    @inlinable @inline(__always)
    public static func requestFonts(_ fontDescriptors: [CTFontDescriptor], _ completionHandler: @escaping (CFArray) -> Void) {
        CTFontManagerRequestFonts(fontDescriptors as CFArray, completionHandler)
    }
    #endif
}

public extension CTFrame {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTFrameGetTypeID() }
    
    @inlinable @inline(__always) var stringRange: Range<Int> { .init(CTFrameGetStringRange(self)) }
    @inlinable @inline(__always) var visibleStringRange: Range<Int> { .init(CTFrameGetVisibleStringRange(self)) }
    @inlinable @inline(__always) var path: CGPath { CTFrameGetPath(self) }
    @inlinable @inline(__always) var attributes: [CFString : Any] { CTFrameGetFrameAttributes(self) as! Dictionary }
    @inlinable @inline(__always) var lines: [CTLine] { CTFrameGetLines(self) as! Array }
    
    @inlinable @inline(__always)
    func getLineOrigins(_ range: Range<Int>, origins: UnsafeMutablePointer<CGPoint>) {
        CTFrameGetLineOrigins(self, range.asCFRange, origins)
    }
    
    @inlinable @inline(__always)
    func draw(_ context: CGContext) {
        CTFrameDraw(self, context)
    }
}

public extension CTLine {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTLineGetTypeID() }
    
    @inlinable @inline(__always)
    func createTruncatedLine<T: BinaryFloatingPoint>(_ width: T, _ truncationType: CTLineTruncationType,
                                                     _ truncationToken: CTLine?) -> CTLine? {
        CTLineCreateTruncatedLine(self, Double(width), truncationType, truncationToken)
    }
    
    @inlinable @inline(__always)
    func createJustifiedLine<S: BinaryFloatingPoint, T: BinaryFloatingPoint>(_ justificationFactor: S, _ justificationWidth: T) -> CTLine? {
        CTLineCreateJustifiedLine(self, CGFloat(justificationFactor), Double(justificationWidth))
    }
    
    @inlinable @inline(__always) var glyphCount: Int { CTLineGetGlyphCount(self) }
    @inlinable @inline(__always) var glyphRuns: [CTRun] { CTLineGetGlyphRuns(self) as! Array }
    @inlinable @inline(__always) var stringRange: Range<Int> { .init(CTLineGetStringRange(self)) }
    
    @inlinable @inline(__always)
    func getPenOffset<S: BinaryFloatingPoint, T: BinaryFloatingPoint>(_ flushFactor: S, _ flushWidth: T) -> Double {
        CTLineGetPenOffsetForFlush(self, CGFloat(flushFactor), Double(flushWidth))
    }
    
    @inlinable @inline(__always)
    func draw(_ context: CGContext) {
        CTLineDraw(self, context)
    }
    
    @inlinable @inline(__always)
    func getTypographicBounds(_ ascent: UnsafeMutablePointer<CGFloat>?, _ descent: UnsafeMutablePointer<CGFloat>?,
                              _ leading: UnsafeMutablePointer<CGFloat>?) -> Double {
        CTLineGetTypographicBounds(self, ascent, descent, leading)
    }
    
    @inlinable @inline(__always)
    func getBounds(_ options: CTLineBoundsOptions) -> CGRect {
        CTLineGetBoundsWithOptions(self, options)
    }
    
    @inlinable @inline(__always)
    var trailingWhitespaceWidth: Double { CTLineGetTrailingWhitespaceWidth(self) }
    
    @inlinable @inline(__always)
    func getImageBounds(_ context: CGContext?) -> CGRect {
        CTLineGetImageBounds(self, context)
    }
    
    @inlinable @inline(__always)
    func getStringIndex(_ position: CGPoint) -> Int {
        CTLineGetStringIndexForPosition(self, position)
    }
    
    @inlinable @inline(__always)
    func getOffset(_ charIndex: Int, _ secondaryOffset: UnsafeMutablePointer<CGFloat>?) -> CGFloat {
        CTLineGetOffsetForStringIndex(self, charIndex, secondaryOffset)
    }
    
    @inlinable @inline(__always)
    func enumerateCaretOffsets(_ closure: @escaping (Double, Int, Bool, UnsafeMutablePointer<Bool>) -> Void) {
        CTLineEnumerateCaretOffsets(self, closure)
    }
}

public extension CTRun {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTRunGetTypeID() }
    
    @inlinable @inline(__always) var glyphCount: Int { CTRunGetGlyphCount(self) }
    @inlinable @inline(__always) var attributes: [CFString : Any] { CTRunGetAttributes(self) as! Dictionary }
    @inlinable @inline(__always) var status: CTRunStatus { CTRunGetStatus(self) }
    
    @inlinable @inline(__always) var glyphsPtr: UnsafePointer<CGGlyph>? { CTRunGetGlyphsPtr(self) }
    @inlinable @inline(__always) var positionsPtr: UnsafePointer<CGPoint>? { CTRunGetPositionsPtr(self) }
    @inlinable @inline(__always) var advancesPointer: UnsafePointer<CGSize>? { CTRunGetAdvancesPtr(self) }
    @inlinable @inline(__always) var stringIndicesPtr: UnsafePointer<Int>? { CTRunGetStringIndicesPtr(self) }
    
    @inlinable @inline(__always)
    func getGlyphs(_ range: Range<Int>, _ buffer: UnsafeMutablePointer<CGGlyph>) {
        CTRunGetGlyphs(self, range.asCFRange, buffer)
    }
    
    @inlinable @inline(__always)
    func getPositions(_ range: Range<Int>, _ buffer: UnsafeMutablePointer<CGPoint>) {
        CTRunGetPositions(self, range.asCFRange, buffer)
    }
    
    @inlinable @inline(__always)
    func getAdvances(_ range: Range<Int>, _ buffer: UnsafeMutablePointer<CGSize>) {
        CTRunGetAdvances(self, range.asCFRange, buffer)
    }
    
    @inlinable @inline(__always)
    func getStringIndices(_ range: Range<Int>, _ buffer: UnsafeMutablePointer<Int>) {
        CTRunGetStringIndices(self, range.asCFRange, buffer)
    }
    
    @inlinable @inline(__always)
    var stringRange: Range<Int> { .init(CTRunGetStringRange(self)) }
    
    @inlinable @inline(__always)
    func getTypographicBounds(_ range: Range<Int>, _ ascent: UnsafeMutablePointer<CGFloat>?,
                              _ descent: UnsafeMutablePointer<CGFloat>?, _ leading: UnsafeMutablePointer<CGFloat>?) -> Double {
        CTRunGetTypographicBounds(self, range.asCFRange, ascent, descent, leading)
    }
    
    @inlinable @inline(__always)
    func getImageBounds(_ context: CGContext?, _ range: CFRange) -> CGRect {
        CTRunGetImageBounds(self, context, range)
    }
    
    @inlinable @inline(__always)
    var textMatrix: CGAffineTransform { CTRunGetTextMatrix(self) }
    
    @inlinable @inline(__always)
    func getBaseAdvancesAndOrigins(_ range: Range<Int>, _ advancesBuffer: UnsafeMutablePointer<CGSize>?,
                                   _ originsBuffer: UnsafeMutablePointer<CGPoint>?) {
        CTRunGetBaseAdvancesAndOrigins(self, range.asCFRange, advancesBuffer, originsBuffer)
    }
    
    @inlinable @inline(__always)
    func draw(_ context: CGContext, _ range: Range<Int>) {
        CTRunDraw(self, context, range.asCFRange)
    }
}

public extension CTParagraphStyle {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTParagraphStyleGetTypeID() }
    
    @inlinable @inline(__always)
    var copy: CTParagraphStyle { CTParagraphStyleCreateCopy(self) }
    
    @inlinable @inline(__always)
    func getValue(_ spec: CTParagraphStyleSpecifier, _ valueBufferSize: Int, _ valueBuffer: UnsafeMutableRawPointer) -> Bool {
        CTParagraphStyleGetValueForSpecifier(self, spec, valueBufferSize, valueBuffer)
    }
}

public extension CTFontCollection {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTFontCollectionGetTypeID() }
    
    @inlinable @inline(__always)
    func createCopy(_ queryDescriptors: [CTFontDescriptor]?, _ options: [CFString : Any]) -> CTFontCollection {
        CTFontCollectionCreateCopyWithFontDescriptors(self, queryDescriptors as CFArray?, options as CFDictionary)
    }
    
    @inlinable @inline(__always)
    var matchingFontDescriptors: [CTFontDescriptor]? { CTFontCollectionCreateMatchingFontDescriptors(self) as! Array? }
    
    @inlinable @inline(__always)
    func createMatchingFontDescriptors(_ sortCallback: CTFontCollectionSortDescriptorsCallback?,
                                       _ refCon: UnsafeMutableRawPointer?) -> [CTFontCollection]? {
        CTFontCollectionCreateMatchingFontDescriptorsSortedWithCallback(self, sortCallback, refCon) as! Array?
    }
    
    @inlinable @inline(__always)
    func createMatchingFontDescriptors(_ options: [CFString : Any]) -> [CTFontDescriptor]? {
        CTFontCollectionCreateMatchingFontDescriptorsWithOptions(self, options as CFDictionary) as! Array?
    }
}

public extension CTRubyAnnotation {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTRubyAnnotationGetTypeID() }
    
    @inlinable @inline(__always) var copy: CTRubyAnnotation { CTRubyAnnotationCreateCopy(self) }
    @inlinable @inline(__always) var alignment: CTRubyAlignment { CTRubyAnnotationGetAlignment(self) }
    @inlinable @inline(__always) var overhang: CTRubyOverhang { CTRubyAnnotationGetOverhang(self) }
    @inlinable @inline(__always) var sizeFactor: CGFloat { CTRubyAnnotationGetSizeFactor(self) }
    
    @inlinable @inline(__always)
    func getText(_ position: CTRubyPosition) -> String? {
        CTRubyAnnotationGetTextForPosition(self, position) as String?
    }
}

public extension CTTypesetter {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTTypesetterGetTypeID() }
    
    @inlinable @inline(__always)
    func createLine<T: BinaryFloatingPoint>(_ stringRange: Range<Int>, _ offset: T? = nil) -> CTLine {
        if let offset = offset {
            return CTTypesetterCreateLineWithOffset(self, stringRange.asCFRange, Double(offset))
        } else {
            return CTTypesetterCreateLine(self, stringRange.asCFRange)
        }
    }
    
    @inlinable @inline(__always)
    func suggestLineBreak<S: BinaryFloatingPoint, T: BinaryFloatingPoint>(_ startIndex: Int, _ width: S, _ offset: T? = nil) -> Int {
        if let offset = offset {
            return CTTypesetterSuggestLineBreakWithOffset(self, startIndex, Double(width), Double(offset))
        } else {
            return CTTypesetterSuggestLineBreak(self, startIndex, Double(width))
        }
    }
    
    @inlinable @inline(__always)
    func suggestClusterBreak<S: BinaryFloatingPoint, T: BinaryFloatingPoint>(_ startIndex: Int, _ width: S, _ offset: T? = nil) -> Int {
        if let offset = offset {
            return CTTypesetterSuggestClusterBreakWithOffset(self, startIndex, Double(width), Double(offset))
        } else {
            return CTTypesetterSuggestClusterBreak(self, startIndex, Double(width))
        }
    }
}

public extension CTGlyphInfo {
    @inlinable @inline(__always)
    static var typeID: CFTypeID {CTGlyphInfoGetTypeID() }
    
    @inlinable @inline(__always) var name: String? { CTGlyphInfoGetGlyphName(self) as String? }
    @inlinable @inline(__always) var glyph: CGGlyph { CTGlyphInfoGetGlyph(self) }
    @inlinable @inline(__always) var characterIdentifier: CGFontIndex { CTGlyphInfoGetCharacterIdentifier(self) }
    @inlinable @inline(__always) var characterCollection: CTCharacterCollection { CTGlyphInfoGetCharacterCollection(self) }
}

public extension CTFramesetter {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTFramesetterGetTypeID() }
    
    @inlinable @inline(__always)
    func createFrame(_ stringRange: Range<Int>, _ path: CGPath, _ frameAttributes: [CFString : Any]) -> CTFrame {
        CTFramesetterCreateFrame(self, stringRange.asCFRange, path, frameAttributes as CFDictionary)
    }
    
    @inlinable @inline(__always)
    var typesetter: CTTypesetter { CTFramesetterGetTypesetter(self) }
    
    @inlinable @inline(__always)
    func suggestFrameSize(_ stringRange: Range<Int>, _ frameAttributes: [CFString : Any]?, _ constraints: CGSize,
                          _ fitRange: UnsafeMutablePointer<CFRange>?) -> CGSize {
        CTFramesetterSuggestFrameSizeWithConstraints(self, stringRange.asCFRange, frameAttributes as CFDictionary?, constraints, fitRange)
    }
}

public extension CTRunDelegate {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTRunDelegateGetTypeID() }
    
    @inlinable @inline(__always)
    var refCon: UnsafeMutableRawPointer { CTRunDelegateGetRefCon(self) }
}

public extension CTTextTab {
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CTTextTabGetTypeID() }
    
    @inlinable @inline(__always) var alignment: CTTextAlignment { CTTextTabGetAlignment(self) }
    @inlinable @inline(__always) var location: Double { CTTextTabGetLocation(self) }
    @inlinable @inline(__always) var options: [CFString : Any] { CTTextTabGetOptions(self) as! Dictionary }
}
