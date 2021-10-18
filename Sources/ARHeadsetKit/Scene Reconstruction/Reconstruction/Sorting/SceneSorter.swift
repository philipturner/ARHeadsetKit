//
//  SceneSorter.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

final class SceneSorter: DelegateSceneRenderer {
    unowned let sceneRenderer: SceneRenderer
    
    var firstNode: OctreeNode!
    var octreeAsArray: [OctreeNode.ArrayElement]!
    var worldOctantSize: Float = .nan
    
    var firstSceneSorter: FirstSceneSorter!
    var secondSceneSorter: SecondSceneSorter!
    var thirdSceneSorter: ThirdSceneSorter!
    var fourthSceneSorter: FourthSceneSorter!
    
    init(sceneRenderer: SceneRenderer, library: MTLLibrary) {
        self.sceneRenderer = sceneRenderer
        
        firstSceneSorter  = FirstSceneSorter(sceneSorter: self, library: library)
        secondSceneSorter = SecondSceneSorter(sceneSorter: self, library: library)
        thirdSceneSorter  = ThirdSceneSorter(sceneSorter: self, library: library)
        fourthSceneSorter = FourthSceneSorter(sceneSorter: self, library: library)
    }
}

protocol DelegateSceneSorter {
    var sceneSorter: SceneSorter { get }
    
    init(sceneSorter: SceneSorter, library: MTLLibrary)
}

extension DelegateSceneSorter {
    var sceneRenderer: SceneRenderer { sceneSorter.sceneRenderer }
    var renderer: MainRenderer { sceneSorter.renderer }
    var device: MTLDevice { sceneSorter.device }
    var sceneMeshReducer: SceneMeshReducer { sceneSorter.sceneMeshReducer }
    
    var preCullVertexCount: Int { sceneMeshReducer.preCullVertexCount }
    var preCullTriangleCount: Int { sceneMeshReducer.preCullTriangleCount }
    
    var reducedVertexBuffer: MTLBuffer { sceneMeshReducer.pendingReducedVertexBuffer }
    var reducedColorBuffer: MTLBuffer { sceneMeshReducer.pendingReducedColorBuffer }
    var reducedIndexBuffer: MTLBuffer { sceneMeshReducer.pendingReducedIndexBuffer }
    
    var firstNode: OctreeNode { sceneSorter.firstNode }
    var octreeAsArray: [OctreeNode.ArrayElement] { sceneSorter.octreeAsArray }
    var worldOctantSize: Float { sceneSorter.worldOctantSize }
    
    var firstSceneSorter: FirstSceneSorter { sceneSorter.firstSceneSorter }
    var secondSceneSorter: SecondSceneSorter { sceneSorter.secondSceneSorter }
    var thirdSceneSorter: ThirdSceneSorter { sceneSorter.thirdSceneSorter }
    var fourthSceneSorter: FourthSceneSorter { sceneSorter.fourthSceneSorter }
}
