import SwiftUI
#if os(macOS)
import AppKit
#endif

struct OutputTextView: View {
    let text: String
    private var hasCopyableOutput: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let lineCount = text.isEmpty ? 0 : text.split(whereSeparator: \.isNewline).count
        Group {
            #if os(macOS)
            MacReadOnlyOutputTextView(text: text)
            #else
            TextEditor(text: .constant(text))
                .font(.system(.body, design: .monospaced))
            #endif
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                Button {
                    copyToPasteboard(text)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(hasCopyableOutput ? .secondary : .tertiary)
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("Copy output")
                .disabled(!hasCopyableOutput)
                .accessibilityLabel("Copy output")
                .accessibilityValue(hasCopyableOutput ? "Enabled" : "Disabled")
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

#if os(macOS)
private struct MacReadOnlyOutputTextView: NSViewRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.configure(scrollView: scrollView, textView: textView)

        DispatchQueue.main.async {
            Self.updateVerticalScroller(for: scrollView, textView: textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy

        DispatchQueue.main.async {
            Self.updateVerticalScroller(for: scrollView, textView: textView)
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    private static func updateVerticalScroller(for scrollView: NSScrollView, textView: NSTextView) {
        guard let textContainer = textView.textContainer else { return }
        textView.layoutManager?.ensureLayout(for: textContainer)

        let usedHeight = textView.layoutManager?.usedRect(for: textContainer).height ?? 0
        let contentHeight = ceil(usedHeight + (textView.textContainerInset.height * 2))
        let visibleHeight = scrollView.contentView.bounds.height
        scrollView.hasVerticalScroller = contentHeight > (visibleHeight + 1)
    }

    final class Coordinator {
        private var frameObserver: NSObjectProtocol?
        private var boundsObserver: NSObjectProtocol?
        private weak var scrollView: NSScrollView?
        private weak var textView: NSTextView?

        func configure(scrollView: NSScrollView, textView: NSTextView) {
            cleanup()

            self.scrollView = scrollView
            self.textView = textView

            scrollView.contentView.postsFrameChangedNotifications = true
            scrollView.contentView.postsBoundsChangedNotifications = true

            frameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.recalculateScrollerVisibility()
            }

            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.recalculateScrollerVisibility()
            }
        }

        func cleanup() {
            if let frameObserver {
                NotificationCenter.default.removeObserver(frameObserver)
            }
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
            frameObserver = nil
            boundsObserver = nil
        }

        deinit {
            cleanup()
        }

        private func recalculateScrollerVisibility() {
            guard let scrollView, let textView else { return }
            MacReadOnlyOutputTextView.updateVerticalScroller(for: scrollView, textView: textView)
        }
    }
}
#endif
