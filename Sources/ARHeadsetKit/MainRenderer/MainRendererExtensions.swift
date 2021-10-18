//
//  MainRendererExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/11/21.
//

import Metal
import ARKit
import SwiftUI

protocol GeometryRenderer {
    associatedtype GeometryType: CaseIterable
    @inlinable func drawGeometry(type: GeometryType, renderEncoder: ARMetalRenderCommandEncoder)
}

protocol BufferExpandable {
    associatedtype BufferType: CaseIterable
    @inlinable func ensureBufferCapacity(type: BufferType, capacity: Int)
}

extension BufferExpandable {
    @inlinable func ensureBufferCapacity<T: FixedWidthInteger>(type: BufferType, capacity: T) {
        ensureBufferCapacity(type: type, capacity: Int(capacity))
    }
}

extension MainRenderer {
    
    func updateResources(frame: ARFrame) {
        if coordinator.settingsAreShown {
            if timeSinceSettingsOpenAnimationStart < 0 {
                timeSinceSettingsOpenAnimationStart = 0
            } else {
                timeSinceSettingsOpenAnimationStart += 1
            }
        } else {
            timeSinceSettingsOpenAnimationStart = .min
        }
        
        if coordinator.showingAppTutorial {
            shouldRenderToDisplay = false
        } else {
            let waitTime = Int(MainSettingsView<EmptySettingsView>.openAnimationDuration * 60 * 2)
            shouldRenderToDisplay = timeSinceSettingsOpenAnimationStart < waitTime
        }
        
        
        
        if !coordinator.settingsShouldBeAnimated {
            coordinator.settingsShouldBeAnimated = true
        }
        
        var renderingSettings: RenderingSettings { coordinator.renderingSettings }
        usingHeadsetMode = renderingSettings.usingHeadsetMode
        usingFlyingMode  = renderingSettings.usingFlyingMode
        
        interfaceScaleChanged = interfaceScale != renderingSettings.interfaceScale
        if interfaceScaleChanged { interfaceScale = renderingSettings.interfaceScale }
        
        if UIDevice.current.userInterfaceIdiom != .phone {
            usingHeadsetMode = false
        }
        
        userSettings.updateResources()
        
        var storedSettings: UserSettings.StoredSettings { userSettings.storedSettings }
        allowingSceneReconstruction = storedSettings.allowingSceneReconstruction
        allowingHandReconstruction = storedSettings.allowingHandReconstruction
        
        asyncUpdateTextures(frame: frame)
        updateUniforms(frame: frame)
        
        if usingLiDAR, allowingSceneReconstruction {
            sceneRenderer.asyncUpdateResources(frame: frame)
        } else {
            sceneRenderer2D.asyncUpdateResources()
        }
        
        userSettings.lensDistortionCorrector.updateResources()
        centralRenderer.initializeFrameData()
        interfaceRenderer.initializeFrameData()
        
        updateInteractionRay(frame: frame)
        
        
        
        customRenderer?.updateResources()
        
        if shouldRenderToDisplay {
            interfaceRenderer.updateResources()
            centralRenderer.updateResources()
        }
    }
    
    func drawGeometry(renderEncoder mtlRenderEncoder: MTLRenderCommandEncoder, threadID: Int = 0) {
        let renderEncoder = ARMetalRenderCommandEncoder(renderer: self, encoder: mtlRenderEncoder, threadID: threadID)
        
        let fragmentUniformBuffer = centralRenderer.globalFragmentUniformBuffer
        let fragmentUniformOffset = centralRenderer.globalFragmentUniformOffset
        renderEncoder.encoder.setFragmentBuffer(fragmentUniformBuffer, offset: fragmentUniformOffset, index: 0)
        
        interfaceRenderer.drawGeometry(type: .opaque, renderEncoder: renderEncoder)
        renderEncoder.encoder.setDepthStencilState(depthStencilState)
        
        renderEncoder.pushOptDebugGroup("Render Custom Objects")
        customRenderer?.drawGeometry(renderEncoder: renderEncoder)
        renderEncoder.clearDebugGroups()
        
        centralRenderer.drawGeometry(type: .object, renderEncoder: renderEncoder)
        
        if usingLiDAR, allowingSceneReconstruction {
            sceneRenderer.updateResourcesSemaphore.wait()
            sceneRenderer.drawGeometry(type: .sceneMesh, renderEncoder: renderEncoder)
        } else {
            sceneRenderer2D.updateResourcesSemaphore.wait()
            sceneRenderer2D.drawGeometry(type: .sceneRectangle, renderEncoder: renderEncoder)
        }
        
        interfaceRenderer.drawGeometry(type: .transparent, renderEncoder: renderEncoder)
    }
    
    func asyncUpdateTextures(frame: ARFrame) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            @inline(__always)
            func bind(_ pixelBuffer: CVPixelBuffer?, to reference: inout MTLTexture!, _ label: String,
                      _ pixelFormat: MTLPixelFormat, _ width: Int, _ height: Int, _ planeIndex: Int = 0)
            {
                guard let pixelBuffer = pixelBuffer else {
                    reference = nil
                    return
                }
                
                reference = textureCache.createMTLTexture(pixelBuffer, pixelFormat, width, height, planeIndex)!
                reference.optLabel = label
            }
            
