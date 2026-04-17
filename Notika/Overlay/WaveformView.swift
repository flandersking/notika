import SwiftUI

/// Animierter Balken-Graph, der ein Shift-Register von Audio-Levels
/// als weiche, pulsierende Waveform darstellt.
struct WaveformView: View {
    let levels: [Float]
    var tint: Color = .white

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(tint)
                    .frame(width: 2.5, height: barHeight(for: level))
                    .animation(.spring(response: 0.18, dampingFraction: 0.65), value: level)
            }
        }
        .frame(height: 20)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func barHeight(for level: Float) -> CGFloat {
        let clamped = max(0.08, min(1.0, CGFloat(level)))
        return 4 + clamped * 18
    }
}

#Preview {
    ZStack {
        Color.black
        WaveformView(levels: (0..<16).map { _ in Float.random(in: 0...1) })
            .padding()
    }
    .frame(width: 260, height: 60)
}
