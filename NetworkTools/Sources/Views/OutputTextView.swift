import SwiftUI

struct OutputTextView: View {
    let text: String

    var body: some View {
        TextEditor(text: .constant(text))
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Output")
    }
}
