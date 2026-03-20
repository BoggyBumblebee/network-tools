import SwiftUI
#if os(macOS)
import AppKit
#endif

struct OutputTextView: View {
    let text: String

    var body: some View {
        let lineCount = text.isEmpty ? 0 : text.split(whereSeparator: \.isNewline).count
        TextEditor(text: .constant(text))
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Button {
                    copyToPasteboard(text)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("Copy output")
                .disabled(text.isEmpty)
                .accessibilityLabel("Copy output")
                .accessibilityHint("Copies output text to the clipboard.")
            }
            .accessibilityLabel("Output")
            .accessibilityValue(lineCount == 0 ? "No output yet" : "\(lineCount) lines")
            .accessibilityHint("Read-only operation output.")
    }

    private func copyToPasteboard(_ value: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        #endif
    }
}
