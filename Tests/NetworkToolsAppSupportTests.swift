import XCTest
import AppKit
@testable import NetworkTools

final class NetworkToolsAppSupportTests: XCTestCase {
    func testHelpURLReturnsNilWhenBaseURLIsMissing() {
        XCTAssertNil(NetworkToolsAppSupport.helpURL(baseURL: nil, anchor: "quick-start"))
    }

    func testHelpURLReturnsBaseURLWhenAnchorIsMissingOrEmpty() {
        let baseURL = URL(fileURLWithPath: "/tmp/help/index.html")

        XCTAssertEqual(NetworkToolsAppSupport.helpURL(baseURL: baseURL, anchor: nil), baseURL)
        XCTAssertEqual(NetworkToolsAppSupport.helpURL(baseURL: baseURL, anchor: ""), baseURL)
    }

    func testHelpURLAddsAnchorFragment() {
        let baseURL = URL(fileURLWithPath: "/tmp/help/index.html")

        let anchoredURL = NetworkToolsAppSupport.helpURL(baseURL: baseURL, anchor: "troubleshooting")

        XCTAssertEqual(anchoredURL?.fragment, "troubleshooting")
    }

    func testOpenHelpPageBeepsWhenHelpURLCannotBeResolved() {
        var beepCount = 0

        NetworkToolsAppSupport.openHelpPage(
            anchor: "quick-start",
            baseHelpURL: nil,
            openURL: { _ in
                XCTFail("openURL should not be called when help URL is missing")
                return true
            },
            beep: { beepCount += 1 }
        )

        XCTAssertEqual(beepCount, 1)
    }

    func testOpenHelpPageBeepsWhenOpenFails() {
        let baseURL = URL(fileURLWithPath: "/tmp/help/index.html")
        var openedURL: URL?
        var beepCount = 0

        NetworkToolsAppSupport.openHelpPage(
            anchor: "quick-start",
            baseHelpURL: baseURL,
            openURL: {
                openedURL = $0
                return false
            },
            beep: { beepCount += 1 }
        )

        XCTAssertEqual(openedURL?.fragment, "quick-start")
        XCTAssertEqual(beepCount, 1)
    }

    func testOpenHelpPageDoesNotBeepWhenOpenSucceeds() {
        let baseURL = URL(fileURLWithPath: "/tmp/help/index.html")
        var beepCount = 0

        NetworkToolsAppSupport.openHelpPage(
            anchor: nil,
            baseHelpURL: baseURL,
            openURL: { _ in true },
            beep: { beepCount += 1 }
        )

        XCTAssertEqual(beepCount, 0)
    }

    func testResolveApplicationIconUsesExpectedPrecedence() {
        let bundledIcon = NSImage(size: NSSize(width: 16, height: 16))
        let applicationIcon = NSImage(size: NSSize(width: 16, height: 16))
        let namedIcon = NSImage(size: NSSize(width: 16, height: 16))
        let fallbackIcon = NSImage(size: NSSize(width: 16, height: 16))

        XCTAssertTrue(
            NetworkToolsAppSupport.resolveApplicationIcon(
                bundledIcon: bundledIcon,
                applicationIcon: applicationIcon,
                namedIcon: namedIcon,
                fallbackIcon: fallbackIcon
            ) === bundledIcon
        )

        XCTAssertTrue(
            NetworkToolsAppSupport.resolveApplicationIcon(
                bundledIcon: nil,
                applicationIcon: applicationIcon,
                namedIcon: namedIcon,
                fallbackIcon: fallbackIcon
            ) === applicationIcon
        )

        XCTAssertTrue(
            NetworkToolsAppSupport.resolveApplicationIcon(
                bundledIcon: nil,
                applicationIcon: nil,
                namedIcon: namedIcon,
                fallbackIcon: fallbackIcon
            ) === namedIcon
        )

        XCTAssertTrue(
            NetworkToolsAppSupport.resolveApplicationIcon(
                bundledIcon: nil,
                applicationIcon: nil,
                namedIcon: nil,
                fallbackIcon: fallbackIcon
            ) === fallbackIcon
        )
    }

