import ARHeadsetKit

extension GameRenderer: CustomRenderer {
    
    func updateResources() {
        cubePicker.updateResources()
        
        if let cubeIndex = cubePicker.cubeIndex {
            cubes[cubeIndex].isRed = true
        }
        
        cubeRenderer.updateResources()
        
        if let cubeIndex = cubePicker.cubeIndex {
            cubes[cubeIndex].isRed = false
            
            if cubes[cubeIndex].velocity != nil {
                if cubes.contains(where: {
                    $0.velocity == nil
                }) {
                    setReactionParams()
                }
                
                cubePicker.cubeIndex = nil
            }
        }
        
        gameInterface.updateResources()
    }
    
    func setReactionParams() {
        let cubeIndex = cubePicker.cubeIndex!
        let location = cubes[cubeIndex].location
        
        guard drand48() < 0.50 else {
            gameInterface.reactionParams = nil
            return
        }
        
        let possibleMessages = [
            "Score!",
            "Rock On!",
            "When Pigs Fly...",
            "Yeet!",
        ]
        
        let message = possibleMessages.randomElement()!
        gameInterface.reactionParams = (message, location)
        gameInterface.updateReactionMessage()
    }
    
    func setCongratulation() {
        let cubeZone = simd_float2x3(
            [-0.3, -0.3, -0.6],
            [ 0.3,  0.3,  0.0]
        )
        
        let location = (cubeZone[0] + cubeZone[1]) / 2
        let message = "Congratulations!"
        
        gameInterface.reactionParams = (message, location)
        gameInterface.updateReactionMessage()
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
}
