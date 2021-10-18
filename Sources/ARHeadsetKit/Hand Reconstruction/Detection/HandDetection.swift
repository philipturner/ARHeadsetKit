//
//  HandDetection.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/15/21.
//

import Metal
import Vision

extension HandRenderer {
    
    struct HandDetectionResults {
        private(set) var optionStorage: UInt8
        var color: simd_half3 = .init(repeating: 0)
        
        var isDetected: Bool {
            get { optionStorage & 1 != 0 }
            set {
                if newValue {
                    optionStorage |= 1
                } else {
                    optionStorage &= 0b1111_1110
                }
            }
        }
        
        var isFlat: Bool { optionStorage & 2 != 0 }
        
        var isSmall: Bool { optionStorage & 12 != 0 }
        var xAxisIsSmall: Bool { optionStorage & 4 != 0 }
        var yAxisIsSmall: Bool { optionStorage & 8 != 0 }
        
        var isCloseToEdge: Bool { optionStorage & 48 != 0 }
        var xAxisIsCloseToEdge: Bool { optionStorage & 16 != 0 }
        var yAxisIsCloseToEdge: Bool { optionStorage & 32 != 0 }
        
        var visionReturnedHand: Bool { optionStorage & 64 != 0 }
        
        init() {
            optionStorage = 0
        }
        
        init(observation: [simd_float2], aspectRatio: Float) {
            var extremaCoords = simd_float4(lowHalf: [1, 1], highHalf: [0, 0])
            
            for point in observation {
                let minMask = point .<= extremaCoords.lowHalf
                let maxMask = point .>= extremaCoords.highHalf
                
                if any(minMask) {
                    if minMask[0] { extremaCoords.lowHalf.x = point.x }
                    if minMask[1] { extremaCoords.lowHalf.y = point.y }
                }
                
                if any(maxMask) {
                    if maxMask[0] { extremaCoords.highHalf.x = point.x }
                    if maxMask[1] { extremaCoords.highHalf.y = point.y }
                }
            }
            
            let boundingBoxSize = extremaCoords.highHalf - extremaCoords.lowHalf
            let axesAreSmall = boundingBoxSize .< [0.075, 0.1]
            
            let axesAreCloseToEdge = extremaCoords.lowHalf  .< [0.06, 0.08]
                                  .| extremaCoords.highHalf .> [0.94, 0.92]
            
            let flatness = getFlatness(observation.map{ $0 * .init(aspectRatio, 1) })
            
            optionStorage = 65
            
            if flatness > (any(axesAreCloseToEdge) ? 0.48 : 0.50) { optionStorage |= 2 }
            
            if axesAreSmall[0] { optionStorage |= 4 }
            if axesAreSmall[1] { optionStorage |= 8 }
            
            if axesAreCloseToEdge[0] { optionStorage |= 16 }
            if axesAreCloseToEdge[1] { optionStorage |= 32 }
        }
    }
    
    func locateHand(_ videoFrame: CVPixelBuffer) {
        guard let colorTextureY = colorTextureY,
              let colorTextureCbCr = colorTextureCbCr,
              let sceneDepthTexture = sceneDepthTexture,
              let segmentationTexture = segmentationTexture else
        {
            pendingLocationReturn = { [unowned self] in
                detectionResults = HandDetectionResults()
                
                rawPositions = nil
                filteredPositions = nil
                handCenter = nil
            }
            
            currentlyDetectingHand = false
            return
        }
        
        let handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest.maximumHandCount = 1
        handPoseRequest.preferBackgroundProcessing = true
        
        let handler = VNImageRequestHandler(cvPixelBuffer: videoFrame)
        
        DispatchQueue.global(qos: .default).async { [unowned self] in
            try! handler.perform([ handPoseRequest ])
            
            guard let observation = handPoseRequest.observations.first else {
                pendingLocationReturn = { [unowned self] in
                    detectionResults = HandDetectionResults()
                    
                    rawPositions = nil
                    filteredPositions = nil
                    handCenter = nil
                }
                
                currentlyDetectingHand = false
                return
            }
            
            
            
            var results = HandDetectionResults(observation: observation, aspectRatio: renderer.cameraMeasurements.aspectRatio)
            
            if results.optionStorage & 14 != 0 {
                results.isDetected = false
                
                pendingLocationReturn = { [unowned self] in
                    detectionResults = results
                    
                    rawPositions = observation
                    filteredPositions = nil
                    handCenter = nil
                }
                
                currentlyDetectingHand = false
                return
            }
            
            
            
            func getJointPositions(_ index: Int) -> simd_float4x3 {
                let startIndex = index << 2 + 1
                let columns = (startIndex..<startIndex + 4).map { simd_make_float3_undef(observation[$0]) }
                
                return simd_float4x3(columns)
            }
            
            let computeUniformPointer = computeUniformBuffer.contents().assumingMemoryBound(to: ComputeUniforms.self)
            computeUniformPointer.pointee.cameraToWorldTransform = cameraToWorldTransform
            
            computeUniformPointer.pointee.wristPosition = simd_make_float3_undef(observation[0])
            computeUniformPointer.pointee.thumbJointPositions  = getJointPositions(0)
            computeUniformPointer.pointee.indexJointPositions  = getJointPositions(1)
            computeUniformPointer.pointee.middleJointPositions = getJointPositions(2)
            computeUniformPointer.pointee.ringJointPositions   = getJointPositions(3)
            computeUniformPointer.pointee.littleJointPositions = getJointPositions(4)
            
            
            
            let commandBuffer = renderer.commandQueue.makeDebugCommandBuffer()
            commandBuffer.optLabel = "Hand Location Command Buffer"
            
            let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
            computeEncoder.optLabel = "Locate Hand Joints"
            
            computeEncoder.setTexture(colorTextureY,       index: 0)
            computeEncoder.setTexture(colorTextureCbCr,    index: 1)
            computeEncoder.setTexture(sceneDepthTexture,   index: 2)
            computeEncoder.setTexture(segmentationTexture, index: 3)
            
            computeEncoder.setComputePipelineState(sampleJointDepths1PipelineState)
            computeEncoder.setBuffer(computeUniformBuffer, offset: 0, index: 0)
            computeEncoder.dispatchThreadgroups(21, threadsPerThreadgroup: 32)
            
            computeEncoder.setComputePipelineState(locateHandCenterPipelineState)
            computeEncoder.dispatchThreadgroups(1,  threadsPerThreadgroup: 64)
            
            computeEncoder.setComputePipelineState(sampleJointDepths2PipelineState)
            computeEncoder.dispatchThreadgroups(21, threadsPerThreadgroup: 32)
            
            computeEncoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            
            
            let handIsDetected = computeUniformPointer.pointee.handIsDetected
            var newHandCenter: simd_float3?
            
            if handIsDetected >= 1 {
                let rawHandCenter = computeUniformPointer.pointee.handCenter
                newHandCenter = simd_float3(rawHandCenter.x, 1 - rawHandCenter.y, rawHandCenter.z)
            }
            
            if handIsDetected == 1 {
                results.color = computeUniformPointer.pointee.wristAndThumbColors.columns.0
            } else {
                results.isDetected = false
            }
            
            pendingLocationReturn = { [unowned self] in
                detectionResults = results
                
                rawPositions = observation
                filteredPositions = computeUniformPointer.pointee.positions
                handCenter = newHandCenter
            }
            
            currentlyDetectingHand = false
        }
    }
    
}