    func testShowAboutWindowPassesOptionsAndActivates() {
        let icon = NSImage(size: NSSize(width: 32, height: 32))
        var capturedOptions: [NSApplication.AboutPanelOptionKey: Any]?
        var didActivate = false

        NetworkToolsAppSupport.showAboutWindow(
            applicationName: "Network Tools",
            icon: icon,
            orderFront: { capturedOptions = $0 },
            activate: { didActivate = true }
        )

        XCTAssertEqual(capturedOptions?[.applicationName] as? String, "Network Tools")
        XCTAssertTrue((capturedOptions?[.applicationIcon] as? NSImage) === icon)
        XCTAssertTrue(didActivate)
    }

    func testBundledAppIconPrefersICNSThenFallsBackToPNG() {
        let icnsURL = URL(fileURLWithPath: "/tmp/AppIcon.icns")
        let pngURL = URL(fileURLWithPath: "/tmp/AppIcon.png")
        let icnsImage = NSImage(size: NSSize(width: 32, height: 32))
        let pngImage = NSImage(size: NSSize(width: 32, height: 32))

        let icnsResult = NetworkToolsAppSupport.bundledAppIcon(
            icnsURL: icnsURL,
            pngURL: pngURL,
            imageLoader: { url in
                if url == icnsURL { return icnsImage }
                if url == pngURL { return pngImage }
                return nil
            }
        )
        XCTAssertTrue(icnsResult === icnsImage)

        let pngFallbackResult = NetworkToolsAppSupport.bundledAppIcon(
            icnsURL: icnsURL,
            pngURL: pngURL,
            imageLoader: { url in
                if url == pngURL { return pngImage }
                return nil
            }
        )
        XCTAssertTrue(pngFallbackResult === pngImage)
    }

    func testBundledAppIconReturnsNilWhenNoAssetCanBeLoaded() {
        let icon = NetworkToolsAppSupport.bundledAppIcon(
            icnsURL: URL(fileURLWithPath: "/tmp/AppIcon.icns"),
            pngURL: URL(fileURLWithPath: "/tmp/AppIcon.png"),
            imageLoader: { _ in nil }
        )

        XCTAssertNil(icon)
    }

    func testNetworkToolsAppOpenHelpPageUsesInjectedDependencies() {
        let baseURL = URL(fileURLWithPath: "/tmp/help/index.html")
        var openedURL: URL?
        var beepCount = 0

        NetworkToolsApp.openHelpPage(
            anchor: "quick-start",
            baseHelpURL: baseURL,
            openURL: {
                openedURL = $0
                return true
            },
            beep: { beepCount += 1 }
        )

        XCTAssertEqual(openedURL?.fragment, "quick-start")
        XCTAssertEqual(beepCount, 0)
    }

    func testNetworkToolsAppOpenHelpPageUsesDefaultHelpResource() {
        var openedURL: URL?
        var beepCount = 0

        NetworkToolsApp.openHelpPage(
            anchor: "quick-start",
            openURL: {
                openedURL = $0
                return true
            },
            beep: { beepCount += 1 }
        )

        XCTAssertEqual(openedURL?.lastPathComponent, "index.html")
        XCTAssertEqual(openedURL?.fragment, "quick-start")
        XCTAssertEqual(beepCount, 0)
    }

    func testNetworkToolsAppShowAboutWindowUsesInjectedDependencies() {
        let icon = NSImage(size: NSSize(width: 16, height: 16))
        var capturedOptions: [NSApplication.AboutPanelOptionKey: Any]?
        var didActivate = false

        NetworkToolsApp.showAboutWindow(
            applicationName: "Network Tools",
            icon: icon,
            orderFront: { capturedOptions = $0 },
            activate: { didActivate = true }
        )

        XCTAssertEqual(capturedOptions?[.applicationName] as? String, "Network Tools")
        XCTAssertTrue((capturedOptions?[.applicationIcon] as? NSImage) === icon)
        XCTAssertTrue(didActivate)
    }

    func testNetworkToolsAppShowAboutWindowFallsBackToResolvedIcon() {
        var capturedOptions: [NSApplication.AboutPanelOptionKey: Any]?
        var didActivate = false

        NetworkToolsApp.showAboutWindow(
            applicationName: "Network Tools",
            icon: nil,
            orderFront: { capturedOptions = $0 },
            activate: { didActivate = true }
        )

        XCTAssertEqual(capturedOptions?[.applicationName] as? String, "Network Tools")
        XCTAssertNotNil(capturedOptions?[.applicationIcon] as? NSImage)
        XCTAssertTrue(didActivate)
    }

