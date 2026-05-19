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
        Form {
            Section {
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        LLMSettingsChromeIcon(systemImage: overviewSystemImage, tint: overviewTint)

                        VStack(alignment: .leading) {
                            Text(overviewTitle)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)

                            if let overviewSubtitle {
                                Text(overviewSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    overviewContent
                }
            }

            Section {
                linksContent
            } header: {
                Text(groupsTitle)
            } footer: {
                if let groupsFooter {
                    Text(groupsFooter)
                }
            }
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
    }
}

struct LLMSettingsChromeIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
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
        HStack {
            LLMSettingsChromeIcon(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if let value {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}
