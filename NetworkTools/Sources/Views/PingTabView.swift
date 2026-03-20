import SwiftUI

struct PingTabView: View {
    @ObservedObject var viewModel: PingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Destination")
                    TextField("IPv4 address or internet hostname", text: $viewModel.destination)
                        .textFieldStyle(.roundedBorder)
                        .overlay(validationBorder(isValid: viewModel.isDestinationValid))
                        .accessibilityLabel("Ping Destination")
                        .accessibilityValue(viewModel.isDestinationValid ? "Valid" : "Invalid")
                        .accessibilityHint("Enter an IPv4 address or internet hostname.")
                }
                .frame(maxWidth: 420)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mode")
                    Toggle("Send an unlimited number of pings", isOn: $viewModel.isUnlimited)
                        .toggleStyle(.checkbox)
                        .accessibilityLabel("Send an unlimited number of pings")
                }
                .frame(maxWidth: 320)

                VStack(alignment: .leading, spacing: 6) {
                    Text("# Pings to send")
                    TextField("10", text: $viewModel.pingCountText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isUnlimited)
                        .overlay(validationBorder(isValid: viewModel.isCountValid))
                        .accessibilityLabel("Number of pings to send")
                        .accessibilityValue(
                            viewModel.isUnlimited ? "Disabled" : (viewModel.isCountValid ? "Valid" : "Invalid")
                        )
                        .accessibilityHint("Enter a number from 1 to 100.")
                }
                .frame(width: 180)

                Button(viewModel.primaryButtonLabel) {
                    viewModel.primaryAction()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isRunning && !viewModel.canStart)
                .accessibilityLabel(viewModel.isRunning ? "Stop ping" : "Start ping")
                .accessibilityHint(
                    viewModel.isRunning
                        ? "Stops the current ping operation."
                        : "Starts ping with the current destination and count."
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