    func testNetworkToolsAppResolvedApplicationIconUsesInjectedInputs() {
        let bundledIcon = NSImage(size: NSSize(width: 16, height: 16))
        let fallbackIcon = NSImage(size: NSSize(width: 16, height: 16))

        let resolved = NetworkToolsApp.resolvedApplicationIcon(
            bundledIcon: bundledIcon,
            applicationIcon: nil,
            namedIcon: nil,
            fallbackIcon: fallbackIcon
        )

        XCTAssertTrue(resolved === bundledIcon)
    }

    func testNetworkToolsAppResolvedApplicationIconUsesApplicationIconWhenBundledMissing() {
        let applicationIcon = NSImage(size: NSSize(width: 16, height: 16))
        let fallbackIcon = NSImage(size: NSSize(width: 16, height: 16))

        let resolved = NetworkToolsApp.resolvedApplicationIcon(
            bundledIcon: nil,
            applicationIcon: applicationIcon,
            namedIcon: nil,
            fallbackIcon: fallbackIcon
        )

        XCTAssertTrue(resolved === applicationIcon)
    }

    func testNetworkToolsAppResolvedApplicationIconUsesNamedIconWhenHigherPriorityIconsMissing() {
        let namedIcon = NSImage(size: NSSize(width: 16, height: 16))
        let fallbackIcon = NSImage(size: NSSize(width: 16, height: 16))

        let resolved = NetworkToolsApp.resolvedApplicationIcon(
            bundledIcon: nil,
            applicationIcon: nil,
            namedIcon: namedIcon,
            fallbackIcon: fallbackIcon
        )

        XCTAssertTrue(resolved === namedIcon)
    }

    func testNetworkToolsAppResolvedApplicationIconUsesFallbackWhenNoPreferredIconExists() {
        var fallbackEvaluations = 0
        let fallbackIcon = NSImage(size: NSSize(width: 16, height: 16))

        let resolved = NetworkToolsApp.resolvedApplicationIcon(
            bundledIcon: nil,
            applicationIcon: nil,
            namedIcon: nil,
            fallbackIcon: {
                fallbackEvaluations += 1
                return fallbackIcon
            }()
        )

        XCTAssertTrue(resolved === fallbackIcon)
        XCTAssertEqual(fallbackEvaluations, 1)
    }

    func testAcquireSingleInstanceLockSkipsWhenRunningUnderTests() {
        var didAttemptToOpen = false

        let outcome = NetworkToolsAppSupport.acquireSingleInstanceLock(
            environment: ["XCTestConfigurationFilePath": "/tmp/xctest"],
            bundleIdentifier: "com.example.NetworkTools",
            temporaryDirectory: "/tmp",
            processIdentifier: 123,
            openLockFile: { _, _, _ in
                didAttemptToOpen = true
                return -1
            },
            lockFile: { _, _ in 0 },
            closeFile: { _ in 0 },
            truncateFile: { _, _ in 0 },
            seekFile: { _, _, _ in 0 },
            writeString: { _, _ in }
        )

        XCTAssertEqual(outcome, .skippedForTests)
        XCTAssertFalse(didAttemptToOpen)
    }

    func testAcquireSingleInstanceLockReturnsUnavailableWhenOpenFails() {
        let outcome = NetworkToolsAppSupport.acquireSingleInstanceLock(
            environment: [:],
            bundleIdentifier: "com.example.NetworkTools",
            temporaryDirectory: "/tmp",
            processIdentifier: 123,
            openLockFile: { _, _, _ in -1 },
            lockFile: { _, _ in 0 },
            closeFile: { _ in 0 },
            truncateFile: { _, _ in 0 },
            seekFile: { _, _, _ in 0 },
            writeString: { _, _ in }
        )

        XCTAssertEqual(outcome, .lockUnavailable)
    }

    func testAcquireSingleInstanceLockDetectsExistingInstanceAndClosesFD() {
        var closedFDs: [Int32] = []

        let outcome = NetworkToolsAppSupport.acquireSingleInstanceLock(
            environment: [:],
            bundleIdentifier: "com.example.NetworkTools",
            temporaryDirectory: "/tmp",
            processIdentifier: 321,
            openLockFile: { _, _, _ in 44 },
            lockFile: { _, _ in -1 },
            closeFile: {
                closedFDs.append($0)
                return 0
            },
            truncateFile: { _, _ in 0 },
            seekFile: { _, _, _ in 0 },
            writeString: { _, _ in }
        )

        XCTAssertEqual(outcome, .existingInstanceDetected(bundleIdentifier: "com.example.NetworkTools"))
        XCTAssertEqual(closedFDs, [44])
    }

