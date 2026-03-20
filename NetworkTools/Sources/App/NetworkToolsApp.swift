import SwiftUI

@main
struct NetworkToolsApp: App {
    var body: some Scene {
        WindowGroup("Network Tools") {
            RootTabView()
                .frame(minWidth: 980, minHeight: 310)
        }
        .defaultSize(width: 980, height: 310)
    }
}
