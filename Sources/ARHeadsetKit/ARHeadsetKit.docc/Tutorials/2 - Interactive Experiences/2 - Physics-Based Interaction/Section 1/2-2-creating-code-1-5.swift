import ARHeadsetKit

struct Cube {
    var location: simd_float3
    var orientation: simd_quatf
    var sideLength: Float
    
    var isHighlighted = false
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
    
    func getObject() -> ARObject {
        var color: simd_float3
        
        if isHighlighted {
            color = [0.6, 0.8, 1.0]
        } else {
            color = [0.2, 0.5, 0.7]
        }
        
        return ARObject(shapeType: .cube,
                        position: location,
                        orientation: orientation,
                        scale: .init(repeating: sideLength),
                        
                        color: color)
    }
}
