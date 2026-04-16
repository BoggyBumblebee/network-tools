import SwiftUI
import AppKit
import Darwin

enum NetworkToolsAppSupport {
    enum SingleInstanceLockOutcome: Equatable {
        case skippedForTests
        case lockUnavailable
        case existingInstanceDetected(bundleIdentifier: String)
        case lockAcquired(fileDescriptor: Int32)
    }

    struct RunningApplicationProxy {
        let processIdentifier: Int32
        let bundleURL: URL?
        let unhide: () -> Void
        let activateAllWindows: () -> Void
    }

    static func helpURL(baseURL: URL?, anchor: String?) -> URL? {
        guard var helpURL = baseURL else {
            return nil
        }

        if let anchor, !anchor.isEmpty,
           var components = URLComponents(url: helpURL, resolvingAgainstBaseURL: false) {
            components.fragment = anchor
            if let anchoredURL = components.url {
                helpURL = anchoredURL
            }
        }

        return helpURL
    }

    static func openHelpPage(
        anchor: String?,
        baseHelpURL: URL?,
        openURL: (URL) -> Bool,
        beep: () -> Void
    ) {
        guard let helpURL = helpURL(baseURL: baseHelpURL, anchor: anchor) else {
            beep()
            return
        }

        if !openURL(helpURL) {
            beep()
        }
    }

    static func showAboutWindow(
        applicationName: String,
        icon: NSImage,
        orderFront: ([NSApplication.AboutPanelOptionKey: Any]) -> Void,
        activate: () -> Void
    ) {
        orderFront(aboutPanelOptions(applicationName: applicationName, icon: icon))
        activate()
    }

    static func aboutPanelOptions(
        applicationName: String,
        icon: NSImage
    ) -> [NSApplication.AboutPanelOptionKey: Any] {
        [
            .applicationName: applicationName,
            .applicationIcon: icon
        ]
    }

    static func resolveApplicationIcon(
        bundledIcon: NSImage?,
        applicationIcon: NSImage?,
        namedIcon: NSImage?,
        fallbackIcon: @autoclosure () -> NSImage
    ) -> NSImage {
        if let bundledIcon {
            return bundledIcon
        }
        if let applicationIcon {
            return applicationIcon
        }
        if let namedIcon {
            return namedIcon
        }
        return fallbackIcon()
    }

    static func bundledAppIcon(
        icnsURL: URL?,
        pngURL: URL?,
        imageLoader: (URL) -> NSImage?
    ) -> NSImage? {
        if let icnsURL, let icon = imageLoader(icnsURL) {
            return icon
        }
        if let pngURL, let icon = imageLoader(pngURL) {
            return icon
        }
        return nil
    }

    static func acquireSingleInstanceLock(
        environment: [String: String],
        bundleIdentifier: String?,
        temporaryDirectory: String,
        processIdentifier: Int32,
        openLockFile: (String, Int32, mode_t) -> Int32,
        lockFile: (Int32, Int32) -> Int32,
        closeFile: (Int32) -> Int32,
        truncateFile: (Int32, off_t) -> Int32,
        seekFile: (Int32, off_t, Int32) -> off_t,
        writeString: (Int32, String) -> Void
    ) -> SingleInstanceLockOutcome {
        if environment["XCTestConfigurationFilePath"] != nil {
            return .skippedForTests
        }

        let resolvedBundleIdentifier = bundleIdentifier ?? "NetworkTools"
        let lockPath = (temporaryDirectory as NSString).appendingPathComponent(
            "\(resolvedBundleIdentifier).single-instance.lock"
        )
        let fd = openLockFile(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            return .lockUnavailable
        }

        if lockFile(fd, LOCK_EX | LOCK_NB) != 0 {
            _ = closeFile(fd)
            return .existingInstanceDetected(bundleIdentifier: resolvedBundleIdentifier)
        }

        _ = truncateFile(fd, 0)
        _ = seekFile(fd, 0, SEEK_SET)
        writeString(fd, "\(processIdentifier)\n")

        return .lockAcquired(fileDescriptor: fd)
    }

