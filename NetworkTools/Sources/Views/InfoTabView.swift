import SwiftUI
#if os(macOS)
import AppKit
#endif

struct InfoTabView: View {
    @ObservedObject var viewModel: InfoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker(
                    "Network Interface",
                    selection: Binding(
                        get: { viewModel.selectedInterfaceName },
                        set: { viewModel.selectInterface($0) }
                    )
                ) {
                    ForEach(viewModel.interfaces) { interface in
                        Text("\(interface.isActive ? "🟢" : "🔴") \(interface.displayName)")
                            .accessibilityLabel("\(interface.isActive ? "Active" : "Inactive"), \(interface.displayName)")
                            .tag(interface.name)
                    }
                }
                .disabled(viewModel.interfaces.isEmpty)
                .accessibilityLabel("Network Interface Picker")
                .accessibilityHint("Select a network interface to view details.")
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
                    valueView(for: row)
                }
                .accessibilityElement(children: .combine)
                .contextMenu {
                    Button("Copy Value") {
                        copyToPasteboard(displayValueText(for: row))
                    }
                    Button("Copy Row") {
                        copyToPasteboard("\(row.label): \(displayValueText(for: row))")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func valueView(for row: DisplayRow) -> some View {
        if row.label == "Link Status" {
            linkStatusView(statusValue: row.value)
        } else {
            Text(row.value)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func linkStatusView(statusValue: String) -> some View {
        let normalized = statusValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized == "up" {
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text("Active")
            }
        } else if normalized == "down" {
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text("Inactive")
            }
        } else {
            Text(statusValue)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.trailing)
        }
    }

    private func displayValueText(for row: DisplayRow) -> String {
        guard row.label == "Link Status" else {
            return row.value
        }

        let normalized = row.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "up" {
            return "Active"
        }
        if normalized == "down" {
            return "Inactive"
        }
        return row.value
    }

    private func copyToPasteboard(_ value: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        #endif
    }
}
