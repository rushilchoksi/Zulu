import SwiftUI

/// A draggable timeline that shifts every clock in the panel forward or back.
/// Snaps to 15-minute steps, with a magnet at "now".
struct TimeScrubber: View {

    @Binding var offset: TimeInterval

    /// Half-width of the timeline, in seconds. The track spans -range to +range.
    let range: TimeInterval = 12 * 3600
    private let step: TimeInterval = 15 * 60
    private let magnet: TimeInterval = 18 * 60
    private let knob: CGFloat = 14

    @State private var dragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let travel = max(width - knob, 1)
            let fraction = CGFloat((offset + range) / (2 * range))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 4)

                // Hour ticks every three hours, brighter at the midpoint.
                HStack(spacing: 0) {
                    ForEach(0...8, id: \.self) { index in
                        Rectangle()
                            .fill(Color.primary.opacity(index == 4 ? 0.28 : 0.14))
                            .frame(width: index == 4 ? 1.5 : 1, height: index == 4 ? 10 : 6)
                        if index < 8 { Spacer(minLength: 0) }
                    }
                }
                .padding(.horizontal, knob / 2)

                // Filled span from "now" to the current position.
                Capsule()
                    .fill(Color.accentColor.opacity(0.55))
                    .frame(width: abs(fraction - 0.5) * travel, height: 4)
                    .offset(x: knob / 2 + min(fraction, 0.5) * travel)

                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.25), radius: dragging ? 4 : 2, y: 1)
                    .frame(width: knob, height: knob)
                    .scaleEffect(dragging ? 1.15 : 1)
                    .offset(x: fraction * travel)
            }
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !dragging { withAnimation(.snappy(duration: 0.15)) { dragging = true } }
                        let position = min(max(0, value.location.x - knob / 2), travel)
                        let raw = TimeInterval(position / travel) * 2 * range - range
                        let snapped = (raw / step).rounded() * step
                        offset = abs(snapped) < magnet ? 0 : snapped
                    }
                    .onEnded { _ in
                        withAnimation(.snappy(duration: 0.2)) { dragging = false }
                    }
            )
        }
        .frame(height: 24)
    }
}
