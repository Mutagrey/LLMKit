// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
        .tvOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "LLMKitCore",
            targets: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMStorage",
                "LLMDeviceProfiling"
            ]
        ),
        .library(
            name: "LLMKitApple",
            targets: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMStorage",
                "LLMDeviceProfiling",
                "LLMBackendFoundationModels",
                "LLMBackendCoreML"
            ]
        ),
        .library(
            name: "LLMKitLocal",
            targets: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMStorage",
                "LLMDeviceProfiling",
                "LLMBackendCoreML",
                "LLMBackendMLX"
            ]
        ),
        .library(
            name: "LLMKitRemote",
            targets: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMStorage",
                "LLMDeviceProfiling",
                "LLMNetworking",
                "LLMBackendRemote"
            ]
        ),
        .library(
            name: "LLMKitUI",
            targets: [
                "LLMUIChat",
                "LLMUIDownloads"
            ]
        ),
        .library(
            name: "LLMKitFull",
            targets: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMStorage",
                "LLMDeviceProfiling",
                "LLMNetworking",
                "LLMBackendFoundationModels",
                "LLMBackendCoreML",
                "LLMBackendMLX",
                "LLMBackendRemote",
                "LLMUIChat",
                "LLMUIDownloads"
            ]
        )
    ],
    dependencies: [
        // Add external packages only after ADR review.
        // Example placeholders:
        // .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.0.0"),
        // .package(url: "https://github.com/apple/swift-collections", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "LLMCore"
        ),
        .target(
            name: "LLMProtocols",
            dependencies: [
                "LLMCore"
            ]
        ),
        .target(
            name: "LLMSessions",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMPrompting",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMTools",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMSafety",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMObservability",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMStorage",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ]
        ),
        .target(
            name: "LLMDeviceProfiling",
            dependencies: [
                "LLMCore"
            ]
        ),
        .target(
            name: "LLMNetworking",
            dependencies: [
                "LLMCore"
            ]
        ),
        .target(
            name: "LLMModelLifecycle",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMStorage",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMOrchestrator",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability",
                "LLMModelLifecycle",
                "LLMDeviceProfiling"
            ]
        ),
        .target(
            name: "LLMBackendFoundationModels",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMBackendCoreML",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMModelLifecycle",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMBackendMLX",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMModelLifecycle",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMBackendRemote",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMNetworking",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMUIChat",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMTools",
                "LLMObservability"
            ]
        ),
        .target(
            name: "LLMUIDownloads",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMModelLifecycle",
                "LLMObservability"
            ]
        ),
        .testTarget(
            name: "LLMCoreTests",
            dependencies: ["LLMCore"]
        ),
        .testTarget(
            name: "LLMProtocolsTests",
            dependencies: ["LLMProtocols"]
        ),
        .testTarget(
            name: "LLMSessionsTests",
            dependencies: ["LLMSessions"]
        ),
        .testTarget(
            name: "LLMPromptingTests",
            dependencies: ["LLMPrompting"]
        ),
        .testTarget(
            name: "LLMToolsTests",
            dependencies: ["LLMTools"]
        ),
        .testTarget(
            name: "LLMSafetyTests",
            dependencies: ["LLMSafety"]
        ),
        .testTarget(
            name: "LLMObservabilityTests",
            dependencies: ["LLMObservability"]
        ),
        .testTarget(
            name: "LLMStorageTests",
            dependencies: ["LLMStorage"]
        ),
        .testTarget(
            name: "LLMDeviceProfilingTests",
            dependencies: ["LLMDeviceProfiling"]
        ),
        .testTarget(
            name: "LLMNetworkingTests",
            dependencies: ["LLMNetworking"]
        ),
        .testTarget(
            name: "LLMModelLifecycleTests",
            dependencies: ["LLMModelLifecycle"]
        ),
        .testTarget(
            name: "LLMOrchestratorTests",
            dependencies: ["LLMOrchestrator"]
        ),
        .testTarget(
            name: "LLMBackendFoundationModelsTests",
            dependencies: ["LLMBackendFoundationModels"]
        ),
        .testTarget(
            name: "LLMBackendCoreMLTests",
            dependencies: ["LLMBackendCoreML"]
        ),
        .testTarget(
            name: "LLMBackendMLXTests",
            dependencies: ["LLMBackendMLX"]
        ),
        .testTarget(
            name: "LLMBackendRemoteTests",
            dependencies: ["LLMBackendRemote"]
        ),
        .testTarget(
            name: "LLMUIChatTests",
            dependencies: ["LLMUIChat"]
        ),
        .testTarget(
            name: "LLMUIDownloadsTests",
            dependencies: ["LLMUIDownloads"]
        )
    ]
)
