import SwiftUI

/// A BeReal-style pill segmented control: a dark capsule track with a lighter capsule sliding
/// under the selected segment. Sizes to its content (segments hug their labels) rather than
/// stretching full width.
struct SegmentedControl<Value: Hashable>: View {
    struct Segment: Identifiable {
        let value: Value
        let label: String
        var id: Value { value }
    }

    let options: [Segment]
    @Binding var selection: Value

    @Namespace private var namespace

    init(options: [(value: Value, label: String)], selection: Binding<Value>) {
        self.options = options.map { Segment(value: $0.value, label: $0.label) }
        self._selection = selection
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(Typography.font(.body, weight: .semiBold))
                        .foregroundStyle(isSelected ? Colors.textPrimary : Colors.textSecondary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.xs)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Colors.surfaceRaised)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xxs)
        .background(Colors.surface, in: Capsule())
    }
}

#Preview {
    struct Demo: View {
        @State private var selection = 0
        var body: some View {
            SegmentedControl(
                options: [(0, "All drops"), (1, "My drops")],
                selection: $selection
            )
        }
    }
    return Demo()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Colors.background)
}
