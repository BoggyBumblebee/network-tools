# Network Tools — Specification (v1.2)

## 1. Document Control

**Document Name:** SPEC.MD  
**Document Version:** 1.2  
**Last Updated:** 2026-03-20  
**Target Artifact:** macOS SwiftUI application  
**Application Name:** Network Tools  
**Minimum Platform:** macOS 15  
**Device Support:** macOS desktop/laptop only  
**State Management:** Stateless application  
**Code Signing / Deployment:** Developer-signed  

## 2. Purpose

This document defines the functional and non-functional requirements for a macOS-only SwiftUI application named **Network Tools**. The application will provide a unified interface with three tabs:

1. **Info** — inspect network interface information and transfer statistics.
2. **Ping** — execute continuous or fixed-count ICMP-style ping operations against an IPv4 address or internet hostname.
3. **Port Scan** — scan all ports or a user-specified port range on an IPv4 address or internet hostname and report open ports.

The application is intended to be stateless and does not persist user-entered data or results between launches.

## 3. Scope

### In Scope
- Native macOS SwiftUI application.
- Developer-signed macOS app.
- Native Swift networking implementation using sockets and/or Network framework.
- Display of interface metadata and transfer statistics.
- Ping workflow with validation, start/stop behavior, and streaming results.
- TCP port scanning workflow with validation, start/stop behavior, and streaming results.
- Accessibility, diagnostics, error handling, responsiveness, and testability.

### Out of Scope
- iPhone or iPad support.
- Persistent storage of settings, history, or results.
- Export features.
- Authentication or user accounts.
- Advanced protocol analysis beyond the described feature set.
- Reporting closed ports in the Port Scan tab.

## 4. Assumptions and Constraints

1. The app minimum deployment target is **macOS 15**.
2. The application must be implemented using **SwiftUI**.
3. Networking functionality must use a **native Swift implementation** based on sockets and/or the Network framework; wrapping shell commands such as `ping` is not acceptable.
4. The application is intended for **developer-signed macOS deployment** rather than App Sandbox deployment.
5. Where macOS does not expose interface properties such as vendor, model, transport speed, or link speed, the UI must display **`Unavailable`**.
6. Ping and port scan outputs must be presented in a **raw terminal-style text format**.
7. Long-running operations must remain **responsive and cancellable**.
8. Port Scan results must report **open ports only**.
9. The app shall not require root/admin elevation for normal operation.

## 5. High-Level Product Behavior

The application will open on the **Info** tab by default. The user can switch between tabs at any time. Ping and Port Scan operations must continue running if the user navigates away from those tabs, unless explicitly stopped by the user or terminated by an error condition.

The app does not store state across launches. Any currently displayed values or operation results are session-only.

## 6. Architecture Overview

The implementation must follow a clean separation of concerns.

### Recommended Layers
- **UI Layer**: SwiftUI views and view models.
- **Domain/Service Layer**: network interface inspection, ping engine, and port scanning engine.
- **System Integration Layer**: interfaces to sockets, Network framework, SystemConfiguration, NetworkExtension, or other permitted Apple APIs required by the developer-signed deployment model.

### Recommended Design Principles
- MVVM or equivalent SwiftUI-friendly architecture.
- All long-running operations must be asynchronous.
- UI updates must occur on the main actor.
- Background work must be cancellable.
- Service interfaces must be testable via dependency injection.

## 7. Functional Requirements

---

## 7.1 Application Shell and Navigation

### Requirements
1. The application shall present a tab-based interface with exactly three tabs:
   - **Info**
   - **Ping**
   - **Port Scan**
2. The application shall open on the **Info** tab by default.
3. The application shall support macOS desktop usage only.
4. The application shall not require data persistence.

### Acceptance Criteria
- On launch, the user lands on the Info tab without prior interaction.
- The three tabs are always visible and selectable.
- Switching tabs does not relaunch the app state or clear active in-memory operations except where explicitly required.

---

