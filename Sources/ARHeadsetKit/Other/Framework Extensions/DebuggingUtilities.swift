//
//  DebuggingUtilities.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/21/21.
//

import Foundation

@usableFromInline internal let _doingDebugLabels = true
@usableFromInline internal let _bypassingMetalAPIValidation = false

@inlinable @inline(__always)
public func debugLabel(_ closure: (() -> Void)) {
    #if DEBUG
    if _doingDebugLabels {
        closure()
    }
    #endif
}

@inlinable @inline(__always)
public func debugLabelReturn<T>(_ defaultOutput: T, _ closure: (() -> T)) -> T {
    #if DEBUG
    if _doingDebugLabels {
        return closure()
    } else {
        return defaultOutput
    }
    #else
    return defaultOutput
    #endif
}

@inlinable @inline(__always)
public func debugLabelConditionalReturn<T>(_ closure1: (() -> T), else closure2: (() -> T)) -> T {
    #if DEBUG
    if _doingDebugLabels {
        return closure1()
    } else {
        return closure2()
    }
    #else
    return closure2()
    #endif
}
