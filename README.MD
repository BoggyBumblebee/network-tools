# Network Tools

[![Build](https://github.com/BoggyBumblebee/network-tools/actions/workflows/build.yml/badge.svg)](https://github.com/BoggyBumblebee/network-tools/actions/workflows/build.yml)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=BoggyBumblebee_network-tools&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=BoggyBumblebee_network-tools)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=BoggyBumblebee_network-tools&metric=coverage)](https://sonarcloud.io/summary/new_code?id=BoggyBumblebee_network-tools)

## About The Project

Network Tools is a native macOS app built with SwiftUI for quick, local network diagnostics.  
The project was developed with Codex.

It currently provides three tabs:

- **Info**: Inspect interface details and transfer statistics for available network interfaces.
- **Ping**: Run ping operations against an IPv4 address or hostname.
- **Port Scan**: Scan a destination host across a selected port range (or all ports).

The app is designed for direct desktop use with a simple single-window UI, keyboard-accessible controls, and test coverage for core validation and view-model behavior.

### Built With

- Swift 5.10
- SwiftUI (macOS app UI)
- XCTest (unit tests)
- Xcode / xcodebuild
- Darwin, SystemConfiguration, and IOKit frameworks

## Getting Started

### Prerequisites

- macOS 15.0 or later
- Xcode 16+ (or a compatible toolchain with `xcodebuild`)

Optional:

- `xcodegen` (only if you want to regenerate the Xcode project from `project.yml`)

### Installation

1. Clone the repository:

```bash
git clone https://github.com/BoggyBumblebee/network-tools.git
cd network-tools
```

2. Open in Xcode:

```bash
open NetworkTools.xcodeproj
```

3. Build and run from Xcode (Scheme: `NetworkTools`), or build from terminal:

```bash
xcodebuild -project NetworkTools.xcodeproj -scheme NetworkTools build
```

4. Run tests (same command style used in CI):

```bash
xcodebuild \
  -project NetworkTools.xcodeproj \
  -scheme NetworkTools \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  test
```

## Usage

1. Launch **Network Tools**.
2. Use the **Info** tab to select an interface and review hardware/address/speed/status/statistics data.
3. Use the **Ping** tab to enter a destination and run a finite or unlimited ping.
4. Use the **Port Scan** tab to scan a destination over a custom range or all ports.
5. Use copy controls/context menus in output/info areas to copy relevant values.

## Testing And Coverage

Run unit tests with coverage enabled:

```bash
xcodebuild \
  -project NetworkTools.xcodeproj \
  -scheme NetworkTools \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  test
```

Generate the SonarCloud-compatible coverage report used by CI:

```bash
curl -sSLo xccov-to-sonarqube-generic.sh \
  https://raw.githubusercontent.com/SonarSource/sonar-scanning-examples/master/swift-coverage/swift-coverage-example/xccov-to-sonarqube-generic.sh
chmod +x xccov-to-sonarqube-generic.sh
./xccov-to-sonarqube-generic.sh TestResults.xcresult > sonar-generic-coverage.xml
```

Quality target:

- Keep **overall coverage** above **80%**.
- Keep **new code coverage** above **80%**.
- PRs are validated in GitHub Actions and SonarCloud.

## Roadmap

- [ ] Add export options for Ping and Port Scan output.
- [ ] Add richer interface detail fallback handling across more hardware types.
- [ ] Expand automated tests (including more service-level coverage).
- [ ] Add optional history/log persistence for recent runs.

## Contributing

Contributions are welcome.

1. Fork the repo.
2. Create a branch for your change.
3. Make focused changes with tests where appropriate.
4. Open a pull request with a clear description of behavior changes.

## License

Distributed under the MIT License. See [LICENSE.md](LICENSE.md) for details.

## Contact

Maintainer: **BoggyBumblebee**  
Project URL: https://github.com/BoggyBumblebee/network-tools  
Issues: https://github.com/BoggyBumblebee/network-tools/issues

## Acknowledgments

- Apple Swift and SwiftUI documentation
- Apple networking/system frameworks (`Darwin`, `SystemConfiguration`, `IOKit`)
- macOS developer tooling (`xcodebuild`, XCTest)
