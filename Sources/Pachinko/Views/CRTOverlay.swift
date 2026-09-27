import SwiftUI

struct CRTOverlay: View {
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                let i = intensity
                let flicker = 0.97 + 0.03 * sin(t * 47)

                context.fill(
                    Path(rect),
                    with: .color(Color(red: 1.0, green: 0.45, blue: 0.35).opacity(0.03 * i * flicker))
                )

                let lineStep: CGFloat = 2.5
                var y: CGFloat = 0
                while y < size.height {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(Color.black.opacity(0.16 * i)), lineWidth: 1)
                    y += lineStep
                }

                var x: CGFloat = 0
                while x < size.width {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 0))
                    line.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(line, with: .color(Color.black.opacity(0.04 * i)), lineWidth: 1)
                    x += 3
                }

                let vignette = Gradient(stops: [
                    .init(color: .clear, location: 0.45),
                    .init(color: Color.black.opacity(0.50 * i), location: 1.0),
                ])
                context.fill(
                    Path(ellipseIn: rect.insetBy(dx: -rect.width * 0.05, dy: -rect.height * 0.05)),
                    with: .radialGradient(
                        vignette,
                        center: CGPoint(x: rect.midX, y: rect.midY),
                        startRadius: min(rect.width, rect.height) * 0.25,
                        endRadius: hypot(rect.width, rect.height) * 0.55
                    )
                )

                context.stroke(Path(rect), with: .color(Color.black.opacity(0.35 * i)), lineWidth: 12)
            }
            .allowsHitTesting(false)
        }
    }
}

struct CRTScreenModifier: ViewModifier {
    let enabled: Bool
    let shake: CGSize

    func body(content: Content) -> some View {
        content
            .scaleEffect(enabled ? 0.985 : 1.0)
            .offset(x: shake.width, y: shake.height)
            .overlay {
                if enabled {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.02),
                                    Color.black.opacity(0.35),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .padding(1)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: enabled ? 10 : 4))
            .overlay {
                if enabled {
                    CRTOverlay(intensity: 1.0)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .shadow(color: enabled ? Color.orange.opacity(0.14) : .clear, radius: enabled ? 16 : 0)
    }
}

extension View {
    func crtScreen(enabled: Bool, shake: CGSize = .zero) -> some View {
        modifier(CRTScreenModifier(enabled: enabled, shake: shake))
    }
}
