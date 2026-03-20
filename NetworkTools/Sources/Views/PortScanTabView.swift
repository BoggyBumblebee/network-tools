import SwiftUI

struct PortScanTabView: View {
    @ObservedObject var viewModel: PortScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Destination")
                    TextField("IPv4 address or internet hostname", text: $viewModel.destination)
                        .textFieldStyle(.roundedBorder)
                        .overlay(validationBorder(isValid: viewModel.isDestinationValid))
                        .accessibilityLabel("Scan Destination")
                        .accessibilityValue(viewModel.isDestinationValid ? "Valid" : "Invalid")
                        .accessibilityHint("Enter an IPv4 address or internet hostname.")
                }
                .frame(maxWidth: 420)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Scan Mode")
                    Toggle("Scan all ports (1-65535)", isOn: $viewModel.scanAllPorts)
                        .toggleStyle(.checkbox)
                        .accessibilityLabel("Scan all ports")
                }
                .frame(maxWidth: 220)

                VStack(alignment: .leading, spacing: 6) {
                    Text("From")
                    TextField("1", text: $viewModel.fromPortText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.scanAllPorts)
                        .accessibilityLabel("From port")
                        .accessibilityValue(viewModel.scanAllPorts ? "Disabled" : viewModel.fromPortText)
                        .accessibilityHint("Enter the first port in range.")
                }
                .frame(width: 100)

                VStack(alignment: .leading, spacing: 6) {
                    Text("To")
                    TextField("1024", text: $viewModel.toPortText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.scanAllPorts)
                        .accessibilityLabel("To port")
                        .accessibilityValue(viewModel.scanAllPorts ? "Disabled" : viewModel.toPortText)
                        .accessibilityHint("Enter the last port in range.")
                }
                .frame(width: 100)
                .overlay(validationBorder(isValid: viewModel.isRangeValid))

                Button(viewModel.primaryButtonLabel) {
                    viewModel.primaryAction()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isRunning && !viewModel.canStart)
                .accessibilityLabel(viewModel.isRunning ? "Stop scan" : "Start scan")
                .accessibilityHint(
                    viewModel.isRunning
                        ? "Stops the current port scan."
                        : "Starts scanning with the current destination and range."
                )
            }

            GroupBox("Output") {
                OutputTextView(text: viewModel.outputText)
                    .frame(minHeight: 380)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
    }

    @ViewBuilder
    private func validationBorder(isValid: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(isValid ? Color.clear : Color.red.opacity(0.8), lineWidth: 1)
    }
}
