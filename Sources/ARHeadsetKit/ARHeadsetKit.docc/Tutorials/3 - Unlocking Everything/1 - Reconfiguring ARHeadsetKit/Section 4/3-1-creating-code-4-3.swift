import ARHeadsetKit
import SwiftUI

func foo(_ temperature: Double) -> simd_float3 {
    kelvinToRGB(temperature)
}

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
