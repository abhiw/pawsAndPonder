import SwiftUI

/// A minutes value that can be typed or stepped. Typed input is limited to digits, and the
/// bound value only ever holds a number inside `range`.
struct MinutesField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .focused($isFocused)
                    .onSubmit(commit)
                Text("min")
                    .foregroundStyle(.secondary)
                Stepper("", value: $value, in: range)
                    .labelsHidden()
            }
        }
        .onAppear { text = String(value) }
        .onChange(of: text) { filterInput() }
        .onChange(of: value) { text = String(value) }
        .onChange(of: isFocused) { if !isFocused { commit() } }
        .onDisappear(perform: commit)
    }

    /// The value itself is only updated in `commit`, so a running timer never sees half-typed
    /// numbers like the `1` in `180`.
    private func filterInput() {
        let digits = Self.digitsOnly(text, maxLength: String(range.upperBound).count)
        if digits != text {
            text = digits
        }
    }

    private func commit() {
        value = Self.committedValue(from: text, current: value, range: range)
        text = String(value)
    }

    /// Keeps only ASCII digits, which also cleans up pasted text, up to `maxLength` of them.
    static func digitsOnly(_ text: String, maxLength: Int) -> String {
        String(text.filter { ("0"..."9").contains($0) }.prefix(maxLength))
    }

    /// The typed number clamped to `range`, or the current value if nothing was typed.
    static func committedValue(from text: String, current: Int, range: ClosedRange<Int>) -> Int {
        let number = Int(text) ?? current
        return min(max(number, range.lowerBound), range.upperBound)
    }
}