            if usingLiDAR, allowingHandReconstruction || allowingSceneReconstruction {
                bind(frame.segmentationBuffer, to: &segmentationTexture, "Segmentation Texture", .r8Unorm, 256, 192)
                bind(frame.sceneDepth?.depthMap, to: &sceneDepthTexture, "Scene Depth Texture", .r32Float, 256, 192)
                
                if allowingHandReconstruction {
                    handRenderer.segmentationTextureSemaphore.signal()
                }
                
                if allowingSceneReconstruction {
                    sceneRenderer.segmentationTextureSemaphore.signal()
                }
            }
            
            let width  = Int(cameraMeasurements.imageResolution.width)
            let height = Int(cameraMeasurements.imageResolution.height)
            
            bind(frame.capturedImage, to: &colorTextureY,    "Color Texture (Y)",    .r8Unorm,  width,      height,      0)
            bind(frame.capturedImage, to: &colorTextureCbCr, "Color Texture (CbCr)", .rg8Unorm, width >> 1, height >> 1, 1)
            
            if usingLiDAR {
                if allowingHandReconstruction {
                    handRenderer.colorTextureSemaphore.signal()
                }
                
                if allowingSceneReconstruction {
                    sceneRenderer.colorTextureSemaphore.signal()
                } else {
                    sceneRenderer2D.colorTextureSemaphore.signal()
                }
            } else {
                sceneRenderer2D.colorTextureSemaphore.signal()
            }
        }
    }
    
    func updateUniforms(frame: ARFrame) {
        renderIndex = (renderIndex == MainRenderer.numRenderBuffers - 1) ? 0 : renderIndex + 1
        
        timeSinceLastTouch += 1
        timeSinceCurrentTouch += 1
        
        if !usingFlyingMode {
            alreadyStartedUsingFlyingMode = false
        }
        
        if !touchingScreen {
            
        } else if !longPressingScreen {
            timeSinceLastTouch = timeSinceCurrentTouch
            timeSinceCurrentTouch = 0
            
            if usingFlyingMode, alreadyStartedUsingFlyingMode,
               timeSinceLastTouch - timeSinceCurrentTouch < 30, !lastTouchDirectionWasSwitch
            {
                flyingDirectionIsForward = !flyingDirectionIsForward
                lastTouchDirectionWasSwitch = true
            } else {
                lastTouchDirectionWasSwitch = false
            }
        } else {
            if usingFlyingMode, alreadyStartedUsingFlyingMode {
                if timeSinceCurrentTouch >= 30 {
                    cameraMeasurements.flyingPerspectiveAdjustMode = .move
                }
            }
        }
        
        if usingFlyingMode {
            if !alreadyStartedUsingFlyingMode {
                alreadyStartedUsingFlyingMode = true
                
                cameraMeasurements.flyingPerspectiveAdjustMode = .start
            }
        }
        
        let lightEstimate = frame.lightEstimate!
        let convertedColor = kelvinToRGB(Double(lightEstimate.ambientColorTemperature))
        let ambientIntensity = Float(lightEstimate.ambientIntensity) * (0.6 / 1000)
        
        ambientLightColor     = simd_half3(convertedColor * ambientIntensity)
        directionalLightColor = simd_half3(simd_float3(repeating: ambientIntensity))
        
        cameraMeasurements.updateResources(frame: frame)
    }
    
    private func updateInteractionRay(frame: ARFrame) {
        if userSettings.storedSettings.usingHandForSelection {
            if usingLiDAR, allowingHandReconstruction {
                handRenderer.updateResources(frame: frame)
                interactionRay = handRenderer.handRay
            } else {
                handRenderer2D.updateResources(frame: frame)
                interactionRay = handRenderer2D.handRay
                
                if let interactionRay = interactionRay, userSettings.storedSettings.showingHandPosition {
                    let handPosition = fma(interactionRay.direction, Self.interfaceDepth, interactionRay.origin)
                    
                    let handPositionObject = ARObject(shapeType: .sphere,
                                                      position: handPosition,
                                                      scale: [0.017, 0.017, 0.017],
                                                      
                                                      color: [0.9, 0.9, 0.9])
                    
                    centralRenderer.render(object: handPositionObject)
                }
            }
        } else {
            if usingLiDAR, allowingHandReconstruction {
                handRenderer.updateResources(frame: frame)
            }
            
            var rayOrigin: simd_float3
            
            if usingHeadsetMode {
                let headPosition = simd_float4(cameraMeasurements.cameraSpaceHeadPosition, 1)
                rayOrigin = simd_make_float3(cameraMeasurements.cameraToWorldTransform * headPosition)
            } else {
                rayOrigin = simd_make_float3(cameraMeasurements.cameraToWorldTransform[3])
            }
            
            let rayDirection = -simd_make_float3(cameraMeasurements.cameraToWorldTransform[2])
            interactionRay = .init(origin: rayOrigin, direction: rayDirection)
        }
        
        if usingFlyingMode {
            interactionRay = nil
        }
    }
    
}
