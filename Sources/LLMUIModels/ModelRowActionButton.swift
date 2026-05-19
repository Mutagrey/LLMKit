import SwiftUI

struct ModelRowActionButton: View {
    struct Spec {
        enum Style: Equatable {
            case plain
            case circle
        }

        let symbol: String
        let tint: Color
        let label: String
        let style: Style
        let isDisabled: Bool
        let action: () async -> Void
    }

    let spec: Spec
    @State private var effectTrigger = 0

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) {
                effectTrigger += 1
            }
            Task { await spec.action() }
        } label: {
            Image(systemName: spec.symbol)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: effectTrigger)
                .frame(width: buttonSize, height: buttonSize)
                .background {
                    if spec.style == .circle {
                        Circle()
                            .fill(spec.tint.opacity(0.12))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(spec.isDisabled ? Color.secondary : spec.tint)
        .opacity(spec.isDisabled ? 0.45 : 1)
        .disabled(spec.isDisabled)
        .accessibilityLabel(spec.label)
    }

    private var buttonSize: CGFloat {
        switch spec.style {
        case .plain:
            return 26
        case .circle:
            return 28
        }
    }
}
