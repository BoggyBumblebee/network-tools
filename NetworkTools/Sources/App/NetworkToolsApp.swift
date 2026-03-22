import SwiftUI
import AppKit
import Darwin

@main
struct NetworkToolsApp: App {
    private static var singleInstanceLockFD: Int32 = -1

    init() {
        Self.enforceSingleInstance()

        // Keep runtime icon in sync with the bundle icon used by Finder/Dock.
        NSApplication.shared.applicationIconImage = Self.resolvedApplicationIcon()
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
                        .applicationIcon: Self.resolvedApplicationIcon()
                    ])
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            CommandGroup(after: .help) {
                Button("Network Tools Help") {
                    Self.openHelpPage()
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

    private static func openHelpPage() {
        guard let helpURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Help") else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(helpURL)
    }

    private static func resolvedApplicationIcon() -> NSImage {
        // `icon(forFile:)` resolves the same icon representation shown in Finder and Dock.
        let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        icon.size = NSSize(width: 128, height: 128)
        return icon
    }
}
