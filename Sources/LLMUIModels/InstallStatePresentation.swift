import LLMCore
import SwiftUI

extension InstallState {
    var llmUIModelsIsInstalled: Bool {
        switch self {
        case .ready, .warming, .active:
            return true
        case .notInstalled, .downloading, .paused, .downloaded, .verifying, .compiling, .failed, .evicted:
            return false
        }
    }

    var llmUIModelsIsInstalling: Bool {
        switch self {
        case .downloading, .downloaded, .verifying, .compiling:
            return true
        case .notInstalled, .paused, .ready, .warming, .active, .failed, .evicted:
            return false
        }
    }

    var llmUIModelsIsPaused: Bool {
        if case .paused = self {
            return true
        }
        return false
    }

    var llmUIModelsShowsProgress: Bool {
        switch self {
        case .downloading, .paused, .downloaded, .verifying, .compiling:
            return true
        case .notInstalled, .ready, .warming, .active, .failed, .evicted:
            return false
        }
    }

    var llmUIModelsInstallTitle: String {
        switch self {
        case .failed:
            return "Retry"
        case .evicted:
            return "Restore model"
        default:
            return "Download model"
        }
    }

    var llmUIModelsInstallSymbol: String {
        switch self {
        case .failed:
            return "arrow.clockwise"
        default:
            return "icloud.and.arrow.down"
        }
    }

    var llmUIModelsActionTint: Color {
        switch self {
        case .failed:
            return .red
        case .evicted:
            return .orange
        default:
            return .accentColor
        }
    }

    var llmUIModelsProgressFraction: Double {
        switch self {
        case .notInstalled, .evicted:
            return 0
        case .downloading(let progress), .paused(let progress):
            return DownloadProgressPresentation.normalizedFraction(progress)
        case .downloaded, .verifying, .compiling, .ready, .warming, .active, .failed:
            return 1
        }
    }

    var llmUIModelsProgressStatusTitle: String {
        switch self {
        case .notInstalled:
            return "Ready to download"
        case .downloading:
            return "Downloading"
        case .paused:
            return "Paused"
        case .downloaded:
            return "Downloaded"
        case .verifying:
            return "Verifying files"
        case .compiling:
            return "Preparing runtime"
        case .ready:
            return "Ready"
        case .warming:
            return "Warming"
        case .active:
            return "Active"
        case .failed(let message):
            return "Failed: \(message)"
        case .evicted(let reason):
            return "Evicted: \(String(describing: reason))"
        }
    }

    var llmUIModelsProgressColor: Color {
        switch self {
        case .notInstalled:
            return .accentColor
        case .downloading, .downloaded, .verifying, .compiling:
            return .blue
        case .paused, .failed:
            return .red
        case .ready, .warming, .active:
            return .green
        case .evicted:
            return .orange
        }
    }

    var llmUIModelsIsTransferState: Bool {
        switch self {
        case .downloading, .paused:
            return true
        case .notInstalled, .downloaded, .verifying, .compiling, .ready, .warming, .active, .failed, .evicted:
            return false
        }
    }
}
