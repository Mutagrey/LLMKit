import Charts
import SwiftUI

public struct StorageUsageBarSegment: Identifiable {
    public let id: String
    public let title: String
    public let bytes: Int64
    public let tint: Color

    public init(id: String? = nil, title: String, bytes: Int64, tint: Color) {
        self.id = id ?? title
        self.title = title
        self.bytes = max(bytes, 0)
        self.tint = tint
    }
}

public struct StorageUsageBarView: View {
    private let segments: [StorageUsageBarSegment]
    private let foregroundStyleDomain: [String]
    private let foregroundStyleRange: [Color]
    private let totalBytes: Int64
    private let height: CGFloat
    private let cornerRadius: CGFloat
    private let background: Color
    private let accessibilityLabel: String
    private let accessibilityValue: String

    public init(
        segments: [StorageUsageBarSegment],
        totalBytes: Int64,
        height: CGFloat = 25,
        cornerRadius: CGFloat = 8,
        background: Color = Color.secondary.opacity(0.12),
        accessibilityLabel: String = "Storage usage",
        accessibilityValue: String = ""
    ) {
        let visibleSegments = segments.filter { $0.bytes > 0 }
        self.segments = visibleSegments
        self.foregroundStyleDomain = visibleSegments.map(\.title)
        self.foregroundStyleRange = visibleSegments.map(\.tint)
        self.totalBytes = max(totalBytes, 1)
        self.height = height
        self.cornerRadius = cornerRadius
        self.background = background
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
    }

    public var body: some View {
        Chart {
            ForEach(segments) { segment in
                BarMark(
                    x: .value("Storage Size", Double(segment.bytes))
                )
                .foregroundStyle(by: .value("Storage Category", segment.title))
            }
        }
        .chartXScale(domain: 0...max(Double(totalBytes), 1))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(range: .plotDimension(endPadding: -8))
        .chartLegend(.hidden)
        .chartForegroundStyleScale(domain: foregroundStyleDomain, range: foregroundStyleRange)
        .chartPlotStyle { plotArea in
            plotArea
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .animation(.easeInOut(duration: 0.25), value: chartAnimationValue)
    }

    private var chartAnimationValue: Double {
        segments.reduce(0) { partialResult, segment in
            partialResult + Double(segment.bytes)
        }
    }
}