## 7.2 Tab 1 — Info

### Objective
Provide network interface information for a selected network interface and refresh the displayed information every 15 seconds while the Info tab is active.

### UI Requirements
1. The Info tab shall contain a **Picker** listing available network interfaces on the macOS device.
2. The selected interface in the Picker shall determine the content shown in the detail panels.
3. Below the Picker, the UI shall present two side-by-side panels:
   - **Interface Information** (left)
   - **Transfer Statistics** (right)
4. The Info tab shall be the default tab shown on launch.

### Data Requirements
When a network interface is selected, the **Interface Information** panel shall display:
- Hardware Address
- IP Address
- Link Speed
- Transport Speed
- Link Status
- Vendor
- Model

When a network interface is selected, the **Transfer Statistics** panel shall display:
- Sent Packages
- Sent Data
- Send Errors
- Received Packages
- Received Data
- Received Errors
- Collisions

### Refresh Requirements
1. While the user is viewing the Info tab, the selected interface details shall refresh every **15 seconds** (acceptable interval: **14 to 16 seconds**).
2. While the user is not viewing the Info tab, this refresh cycle does not need to run.
3. When the user returns to the Info tab, a refresh shall occur within **1 second**.
4. When a different interface is selected in the Picker, both panels shall update to the newly selected interface.

### Best-Effort Data Exposure Rule
If macOS does not expose a requested value for the selected interface, the app shall display **`Unavailable`** for that field.

### Empty/Unavailable State Requirements
1. If no network interfaces are available, the Picker shall reflect that state and the detail panels shall show an informative empty-state message.
2. If interface statistics cannot be read, the relevant fields shall show `Unavailable` rather than causing the app to fail.

### Acceptance Criteria
- Selecting a different interface updates both panels.
- While the Info tab is open, refresh occurs at 15-second intervals with acceptable variance of 14 to 16 seconds.
- Returning to the Info tab triggers refresh within 1 second.
- While the user is on another tab, periodic refresh for the Info tab is not required.
- Unavailable fields render as `Unavailable`.

---

## 7.3 Tab 2 — Ping

### Objective
Allow the user to execute a ping operation against an IPv4 address or internet hostname using a native Swift implementation.

### Input Requirements
1. The Ping tab shall contain a text input for an **IPv4 address or internet hostname**.
2. The UI shall validate the destination input before allowing the ping to start.
3. Invalid input shall disable the **Ping** button.

### Valid Input Rules
The destination field shall accept either:
- A syntactically valid **IPv4 address**, or
- A syntactically valid **internet hostname**

The spec does not require IPv6 support.

### Count Configuration Requirements
1. The Ping tab shall provide:
   - A text box labeled **`# Pings to send`**, and
   - A radio button or equivalent mutually exclusive control labeled **`Send an unlimited number of pings`**.
2. On first launch of a session, fixed-count mode shall be selected by default with value **4**.
3. If a fixed count is selected, the count must be:
   - numeric,
   - greater than 0,
   - less than or equal to 100.
4. If the count input is invalid, the **Ping** button shall be disabled.
5. If unlimited mode is selected, fixed-count validation shall not block the action.

### Execution Requirements
1. The primary action button shall initially display **`Ping`**.
2. When a ping operation starts, the button text shall change to **`Stop`**.
3. When the button is pressed while displaying **`Stop`**, the active ping operation shall stop and the button text shall revert to **`Ping`**.
4. The ping operation shall stream results into a large text output box.
5. The text output box shall support selecting and copying its contents.
6. If the user changes tabs while a ping is running, the ping operation shall continue.
7. If a fixed count is selected, the ping operation shall automatically stop after the requested number of pings and the button shall revert to **`Ping`**.
8. If unlimited mode is selected, the ping operation shall continue until the user stops it or an unrecoverable error occurs.
9. A second Ping start request while Ping is already running shall be rejected by disabling start controls.

