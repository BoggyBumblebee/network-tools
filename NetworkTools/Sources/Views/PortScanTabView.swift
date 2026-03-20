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
                }
                .frame(width: 100)

                VStack(alignment: .leading, spacing: 6) {
                    Text("To")
                    TextField("1024", text: $viewModel.toPortText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.scanAllPorts)
                        .accessibilityLabel("To port")
                }
                .frame(width: 100)
                .overlay(validationBorder(isValid: viewModel.isRangeValid))

                Button(viewModel.primaryButtonLabel) {
                    viewModel.primaryAction()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isRunning && !viewModel.canStart)
                .accessibilityLabel("Scan Action")
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
