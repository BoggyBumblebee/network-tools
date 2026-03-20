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
                    TextField("4", text: $viewModel.pingCountText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isUnlimited)
                        .overlay(validationBorder(isValid: viewModel.isCountValid))
                        .accessibilityLabel("Number of pings to send")
                }
                .frame(width: 180)

                Button(viewModel.primaryButtonLabel) {
                    viewModel.primaryAction()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isRunning && !viewModel.canStart)
                .accessibilityLabel("Ping Action")
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