### Runtime Defaults
1. Ping interval shall default to **1 second** between probes.
2. Per-probe timeout shall default to **2 seconds**.
3. Destination resolution shall occur before the first probe is sent.
4. If ICMP probe creation is not permitted by platform policy, the run shall fail immediately with a clear message that ICMP is unavailable in the current environment.

### Output Requirements
1. Results shall be displayed in a **raw terminal-style text format**.
2. Output must include a clear start of operation and line-by-line progress.
3. Output must include a termination message indicating one of the following where applicable:
   - completed requested count,
   - stopped by user,
   - failed to resolve host,
   - permission or networking error,
   - timeout or other operational failure.

### Validation Requirements
The **Ping** button shall only be enabled when:
- destination input is valid, and
- either unlimited mode is selected, or the ping count input is valid.

### Acceptance Criteria
- Invalid destination disables the Ping button.
- Invalid count disables the Ping button when fixed-count mode is selected.
- Starting a ping changes the button to Stop.
- Stopping the ping halts new output and changes the button back to Ping.
- Output remains visible and copyable.
- Ping continues when the user switches tabs.
- Fixed-count default is 4 on first launch.
- Maximum fixed count of 100 is accepted; 101 is rejected.

---

## 7.4 Tab 3 — Port Scan

### Objective
Allow the user to scan a destination host for open TCP ports using a native Swift implementation.

### Input Requirements
1. The Port Scan tab shall contain a text input for an **IPv4 address or internet hostname**.
2. The UI shall validate the destination input before allowing the scan to start.
3. Invalid input shall disable the **Scan** button.

### Port Range Requirements
1. The Port Scan tab shall support scanning:
   - all ports from **1 to 65535**, or
   - a user-specified inclusive range.
2. The UI shall provide two text fields labeled **`From`** and **`To`** for the range.
3. On first launch of a session, range mode shall be selected by default with **From = 1** and **To = 1024**.
4. The range inputs shall be validated such that:
   - both are numeric,
   - both are within **1 to 65535**, and
   - `From` is less than or equal to `To`.
5. If the selected scan mode is "all ports," the custom range validation shall not block the action.
6. If range mode is selected and either field is invalid, the **Scan** button shall be disabled.

### Execution Requirements
1. The primary action button shall initially display **`Scan`**.
2. When a scan starts, the button text shall change to **`Stop`**.
3. When the button is pressed while displaying **`Stop`**, the active scan shall stop and the button text shall revert to **`Scan`**.
4. The port scan shall run with **bounded concurrency** and must remain responsive and cancellable.
5. The scan shall continue if the user moves to another tab.
6. The scan shall stream results to a large text output box.
7. The text output box shall support selecting and copying its contents.
8. A second Port Scan start request while a scan is already running shall be rejected by disabling start controls.

### Runtime Defaults
1. Port scan connection timeout shall default to **750 milliseconds** per port.
2. The scanning engine shall cap concurrent in-flight connection attempts at **256**.
3. Progress output shall be emitted at least every **250 ports attempted**.
4. Timeout and connection-refused outcomes shall be treated as non-open ports and shall not be emitted as per-port errors in the main results stream.

### Reporting Requirements
1. The scan shall report **open ports only**.
2. Results shall be displayed in a **raw terminal-style text format**.
3. The output must include:
   - scan target,
   - scanned range,
   - progress messages where appropriate,
   - open port findings,
   - final completion or stop summary.
4. The output does not need to list closed ports.

### Validation Requirements
The **Scan** button shall only be enabled when:
- destination input is valid, and
- either all-ports mode is selected, or the range inputs are valid.

### Acceptance Criteria
- Invalid destination disables the Scan button.
- Invalid range disables the Scan button when range mode is selected.
- Starting a scan changes the button to Stop.
- Stopping the scan halts additional scan activity and changes the button back to Scan.
- Output remains visible and copyable.
- Scan continues when the user switches tabs.
- Only open ports are reported.
- Default range mode starts at 1-1024 on first launch.
- Full-range scans remain responsive and cancellable while honoring the concurrency cap.