    static func activateExistingApplication(
        currentProcessIdentifier: Int32,
        runningApplications: [RunningApplicationProxy],
        openApplication: (URL) -> Void
    ) -> Bool {
        guard let existingApplication = runningApplications.first(
            where: { $0.processIdentifier != currentProcessIdentifier }
        ) else {
            return false
        }

        existingApplication.unhide()
        existingApplication.activateAllWindows()
        if let bundleURL = existingApplication.bundleURL {
            openApplication(bundleURL)
        }
        return true
    }
}

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
        let processIdentifier = ProcessInfo.processInfo.processIdentifier
        let outcome = NetworkToolsAppSupport.acquireSingleInstanceLock(
            environment: ProcessInfo.processInfo.environment,
            bundleIdentifier: Bundle.main.bundleIdentifier,
            temporaryDirectory: NSTemporaryDirectory(),
            processIdentifier: processIdentifier,
            openLockFile: { open($0, $1, $2) },
            lockFile: { flock($0, $1) },
            closeFile: { close($0) },
            truncateFile: { ftruncate($0, $1) },
            seekFile: { lseek($0, $1, $2) },
            writeString: { fd, value in
                _ = value.withCString { cString in
                    write(fd, cString, strlen(cString))
                }
            }
        )

        switch outcome {
        case .lockAcquired(let fileDescriptor):
            singleInstanceLockFD = fileDescriptor
        case .existingInstanceDetected(let bundleIdentifier):
            let runningApplications = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
            ).map { application in
                NetworkToolsAppSupport.RunningApplicationProxy(
                    processIdentifier: application.processIdentifier,
                    bundleURL: application.bundleURL,
                    unhide: { application.unhide() },
                    activateAllWindows: { _ = application.activate(options: [.activateAllWindows]) }
                )
            }
            _ = NetworkToolsAppSupport.activateExistingApplication(
                currentProcessIdentifier: processIdentifier,
                runningApplications: runningApplications,
                openApplication: { bundleURL in
                    NSWorkspace.shared.openApplication(
                        at: bundleURL,
                        configuration: NSWorkspace.OpenConfiguration()
                    ) { _, _ in }
                }
            )
            exit(EXIT_SUCCESS)
        case .skippedForTests, .lockUnavailable:
            return
        }
    }

    static func openHelpPage(
        anchor: String? = nil,
        baseHelpURL: URL? = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Help")
            ?? Bundle.main.url(forResource: "index", withExtension: "html"),
        openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) },
        beep: () -> Void = { NSSound.beep() }
    ) {
        NetworkToolsAppSupport.openHelpPage(
            anchor: anchor,
            baseHelpURL: baseHelpURL,
            openURL: openURL,
            beep: beep
        )
    }

    static func showAboutWindow(
        applicationName: String = "Network Tools",
        icon: NSImage? = nil,
        orderFront: ([NSApplication.AboutPanelOptionKey: Any]) -> Void = {
            NSApp.orderFrontStandardAboutPanel(options: $0)
        },
        activate: () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        }
    ) {
        NetworkToolsAppSupport.showAboutWindow(
            applicationName: applicationName,
            icon: icon ?? resolvedApplicationIcon(),
            orderFront: orderFront,
            activate: activate
        )
    }

    static func resolvedApplicationIcon(
        bundledIcon: NSImage? = bundledAppIcon(),
        applicationIcon: NSImage? = NSApplication.shared.applicationIconImage,
        namedIcon: NSImage? = NSImage(named: NSImage.applicationIconName),
        fallbackIcon: @autoclosure () -> NSImage = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    ) -> NSImage {
        NetworkToolsAppSupport.resolveApplicationIcon(
            bundledIcon: bundledIcon,
            applicationIcon: applicationIcon,
            namedIcon: namedIcon,
            fallbackIcon: fallbackIcon()
        )
    }

    private static func bundledAppIcon() -> NSImage? {
        NetworkToolsAppSupport.bundledAppIcon(
            icnsURL: Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            pngURL: Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
            imageLoader: { NSImage(contentsOf: $0) }
        )
    }
}
