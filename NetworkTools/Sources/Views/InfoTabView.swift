import SwiftUI

struct InfoTabView: View {
    @ObservedObject var viewModel: InfoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Interface")
                    .font(.headline)
                    .onTapGesture(count: 5) {
                        viewModel.toggleDebugDetails()
                    }
                Picker(
                    "Network Interface",
                    selection: Binding(
                        get: { viewModel.selectedInterfaceName },
                        set: { viewModel.selectInterface($0) }
                    )
                ) {
                    ForEach(viewModel.interfaces) { interface in
                        Text(interface.displayName).tag(interface.name)
                    }
                }
                .disabled(viewModel.interfaces.isEmpty)
                .accessibilityLabel("Network Interface Picker")
            }

            if let emptyMessage = viewModel.emptyMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Info Empty State")
                }
                Spacer()
            } else {
                HStack(alignment: .top, spacing: 12) {
                    GroupBox("Interface Information") {
                        KeyValueListView(rows: viewModel.interfaceRows)
                    }

                    GroupBox("Transfer Statistics") {
                        KeyValueListView(rows: viewModel.statisticsRows)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(16)
    }
}

private struct KeyValueListView: View {
    let rows: [DisplayRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                HStack {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.value)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}
