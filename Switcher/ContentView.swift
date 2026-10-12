import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Немає перемикачів",
                systemImage: "switch.2",
                description: Text("Тут з'явиться список ваших перемикачів.")
            )
            .navigationTitle("Switcher")
        }
    }
}

#Preview {
    ContentView()
}