    func testAcquireSingleInstanceLockWritesPIDWhenLockAcquired() {
        var capturedPath = ""
        var didTruncate = false
        var didSeek = false
        var capturedWrite: (fd: Int32, value: String)?

        let outcome = NetworkToolsAppSupport.acquireSingleInstanceLock(
            environment: [:],
            bundleIdentifier: "com.example.NetworkTools",
            temporaryDirectory: "/tmp",
            processIdentifier: 987,
            openLockFile: { path, _, _ in
                capturedPath = path
                return 55
            },
            lockFile: { _, _ in 0 },
            closeFile: { _ in 0 },
            truncateFile: { _, _ in
                didTruncate = true
                return 0
            },
            seekFile: { _, _, _ in
                didSeek = true
                return 0
            },
            writeString: { fd, value in
                capturedWrite = (fd, value)
            }
        )

        XCTAssertEqual(outcome, .lockAcquired(fileDescriptor: 55))
        XCTAssertEqual(capturedPath, "/tmp/com.example.NetworkTools.single-instance.lock")
        XCTAssertTrue(didTruncate)
        XCTAssertTrue(didSeek)
        XCTAssertEqual(capturedWrite?.fd, 55)
        XCTAssertEqual(capturedWrite?.value, "987\n")
    }

    func testActivateExistingApplicationSkipsOpenWhenBundleURLMissing() {
        var unhideCalls = 0
        var activateCalls = 0
        var didOpen = false

        let apps: [NetworkToolsAppSupport.RunningApplicationProxy] = [
            .init(
                processIdentifier: 200,
                bundleURL: nil,
                unhide: { unhideCalls += 1 },
                activateAllWindows: { activateCalls += 1 }
            )
        ]

        let didActivate = NetworkToolsAppSupport.activateExistingApplication(
            currentProcessIdentifier: 100,
            runningApplications: apps,
            openApplication: { _ in didOpen = true }
        )

        XCTAssertTrue(didActivate)
        XCTAssertEqual(unhideCalls, 1)
        XCTAssertEqual(activateCalls, 1)
        XCTAssertFalse(didOpen)
    }

    func testActivateExistingApplicationSelectsNonCurrentProcess() {
        var openedURL: URL?
        var unhideCalls = 0
        var activateCalls = 0

        let apps: [NetworkToolsAppSupport.RunningApplicationProxy] = [
            .init(
                processIdentifier: 100,
                bundleURL: URL(fileURLWithPath: "/tmp/current.app"),
                unhide: { XCTFail("Current process should be ignored") },
                activateAllWindows: { XCTFail("Current process should be ignored") }
            ),
            .init(
                processIdentifier: 200,
                bundleURL: URL(fileURLWithPath: "/tmp/existing.app"),
                unhide: { unhideCalls += 1 },
                activateAllWindows: { activateCalls += 1 }
            )
        ]

        let didActivate = NetworkToolsAppSupport.activateExistingApplication(
            currentProcessIdentifier: 100,
            runningApplications: apps,
            openApplication: { openedURL = $0 }
        )

        XCTAssertTrue(didActivate)
        XCTAssertEqual(unhideCalls, 1)
        XCTAssertEqual(activateCalls, 1)
        XCTAssertEqual(openedURL?.path, "/tmp/existing.app")
    }

    func testActivateExistingApplicationReturnsFalseWhenNoOtherProcesses() {
        let apps: [NetworkToolsAppSupport.RunningApplicationProxy] = [
            .init(
                processIdentifier: 100,
                bundleURL: nil,
                unhide: { XCTFail("Should not be called") },
                activateAllWindows: { XCTFail("Should not be called") }
            )
        ]

        let didActivate = NetworkToolsAppSupport.activateExistingApplication(
            currentProcessIdentifier: 100,
            runningApplications: apps,
            openApplication: { _ in XCTFail("Should not be called") }
        )

        XCTAssertFalse(didActivate)
    }

