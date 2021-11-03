import ARHeadsetKit

struct Cube {
    var location: simd_float3
    var orientation: simd_quatf
    var sideLength: Float
    
    var velocity: simd_float3?
    var angularVelocity: simd_quatf?
    
    var isRed = false
    var isHighlighted = false
    var object: ARObject!
    var normalObject: ARObject!
    
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
    
    func getNormalObject(location: simd_float3,
                         normal: simd_float3) -> ARObject {
        .init(shapeType: .cylinder,
              position: location,
              orientation: simd_quatf(from: [0, 1, 0], to: normal),
              scale: [sideLength / 4, sideLength, sideLength / 4],
              
              color: .init(repeating: 0.8))
    }
    
    func render(centralRenderer: CentralRenderer) {
        guard location.y > -200 else {
            // The cube fell over 200 meters!
            return
        }
        
        centralRenderer.render(object: object)
        
        if let normalObject = normalObject {
            centralRenderer.render(object: normalObject)
        }
    }
}

extension Cube: RayTraceable {
    
    func trace(ray: RayTracing.Ray) -> Float? {
        guard velocity == nil, angularVelocity == nil else {
            return nil
        }
        
        return object.trace(ray: ray)
    }
    
    mutating func update() {
        defer {
            object = getObject()
        }
        
        guard let velocity = velocity,
              let angularVelocity = angularVelocity else {
            return
        }
        
        location += velocity / 60
        
        let acceleration: simd_float3 = [0, -9.8, 0]
        self.velocity! += acceleration / 60
        
        
        
        let angle = angularVelocity.angle / 60
        let axis  = angle == 0 ? [0, 1, 0] : angularVelocity.axis
        
        let rotation = simd_quatf(angle: angle, axis: axis)
        orientation = rotation * orientation
    }
    
}
