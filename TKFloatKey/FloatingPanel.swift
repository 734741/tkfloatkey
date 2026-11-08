import SwiftUI

/// Draggable floating ball + expandable panel. Sits on top of the app UI,
/// stays where you drop it, and remembers the position.
struct FloatingPanel: View {

    @ObservedObject var vault: CredentialVault

    @State private var expanded = false
    @State private var position: CGPoint = .zero
    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging = false

    private let ballSize: CGFloat = 58

    var body: some View {
        GeometryReader { geo in
            let home = CGPoint(x: geo.size.width - ballSize / 2 - 16,
                               y: geo.size.height * 0.55)
            let anchor = resolved(position, home: home, in: geo.size)
            let current = CGPoint(x: anchor.x + dragOffset.width,
                                  y: anchor.y + dragOffset.height)

            ZStack(alignment: .topLeading) {
                if expanded {
                    SlotPanel(vault: vault,
                              onClose: { withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { expanded = false } },
                              onMove: { delta in nudge(delta, from: anchor, in: geo.size) })
                        .frame(width: panelWidth(for: geo.size))
                        .position(clampedPanelCenter(base: current, in: geo.size))
                        .transition(.scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity))
                }

                floatingBall
                    .position(current)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                let moved = hypot(value.translation.width, value.translation.height)
                                if moved < 8 {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                        expanded.toggle()
                                    }
                                } else {
                                    let dropped = CGPoint(x: anchor.x + value.translation.width,
                                                          y: anchor.y + value.translation.height)
                                    let snapped = snapToEdge(dropped, in: geo.size)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        position = snapped
                                        dragOffset = .zero
                                    }
                                    UserDefaults.standard.set([snapped.x, snapped.y],
                                                              forKey: "FloatBall.position")
                                }
                            }
                    )
                    .onAppear { loadPosition() }
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Ball

    private var floatingBall: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.18, green: 0.72, blue: 0.98),
                                              Color(red: 0.36, green: 0.36, blue: 0.98)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(isDragging ? 0.12 : 0.28),
                        radius: isDragging ? 6 : 12, y: 4)
            VStack(spacing: 1) {
                Text("\(vault.filledCount)")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("TK")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Circle()
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
        }
        .frame(width: ballSize, height: ballSize)
        .scaleEffect(isDragging ? 1.06 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
        .accessibilityLabel("账号面板，\(vault.filledCount) 个槽位已填")
    }

    // MARK: - Geometry helpers

    private func panelWidth(for size: CGSize) -> CGFloat {
        min(size.width - 24, 340)
    }

    private func resolved(_ saved: CGPoint, home: CGPoint, in size: CGSize) -> CGPoint {
        guard saved != .zero else { return home }
        return CGPoint(x: min(max(saved.x, ballSize / 2 + 8), size.width - ballSize / 2 - 8),
                       y: min(max(saved.y, ballSize / 2 + 60), size.height - ballSize / 2 - 80))
    }

    private func snapToEdge(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let margin = ballSize / 2 + 12
        let goLeft = p.x < size.width / 2
        return CGPoint(x: goLeft ? margin : size.width - margin,
                       y: min(max(p.y, margin + 40), size.height - margin - 60))
    }

    private func clampedPanelCenter(base: CGPoint, in size: CGSize) -> CGPoint {
        let w = panelWidth(for: size)
        let h: CGFloat = 460
        let cx = min(max(base.x, w / 2 + 10), size.width - w / 2 - 10)
        let cy = min(max(base.y, h / 2 + 20), size.height - h / 2 - 20)
        return CGPoint(x: cx, y: cy)
    }

    private func nudge(_ delta: CGSize, from anchor: CGPoint, in size: CGSize) {
        let next = CGPoint(x: anchor.x + delta.width, y: anchor.y + delta.height)
        position = snapToEdge(next, in: size)
        UserDefaults.standard.set([position.x, position.y], forKey: "FloatBall.position")
    }

    private func loadPosition() {
        if let arr = UserDefaults.standard.array(forKey: "FloatBall.position") as? [Double],
           arr.count == 2 {
            position = CGPoint(x: arr[0], y: arr[1])
        }
    }
}
