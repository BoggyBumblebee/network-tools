import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab

    @StateObject private var infoViewModel = InfoViewModel()
    @StateObject private var pingViewModel = PingViewModel()
    @StateObject private var portScanViewModel = PortScanViewModel()

    init(initialTab: AppTab = Self.initialTab(launchArguments: ProcessInfo.processInfo.arguments)) {
        _selectedTab = State(initialValue: initialTab)
    }

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
            infoViewModel.setInfoTabActive(selectedTab == .info)
        }
        .onChange(of: selectedTab) { _, newValue in
            infoViewModel.setInfoTabActive(newValue == .info)
        }
    }

    static func initialTab(launchArguments: [String]) -> AppTab {
        let prefix = "--uitesting-select-tab="

        guard let argument = launchArguments.first(where: { $0.hasPrefix(prefix) }) else {
            return .info
        }

        switch argument.dropFirst(prefix.count).lowercased() {
        case "info":
            return .info
        case "ping":
            return .ping
        case "portscan", "port-scan", "port_scan":
            return .portScan
        default:
            return .info
        }
    }
}