## 8. Input Validation Rules

### 8.1 Host Validation
The app shall validate destination strings before allowing Ping or Port Scan operations.

### Accepted Forms
- IPv4 dotted-quad addresses.
- Internet hostnames composed of valid hostname labels.
- Punycode hostnames (for example, labels beginning with `xn--`) are accepted as standard ASCII hostnames.

### Rejected Forms
- Empty input.
- Whitespace-only input.
- Malformed IPv4 addresses.
- Malformed hostname strings.
- Hostnames with underscore characters (`_`).
- Hostnames whose total length exceeds 253 characters.
- Labels longer than 63 characters, or labels beginning/ending with `-`.

### Notes
- Validation will be syntactic only before execution.
- DNS resolution errors discovered at runtime shall be presented in the output area and/or inline UI state.
- A trailing `.` in a hostname will not be accepted by validation.

### 8.2 Numeric Validation
- Ping count must be an integer in the range 1 to 100 inclusive.
- Port numbers must be integers in the range 1 to 65535 inclusive.
- The app shall prevent or clearly reject invalid non-numeric input.

## 9. Long-Running Task Behavior

### General Requirements
1. Ping and Port Scan operations shall be independent of tab visibility once started.
2. The app shall remain responsive while operations are running.
3. The app shall allow the user to stop an operation explicitly.
4. Starting a second operation of the same type while one is already running shall be disallowed.
5. The app shall allow one Ping operation and one Port Scan operation to run simultaneously.

### Cancellation Requirements
- Cancellation shall be cooperative and timely.
- UI controls shall reflect cancellation status correctly.
- Output shall include a final line indicating user-initiated stop when applicable.
- Stop requests shall transition UI state from `Stop` to `Ping` or `Scan` within **1 second**.

## 10. UI/UX Requirements

### General Layout
- Use a clean macOS-native SwiftUI design.
- Prefer resizable layouts appropriate to desktop usage.
- Avoid cramped controls.
- Ensure text outputs are readable in larger windows.

### Text Output Areas
- Ping and Port Scan output areas shall support text selection and copy.
- Text must preserve line breaks and terminal-style formatting.
- Output boxes must support scrolling for long-running sessions.
- Each output area shall retain at most **10,000 lines** or **1 MiB** of text, whichever limit is reached first.
- When retention limits are exceeded, the oldest lines shall be truncated and a visible truncation notice shall be appended.

### Button States
- Buttons shall clearly indicate enabled/disabled state.
- Buttons shall change label appropriately between `Ping`/`Stop` and `Scan`/`Stop`.

### Feedback
- Invalid inputs must be visually apparent.
- Runtime errors must be visible to the user in a non-destructive way.
- Empty states must be clear and human-readable.

## 11. Accessibility Requirements

The application shall include accessibility support as a first-class requirement.

### Required Accessibility Behaviors
1. All controls shall have meaningful accessibility labels.
2. Tab names shall be exposed correctly to assistive technologies.
3. Form fields shall have associated labels.
4. The app shall support keyboard navigation across all controls.
5. Text contrast shall be sufficient in supported appearance modes.
6. Dynamic resizing and standard macOS text accessibility behavior must not break layout.
7. Output areas shall be selectable and accessible to screen readers as practical for large text content.
8. Status changes such as start/stop and validation failures must be communicated accessibly.

## 12. Error Handling Requirements

### General Principles
- Fail gracefully.
- Never crash due to unavailable system information, unreachable hosts, invalid user input, or task cancellation.
- Surface human-readable error information.

### Info Tab Errors
- If interface information cannot be read, show `Unavailable` for the affected field(s).
- If statistics are unavailable, show `Unavailable` for the affected field(s).

### Ping Errors
The system must handle and report cases such as:
- invalid destination format,
- host resolution failure,
- timeout,
- ICMP socket/probe creation not permitted in the current runtime context,
- permission limitations,
- network unavailable,
- cancellation.

