import SwiftUI

enum ExampleDemoTab: String, CaseIterable, Identifiable {
    case chat
    case models
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .chat:
            return "Chat"
        case .models:
            return "Models"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right.fill"
        case .models:
            return "cpu.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

struct ExampleDemoTabBar: View {
    @Binding var selection: ExampleDemoTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ExampleDemoTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.title3.weight(.semibold))
                        Text(tab.title)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(selection == tab ? Color.blue : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selection == tab ? Color.primary.opacity(0.12) : Color.clear,
                        in: Capsule(style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }
}

struct ActiveDownloadSummary: Hashable {
    let title: String
    let detail: String
    let progress: Double
    let remainingCount: Int
}

struct ActiveDownloadBanner: View {
    let summary: ActiveDownloadSummary

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)

                Text(summary.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(trailingText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if !summary.detail.isEmpty {
                Text(summary.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }

            ProgressView(value: summary.progress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }

    private var trailingText: String {
        let percent = "\(Int((summary.progress * 100).rounded()))%"
        guard summary.remainingCount > 0 else {
            return percent
        }
        return "\(percent) · +\(summary.remainingCount)"
    }
}

struct ExampleDemoBackground: View {
    var body: some View {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #elseif os(iOS) || os(tvOS) || os(visionOS)
        Color(uiColor: .systemBackground)
        #else
        Color.black.opacity(0.96)
        #endif
    }
}

extension View {
    @ViewBuilder
    func exampleHiddenSystemTabBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }
}
