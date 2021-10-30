import ARHeadsetKit

struct Cube {
    var location: simd_float3
    var orientation: simd_quatf
    var sideLength: Float
    
    var object: ARObject!
    
    init(location: simd_float3,
         orientation: simd_quatf,
         sideLength: Float)
    {
        self.location = location
        self.orientation = orientation
        self.sideLength = sideLength
        
        object = getObject()
    }
    
    private func getObject() -> ARObject {
        .init(shapeType: .cube,
              position: location,
              orientation: orientation,
              scale: .init(repeating: sideLength))
    }
}