### Port Scan Errors
The system must handle and report cases such as:
- invalid destination format,
- host resolution failure,
- invalid range,
- network unavailable,
- cancellation,
- socket creation or connection failure.

Timeout or connection-refused outcomes for individual ports are expected outcomes and must not be treated as fatal scan errors.

## 13. Logging and Diagnostics

The application shall include diagnostics suitable for development and support.

### Requirements
1. Internal operations must emit structured logs for key events.
2. Logs must include start, stop, completion, and error conditions for Ping and Port Scan.
3. Logs must avoid exposing unnecessary sensitive data.
4. Logging must not degrade UI responsiveness.
5. Debug logging verbosity may vary by build configuration.

### Recommended Logged Events
- App launch.
- Interface enumeration and refresh failures.
- Ping start/stop/completion/error.
- Port scan start/stop/completion/error.
- Validation failures where useful in debug builds.

## 14. Performance Requirements

### General
1. The application shall remain responsive during all supported operations.
2. UI updates shall not block the main thread with network work.
3. Info tab refreshes shall not create visible UI stutter.

### Ping
- Output must appear incrementally with minimal lag.
- Unlimited ping must be sustainable without unbounded memory growth and shall comply with output retention limits defined in Section 10.

### Port Scan
- Scanning approach is implementation-defined but must be responsive and cancellable.
- The scanning engine shall use bounded concurrency and enforce the cap defined in Section 7.4 Runtime Defaults.
- Large-range scans, including 1–65535, must not freeze the UI.

## 15. Security and Deployment Requirements

1. The application shall target a developer-signed macOS deployment model and is not required to operate within the App Sandbox.
2. The implementation may use APIs and entitlements appropriate for a developer-signed macOS application, subject to platform security and user-consent requirements.
3. The app shall not require elevated privileges for normal use unless explicitly unavoidable and documented.
4. The app shall not depend on private entitlements.
5. If ICMP functionality is blocked by OS security policy, the app shall emit a clear runtime error and remain otherwise functional.
6. If certain low-level operations are restricted by macOS security policy, entitlements, or runtime permissions, the app shall fail gracefully and surface an understandable message.
7. No persistent storage of network data is required.

## 16. Data and State Management

### Stateless Requirement
- The application shall not persist user inputs, selected tab, previous results, or interface snapshots across launches.
- In-memory state is allowed for the active session.

### Session Behavior
- Ping results and scan results may remain visible while the app remains open.
- Relaunching the app resets all state.

## 17. Recommended Technical Implementation Notes

These are guidance notes, not hard UI requirements unless adopted by the implementation team.

### Info Tab
- Enumerate interfaces using supported system APIs.
- Obtain counters and interface details via best-effort mechanisms compatible with developer-signed macOS deployment.
- Normalize unavailable fields to `Unavailable` at the view-model boundary.

### Ping Tab
- Implement ping using native Swift network primitives and asynchronous task handling.
- Resolve hostnames before sending packets.
- Provide streaming output lines to the UI.
- Maintain ping activity independent of tab visibility.
- Use a 1-second interval and 2-second timeout by default.
- If ICMP setup fails due to runtime policy, fail fast with explicit user-facing output.

### Port Scan Tab
- Implement TCP connect-based scanning for open-port detection.
- Use bounded concurrency with a default cap of 256.
- Stream discovered open ports to the output area as they are found.
- Maintain scan activity independent of tab visibility.
- Use a default connect timeout of 750 ms per port.

## 18. Test Requirements

Testing is required.

### 18.1 Unit Tests
The project shall include unit tests for at least:
- destination validation,
- ping count validation,
- port range validation,
- view model state transitions for start/stop behavior,
- formatting and fallback behavior for unavailable interface fields,
- output retention truncation behavior,
- single-operation guard behavior (no duplicate Ping/Scan starts).

