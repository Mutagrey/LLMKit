import SwiftUI

struct ChatToolActivityCard: View {
    let toolCall: ToolCallPresentation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(iconColor)
                    Text(toolCall.toolName)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(statusLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if !toolCall.arguments.structuredValues.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(argumentLines, id: \.self) { line in
                            Text(line)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let resultLine {
                    Text(resultLine)
                        .font(.footnote)
                        .foregroundStyle(resultColor)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            }

            Spacer(minLength: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusLabel: String {
        switch toolCall.status {
        case .running:
            return "Running"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    private var iconName: String {
        switch toolCall.status {
        case .running:
            return "hammer"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch toolCall.status {
        case .running:
            return .secondary
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private var resultColor: Color {
        switch toolCall.status {
        case .running, .completed:
            return .primary
        case .failed:
            return .red
        }
    }

    private var borderColor: Color {
        switch toolCall.status {
        case .running:
            return .clear
        case .completed:
            return .green.opacity(0.2)
        case .failed:
            return .red.opacity(0.25)
        }
    }

    private var borderWidth: CGFloat {
        switch toolCall.status {
        case .running:
            return 0
        case .completed, .failed:
            return 1
        }
    }

    private var argumentLines: [String] {
        toolCall.arguments.structuredValues
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value.stringValue)" }
    }

    private var resultLine: String? {
        switch toolCall.status {
        case .running:
            return nil
        case .completed(let value), .failed(let value):
            return value
        }
    }
}
