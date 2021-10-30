import ARHeadsetKit

struct Cube {
    var location: simd_float3
    var orientation: simd_quatf
    var sideLength: Float
    
    var velocity: simd_float3?
    var angularVelocity: simd_quatf?
    
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
    
    func render(centralRenderer: CentralRenderer) {
        centralRenderer.render(object: object)
    }
}

extension Cube {
    
    func trace(ray: RayTracing.Ray) -> Float? {
        guard velocity == nil, angularVelocity == nil else {
            return nil
        }
        
        return object.trace(ray: ray)
    }
    
    mutating func collide(location impactLocation: simd_float3,
                          direction: simd_float3, speed: Float)
    {
        assert(length(direction) > 0 && speed >= 0)
        
        velocity = speed * normalize(direction)
        angularVelocity = simd_quatf(angle: 2, axis: [0, 1, 0])
    }
    
    mutating func update() {
        defer {
            object = getObject()
        }
    }
    
}
