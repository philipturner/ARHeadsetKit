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
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
}
