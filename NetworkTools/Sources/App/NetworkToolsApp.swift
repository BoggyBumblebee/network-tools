import SwiftUI
import AppKit
import Darwin

@main
struct NetworkToolsApp: App {
    private static var singleInstanceLockFD: Int32 = -1

    init() {
        Self.enforceSingleInstance()

        // Force the runtime app icon from the compiled icon resource so Dock and About stay in sync.
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup("Network Tools") {
            RootTabView()
                .frame(minWidth: 980, minHeight: 310)
        }
        .defaultSize(width: 980, height: 310)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Network Tools") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Network Tools",
                        .applicationIcon: NSApplication.shared.applicationIconImage as Any
                    ])
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    private static func enforceSingleInstance() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "NetworkTools"
        let lockPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(bundleIdentifier).single-instance.lock")
        let fd = open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)

        guard fd >= 0 else {
            return
        }

        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)

            if let existingApp = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
                .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
                existingApp.activate(options: [.activateAllWindows])
            }

            exit(EXIT_SUCCESS)
        }

        singleInstanceLockFD = fd

        let pidString = "\(ProcessInfo.processInfo.processIdentifier)\n"
        _ = ftruncate(fd, 0)
        _ = lseek(fd, 0, SEEK_SET)
        _ = pidString.withCString { cString in
            write(fd, cString, strlen(cString))
        }
    }
}