### 18.2 Integration / Service Tests
Include tests for:
- host resolution logic,
- cancellation behavior,
- incremental output handling,
- bounded-concurrency scan coordination,
- port timeout handling,
- ICMP-unavailable error-path behavior.

### 18.3 UI Tests
The project must include UI tests covering:
- default launch to Info tab,
- enabled/disabled state of Ping button under valid/invalid inputs,
- enabled/disabled state of Scan button under valid/invalid inputs,
- button label changes during operation,
- tab switching while operations continue,
- default Ping value (4),
- default Port Scan range mode values (1 to 1024).

### 18.4 Manual Test Scenarios
At minimum, verify:
1. Launch opens Info tab.
2. Interface selection updates both panels.
3. Info tab refreshes every 15 seconds while active (acceptable interval: 14 to 16 seconds) and refreshes within 1 second when returning to the tab.
4. Ping with valid IPv4 address succeeds or fails gracefully.
5. Ping with valid hostname succeeds or fails gracefully.
6. Ping invalid input disables action.
7. Fixed-count ping auto-stops and resets button state.
8. Unlimited ping continues until user stops it.
9. Ping continues while switching tabs.
10. Port scan invalid destination disables action.
11. Port scan invalid range disables action.
12. Port scan reports only open ports.
13. Port scan continues while switching tabs.
14. Stop action cancels active scan responsively.
15. Copying text from output areas works.
16. Accessibility labels and keyboard navigation function correctly.
17. Ping count of 100 is accepted; 101 is rejected.
18. Full-range scan remains responsive and can be stopped quickly.
19. Output truncation appears after retention limits are exceeded.

## 19. Acceptance Summary

The implementation will be considered aligned with this specification when:
- The app is a macOS 15+ SwiftUI application.
- It opens on the Info tab.
- The Info tab presents selectable interfaces and two detail panels with 15-second refresh while active (acceptable interval: 14 to 16 seconds), and refreshes within 1 second when returning to the tab.
- Unavailable interface fields display `Unavailable`.
- The Ping tab validates input, supports fixed or unlimited ping, uses default count 4, supports up to count 100, streams terminal-style output, supports copy, and continues across tab changes.
- The Port Scan tab validates input, supports all-ports or range-based scanning, defaults to range 1-1024, reports open ports only, enforces bounded concurrency, streams terminal-style output, supports copy, and continues across tab changes.
- Long-running work is responsive and cancellable.
- Output retention limits are enforced without unbounded memory growth.
- The app is developer-signed and fails gracefully under API, entitlement, or permission limitations.
- Accessibility, logging, error handling, and test requirements are addressed.

## 20. Open Implementation Considerations

The following are intentionally left to the implementation team unless later constrained by a follow-up specification:
- Exact visual styling beyond platform-native clarity.
- Exact output line formatting, provided it remains raw terminal-style and readable.
- Precise internal service decomposition and package structure.

## 21. Version 1.2 Delta

Changes introduced in v1.2:
- Added explicit document version metadata and update date.
- Resolved ping-count ambiguity by defining valid fixed count range as 1-100 inclusive.
- Added first-launch defaults: Ping fixed-count value 4; Port Scan range mode 1-1024.
- Added deterministic runtime defaults for Ping (1 second interval, 2 second timeout).
- Added deterministic runtime defaults for Port Scan (750 ms timeout, concurrency cap 256, progress cadence).
- Made duplicate operation behavior explicit: same-type concurrent starts are disallowed.
- Made cross-feature concurrency explicit: one Ping and one Port Scan may run simultaneously.
- Added explicit output retention limits (10,000 lines or 1 MiB per output area).
- Clarified ICMP-unavailable behavior and non-fatal per-port timeout/refusal handling.
- Expanded test expectations to cover new defaults, limits, and error paths.
- Added explicit Info refresh tolerance while active (14 to 16 seconds around the 15-second target).
- Added explicit return-to-Info refresh SLA (within 1 second).
