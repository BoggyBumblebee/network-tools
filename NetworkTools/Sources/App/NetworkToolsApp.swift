import SwiftUI
import AppKit
import Darwin

@main
struct NetworkToolsApp: App {
    private static var singleInstanceLockFD: Int32 = -1

    init() {
        Self.enforceSingleInstance()
        if let icon = Self.bundledAppIcon() {
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
                    Self.showAboutWindow()
                }
            }
            CommandGroup(replacing: .help) {
                Button("Network Tools Help") {
                    Self.openHelpPage()
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])

                Button("Quick Start") {
                    Self.openHelpPage(anchor: "quick-start")
                }

                Button("Troubleshooting") {
                    Self.openHelpPage(anchor: "troubleshooting")
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
                existingApp.unhide()
                _ = existingApp.activate(options: [.activateAllWindows])
                if let bundleURL = existingApp.bundleURL {
                    NSWorkspace.shared.openApplication(
                        at: bundleURL,
                        configuration: NSWorkspace.OpenConfiguration()
                    ) { _, _ in }
                }
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

    private static func openHelpPage(anchor: String? = nil) {
        guard var helpURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Help")
            ?? Bundle.main.url(forResource: "index", withExtension: "html") else {
            NSSound.beep()
            return
        }

        if let anchor, !anchor.isEmpty,
           var components = URLComponents(url: helpURL, resolvingAgainstBaseURL: false) {
            components.fragment = anchor
            if let anchoredURL = components.url {
                helpURL = anchoredURL
            }
        }

        if !NSWorkspace.shared.open(helpURL) {
            NSSound.beep()
        }
    }

    private static func showAboutWindow() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Network Tools",
            .applicationIcon: resolvedApplicationIcon()
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func resolvedApplicationIcon() -> NSImage {
        if let icon = bundledAppIcon() {
            return icon
        }
        if let icon = NSApplication.shared.applicationIconImage {
            return icon
        }
        if let icon = NSImage(named: NSImage.applicationIconName) {
            return icon
        }
        // `icon(forFile:)` resolves the same icon representation shown in Finder and Dock.
        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    private static func bundledAppIcon() -> NSImage? {
        if let icnsURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: icnsURL) {
            return icon
        }
        if let pngURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: pngURL) {
            return icon
        }
        return nil
    }
}
