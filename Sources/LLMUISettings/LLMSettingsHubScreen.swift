import SwiftUI

public struct LLMSettingsHubScreen<OverviewContent: View, LinksContent: View>: View {
    private let title: String
    private let overviewTitle: String
    private let overviewSubtitle: String?
    private let overviewSystemImage: String
    private let overviewTint: Color
    private let groupsTitle: String
    private let groupsFooter: String?
    private let overviewContent: OverviewContent
    private let linksContent: LinksContent

    public init(
        title: String,
        overviewTitle: String,
        overviewSubtitle: String? = nil,
        overviewSystemImage: String = "sparkles",
        overviewTint: Color = .blue,
        groupsTitle: String = "Settings Groups",
        groupsFooter: String? = nil,
        @ViewBuilder overview: () -> OverviewContent,
        @ViewBuilder links: () -> LinksContent
    ) {
        self.title = title
        self.overviewTitle = overviewTitle
        self.overviewSubtitle = overviewSubtitle
        self.overviewSystemImage = overviewSystemImage
        self.overviewTint = overviewTint
        self.groupsTitle = groupsTitle
        self.groupsFooter = groupsFooter
        self.overviewContent = overview()
        self.linksContent = links()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LLMSettingsChromeCard {
                    HStack(alignment: .top, spacing: 12) {
                        LLMSettingsChromeIcon(systemImage: overviewSystemImage, tint: overviewTint)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(overviewTitle)
                                .font(.headline)
                                .lineLimit(2)

                            if let overviewSubtitle {
                                Text(overviewSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer(minLength: 8)
                    }

                    overviewContent
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(groupsTitle)
                        .font(.headline)

                    LLMSettingsChromeCard(spacing: 14) {
                        linksContent
                    }

                    if let groupsFooter {
                        Text(groupsFooter)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .navigationTitle(title)
    }
}

public struct LLMSettingsNavigationLink<Destination: View>: View {
    private let title: String
    private let subtitle: String
    private let value: String?
    private let systemImage: String
    private let tint: Color
    private let destination: Destination

    public init(
        title: String,
        subtitle: String,
        value: String? = nil,
        systemImage: String,
        tint: Color,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
        self.destination = destination()
    }

    public var body: some View {
        NavigationLink {
            destination
        } label: {
            LLMSettingsNavigationRow(
                title: title,
                subtitle: subtitle,
                value: value,
                systemImage: systemImage,
                tint: tint
            )
        }
        .buttonStyle(.plain)
    }
}

struct LLMSettingsChromeCard<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
    }
}

struct LLMSettingsChromeIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct LLMSettingsBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct LLMSettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let value: String?
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            LLMSettingsChromeIcon(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
