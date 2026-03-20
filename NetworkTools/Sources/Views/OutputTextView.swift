import SwiftUI

struct OutputTextView: View {
    let text: String

    var body: some View {
        let lineCount = text.isEmpty ? 0 : text.split(whereSeparator: \.isNewline).count
        TextEditor(text: .constant(text))
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Output")
            .accessibilityValue(lineCount == 0 ? "No output yet" : "\(lineCount) lines")
            .accessibilityHint("Read-only operation output.")
    }
}
