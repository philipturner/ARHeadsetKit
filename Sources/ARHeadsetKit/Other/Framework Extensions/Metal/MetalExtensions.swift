//
//  MetalExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/5/21.
//

import Metal

public extension MTLDevice {
    @inlinable @inline(__always)
    func makeComputePipelineState(descriptor: MTLComputePipelineDescriptor) -> MTLComputePipelineState {
        try! makeComputePipelineState(descriptor: descriptor, options: [], reflection: nil)
    }
}

extension MTLSize: ExpressibleByIntegerLiteral, ExpressibleByArrayLiteral {
    @inlinable @inline(__always)
    public init(integerLiteral value: Int) {
        self = [ value, 1, 1 ]
    }
    
    @inlinable @inline(__always)
    public init(arrayLiteral elements: Int...) {
        switch elements.count {
        case 1:  self = MTLSizeMake(elements[0], 1, 1)
        case 2:  self = MTLSizeMake(elements[0], elements[1], 1)
        case 3:  self = MTLSizeMake(elements[0], elements[1], elements[2])
        default: fatalError("A MTLSize must not exceed three dimensions!")
        }
    }
}

extension MTLOrigin: ExpressibleByArrayLiteral {
    @inlinable @inline(__always)
    public init(arrayLiteral elements: Int...) {
        switch elements.count {
        case 2:  self = MTLOriginMake(elements[0], elements[1], 0)
        case 3:  self = MTLOriginMake(elements[0], elements[1], elements[2])
        default: fatalError("A MTLOrigin must have two or three dimensions!")
        }
    }
}

extension MTLSamplePosition: ExpressibleByArrayLiteral {
    @inlinable @inline(__always)
    public init(arrayLiteral elements: Float...) {
        switch elements.count {
        case 2:  self = .init(x: elements[0], y: elements[1])
        default: fatalError("A MTLSamplePosition must have two dimensions")
        }
    }
}

extension MTLPackedFloat3 {
    @inlinable @inline(__always) @available(iOS 15.0, macOS 12.0, *)
    public init(_ vector: simd_packed_float3) {
        self = MTLPackedFloat3Make(vector.x, vector.y, vector.z)
    }
}



public extension MTLResource {
    @inlinable @inline(__always)
    var optLabel: String! {
        get { debugLabelReturn(nil) { label } }
        set { debugLabel { label = newValue } }
    }
}

public extension MTLCommandQueue {
    @inlinable @inline(__always)
    var optLabel: String! {
        get { debugLabelReturn(nil) { label } }
        set { debugLabel { label = newValue } }
    }
    
    @inlinable
    func makeDebugCommandBuffer() -> MTLCommandBuffer {
        debugLabelConditionalReturn ({
            let descriptor = MTLCommandBufferDescriptor()
            descriptor.errorOptions = .encoderExecutionStatus
            
            let output = makeCommandBuffer(descriptor: descriptor)!
            output.addCompletedHandler{ $0.printErrors() }
            
            return output
        }, else: {
            return makeCommandBuffer()!
        })
    }
}

public extension MTLCommandBuffer {
    @inlinable @inline(__always)
    var optLabel: String! {
        get { debugLabelReturn(nil) { label } }
        set { debugLabel { label = newValue } }
    }
    
    @inlinable @inline(__always)
    func pushOptDebugGroup(_ string: String) {
        debugLabel { pushDebugGroup(string) }
    }
    
    @inlinable @inline(__always)
    func popOptDebugGroup() {
        debugLabel { popDebugGroup() }
    }
}

public extension MTLCommandEncoder {
    @inlinable @inline(__always)
    var optLabel: String! {
        get { debugLabelReturn(nil) { label } }
        set { debugLabel { label = newValue } }
    }
    
    @inlinable @inline(__always)
    func pushOptDebugGroup(_ string: String) {
        debugLabel { pushDebugGroup(string) }
    }
    
