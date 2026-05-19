import LLMCore

enum DownloadProgressPresentation {
    static func normalizedFraction(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }
        let fraction = value >= 2 && value <= 100 ? value / 100 : value
        return min(max(fraction, 0), 1)
    }

    static func percentTitle(for value: Double, isEstimated: Bool) -> String {
        let percent = Int((normalizedFraction(value) * 100).rounded())
        return "\(percent)%"
    }
}

extension ModelDownloadsViewModel {
    public func installState(for modelID: ModelID) -> InstallState {
        installStates[modelID] ?? .notInstalled
    }
}