    func testNetworkToolsAppEnforceSingleInstanceStoresLockFileDescriptor() {
        var storedFileDescriptor: Int32?
        var didExit = false
        var requestedBundleIdentifiers: [String] = []

        NetworkToolsApp.enforceSingleInstance(
            environment: [:],
            bundleIdentifier: "com.example.NetworkTools",
            temporaryDirectory: "/tmp",
            processIdentifier: 111,
            acquireSingleInstanceLock: { _, _, _, _, _, _, _, _, _, _ in
                .lockAcquired(fileDescriptor: 72)
            },
            runningApplicationsProvider: {
                requestedBundleIdentifiers.append($0)
                return []
            },
            openApplication: { _ in XCTFail("No existing app should be opened") },
            exitProcess: { _ in didExit = true },
            setLockFileDescriptor: { storedFileDescriptor = $0 }
        )

        XCTAssertEqual(storedFileDescriptor, 72)
        XCTAssertFalse(didExit)
        XCTAssertTrue(requestedBundleIdentifiers.isEmpty)
    }

    func testNetworkToolsAppEnforceSingleInstanceActivatesExistingInstanceAndExits() {
        var requestedBundleIdentifiers: [String] = []
        var openedURL: URL?
        var unhideCalls = 0
        var activateCalls = 0
        var exitCode: Int32?
        var storedFileDescriptor: Int32?

        NetworkToolsApp.enforceSingleInstance(
            environment: [:],
            bundleIdentifier: "com.example.NetworkTools",
            temporaryDirectory: "/tmp",
            processIdentifier: 111,
            acquireSingleInstanceLock: { _, _, _, _, _, _, _, _, _, _ in
                .existingInstanceDetected(bundleIdentifier: "com.example.NetworkTools")
            },
            runningApplicationsProvider: { bundleIdentifier in
                requestedBundleIdentifiers.append(bundleIdentifier)
                return [
                    .init(
                        processIdentifier: 222,
                        bundleURL: URL(fileURLWithPath: "/tmp/existing.app"),
                        unhide: { unhideCalls += 1 },
                        activateAllWindows: { activateCalls += 1 }
                    )
                ]
            },
            openApplication: { openedURL = $0 },
            exitProcess: { exitCode = $0 },
            setLockFileDescriptor: { storedFileDescriptor = $0 }
        )

        XCTAssertEqual(requestedBundleIdentifiers, ["com.example.NetworkTools"])
        XCTAssertEqual(unhideCalls, 1)
        XCTAssertEqual(activateCalls, 1)
        XCTAssertEqual(openedURL?.path, "/tmp/existing.app")
        XCTAssertEqual(exitCode, EXIT_SUCCESS)
        XCTAssertNil(storedFileDescriptor)
    }

    func testNetworkToolsAppEnforceSingleInstanceReturnsWhenLockUnavailable() {
        var didExit = false
        var didStoreFileDescriptor = false
        var didRequestRunningApplications = false

        NetworkToolsApp.enforceSingleInstance(
            environment: [:],
            bundleIdentifier: "com.example.NetworkTools",
            temporaryDirectory: "/tmp",
            processIdentifier: 111,
            acquireSingleInstanceLock: { _, _, _, _, _, _, _, _, _, _ in
                .lockUnavailable
            },
            runningApplicationsProvider: { _ in
                didRequestRunningApplications = true
                return []
            },
            openApplication: { _ in XCTFail("No app should be opened when lock is unavailable") },
            exitProcess: { _ in didExit = true },
            setLockFileDescriptor: { _ in didStoreFileDescriptor = true }
        )

        XCTAssertFalse(didExit)
        XCTAssertFalse(didStoreFileDescriptor)
        XCTAssertFalse(didRequestRunningApplications)
    }

    func testNetworkToolsAppEnforceSingleInstanceReturnsWhenSkippedForTests() {
        var didExit = false
        var didStoreFileDescriptor = false
        var didRequestRunningApplications = false

        NetworkToolsApp.enforceSingleInstance(
            environment: ["XCTestConfigurationFilePath": "/tmp/xctest"],
            bundleIdentifier: "com.example.NetworkTools",
            temporaryDirectory: "/tmp",
            processIdentifier: 111,
            acquireSingleInstanceLock: { _, _, _, _, _, _, _, _, _, _ in
                .skippedForTests
            },
            runningApplicationsProvider: { _ in
                didRequestRunningApplications = true
                return []
            },
            openApplication: { _ in XCTFail("No app should be opened when skipping for tests") },
            exitProcess: { _ in didExit = true },
            setLockFileDescriptor: { _ in didStoreFileDescriptor = true }
        )

        XCTAssertFalse(didExit)
        XCTAssertFalse(didStoreFileDescriptor)
        XCTAssertFalse(didRequestRunningApplications)
    }
}
