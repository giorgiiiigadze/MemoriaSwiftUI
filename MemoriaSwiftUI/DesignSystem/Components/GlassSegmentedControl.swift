import SwiftUI

/// A compact segmented control that matches the app's Liquid Glass chrome. The selected
/// segment rides a sliding pill — a real `.glassEffect` capsule on iOS 26, a raised surface
/// on older systems — over a subtle glass track, so it reads as native iOS 26 chrome rather
/// than the boxy stock `.segmented` picker.
///
/// Segments share an equal width (measured from the widest label) so the pill keeps a steady
/// size as it slides, the way UIKit's segmented control does.
struct GlassSegmentedControl<Value: Hashable>: View {
    let segments: [Value]
    let title: (Value) -> String
    @Binding var selection: Value

    @Namespace private var pill
    @State private var segmentWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments, id: \.self) { value in
                segment(value)
            }
        }
        .padding(Spacing.xxs)
        .background(track)
        // Measure the widest label once so every segment gets that width.
        .background(alignment: .leading) { widthProbe }
    }

    private func segment(_ value: Value) -> some View {
        let isSelected = value == selection
        return Text(title(value))
            .font(Typography.font(.sm, weight: .semiBold))
            .foregroundStyle(isSelected ? Colors.textPrimary : Colors.textSecondary)
            .lineLimit(1)
            .padding(.vertical, Spacing.xs)
            .frame(width: segmentWidth > 0 ? segmentWidth : nil)
            .background {
                if isSelected {
                    selectedPill.matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(.capsule)
            .onTapGesture {
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.12)) {
                    selection = value
                }
            }
    }

    @ViewBuilder
    private var selectedPill: some View {
        let shape = Capsule(style: .continuous)
        if #available(iOS 26, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(Colors.glassPanelTint).interactive(), in: shape)
        } else {
            shape.fill(Colors.surfaceRaised)
        }
    }

    private var track: some View {
        Capsule(style: .continuous)
            .fill(Colors.glassChromeFallback)
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Colors.glassChromeBorder.opacity(0.5), lineWidth: 1)
            }
    }

    /// Renders every label off-screen, records the widest, and pads it so no segment ever clips.
    private var widthProbe: some View {
        ZStack {
            ForEach(segments, id: \.self) { value in
                Text(title(value))
                    .font(Typography.font(.sm, weight: .semiBold))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear.onAppear { segmentWidth = geo.size.width + Spacing.xl }
            }
        }
        .hidden()
    }
}

#Preview {
    struct Demo: View {
        @State private var choice = "Recent"
        var body: some View {
            ZStack {
                Colors.background.ignoresSafeArea()
                GlassSegmentedControl(
                    segments: ["Recent", "Oldest"],
                    title: { $0 },
                    selection: $choice
                )
            }
        }
    }
    return Demo()
}
