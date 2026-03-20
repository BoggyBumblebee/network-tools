import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .info

    @StateObject private var infoViewModel = InfoViewModel()
    @StateObject private var pingViewModel = PingViewModel()
    @StateObject private var portScanViewModel = PortScanViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            InfoTabView(viewModel: infoViewModel)
                .tabItem { Label("Info", systemImage: "info.circle") }
                .tag(AppTab.info)

            PingTabView(viewModel: pingViewModel)
                .tabItem { Label("Ping", systemImage: "dot.radiowaves.left.and.right") }
                .tag(AppTab.ping)

            PortScanTabView(viewModel: portScanViewModel)
                .tabItem { Label("Port Scan", systemImage: "shield.lefthalf.filled") }
                .tag(AppTab.portScan)
        }
        .onAppear {
            infoViewModel.setInfoTabActive(true)
        }
        .onChange(of: selectedTab) { _, newValue in
            infoViewModel.setInfoTabActive(newValue == .info)
        }
    }
}