    @inlinable @inline(__always)
    func popOptDebugGroup() {
        debugLabel { popDebugGroup() }
    }
}

public extension MTLComputePipelineDescriptor {
    @inlinable @inline(__always)
    var optLabel: String! {
        get { debugLabelReturn(nil) { label } }
        set { debugLabel { label = newValue } }
    }
}

public extension MTLRenderPipelineDescriptor {
    @inlinable @inline(__always)
    var optLabel: String! {
        get { debugLabelReturn(nil) { label } }
        set { debugLabel { label = newValue } }
    }
}

public extension MTLDepthStencilDescriptor {
    @inlinable @inline(__always)
    var optLabel: String! {
        get { debugLabelReturn(nil) { label } }
        set { debugLabel { label = newValue } }
    }
}

public extension MTLRasterizationRateMapDescriptor {
    @inlinable @inline(__always)
    var optLabel: String! {
        get { debugLabelReturn(nil) { label } }
        set { debugLabel { label = newValue } }
    }
}

public extension MTLLibrary {
    @inlinable @inline(__always)
    func makeComputePipeline<T>(_ type: T.Type, name: String) -> MTLComputePipelineState {
        makeComputePipeline(type, name: name, function: makeFunction(name: name)!)
    }
    
    @inlinable
    func makeComputePipeline<T>(_ type: T.Type, name: String, function computeFunction: MTLFunction) -> MTLComputePipelineState {
        debugLabelConditionalReturn({
            let computePipelineDescriptor = MTLComputePipelineDescriptor()
            computePipelineDescriptor.computeFunction = computeFunction
            computePipelineDescriptor.label = String(describing: type) + " " + name + " Pipeline"
            
            return device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        }, else: {
            return try! device.makeComputePipelineState(function: computeFunction)
        })
    }
}

public extension MTLCommandBuffer {
    
    @inlinable @inline(__always)
    func printErrors() {
        debugLabel {
            _printErrors()
        }
    }
    
    @usableFromInline @inline(never)
    internal func _printErrors() {
        for log in logs {
            print(log.description)
            
            let encoderLabel = log.encoderLabel ?? "Unknown Label"
            print("Faulting encoder: \"\(encoderLabel)\"")
            
            guard let debugLocation = log.debugLocation,
                  let functionName = debugLocation.functionName else {
                return
            }
            
            print("Faulting function: \(functionName) (line \(debugLocation.line), column \(debugLocation.column))")
        }
        
        if let error = error as NSError?,
           let encoderInfos = error.userInfo[MTLCommandBufferEncoderInfoErrorKey] as? [MTLCommandBufferEncoderInfo] {
            print()
            
            switch status {
            case .notEnqueued: print("Status: not enqueued")
            case .enqueued:    print("Status: enqueued")
            case .committed:   print("Status: committed")
            case .scheduled:   print("Status: scheduled")
            case .completed:   print("Status: completed")
            case .error:       print("Status: error")
            @unknown default: fatalError("This status is not possible!")
            }
            
            print("Error code: \(error.code)")
            print("Description: \(error.localizedDescription)")
            
            if let reason = error.localizedFailureReason {
                print("Failure reason: \(reason)")
            }
            
            if let options = error.localizedRecoveryOptions {
                for i in 0..<options.count {
                    print("Recovery option \(i): \(options[i])")
                }
            }
            
            if let suggestion = error.localizedRecoverySuggestion {
                print("Recovery suggestion: \(suggestion)")
            }
            
            print()
            
            for info in encoderInfos {
                switch info.errorState {
                case .faulted:   print(info.label + " faulted")
                case .affected:  print(info.label + " affected")
                case .completed: print(info.label + " completed")
                case .unknown:   print(info.label + " error state unknown")
                case .pending:   print(info.label + " unknown")
                @unknown default: fatalError("This error state is not possible!")
                }
                
                for signpost in info.debugSignposts {
                    print("Signpost:", signpost)
                }
            }
            
            print()
        }
    }
    
}
