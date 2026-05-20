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
                "LLMSessions",
                "LLMPrompting",
                "LLMTools",
                "LLMSafety",
                "LLMObservability"
            ]
        ),
        .library(
            name: "LLMKitRuntime",
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
                "LLMNetworking"
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
            name: "LLMKitGGUF",
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
                "LLMBackendLlamaCpp"
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
                "LLMSettings",
                "LLMUIStorage",
                "LLMUIChat",
                "LLMUIModels",
                "LLMUIObservability",
                "LLMUISettings"
            ]
        ),
        .library(
            name: "LLMKitSettings",
            targets: [
                "LLMSettings",
                "LLMUIStorage",
                "LLMUISettings"
            ]
        ),
        .library(
            name: "LLMKitFull",
            targets: [
                "LLMCore",
                "LLMSettings",
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
                "LLMBackendLlamaCpp",
                "LLMBackendRemote",
                "LLMUIStorage",
                "LLMUIChat",
                "LLMUIModels",
                "LLMUIObservability",
                "LLMUISettings"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMajor(from: "0.31.3")),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0")
        // .package(url: "https://github.com/apple/swift-collections", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "LLMCore",
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMProtocols",
            dependencies: [
                "LLMCore"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMSettings",
            dependencies: [
                "LLMCore"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMSessions",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMPrompting",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMTools",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMSafety",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMObservability",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMStorage",
            dependencies: [
                "LLMCore",
                "LLMProtocols"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMDeviceProfiling",
            dependencies: [
                "LLMCore"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMNetworking",
            dependencies: [
                "LLMCore"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMModelLifecycle",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMStorage",
                "LLMObservability"
            ],
            exclude: ["Docs"]
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
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMBackendFoundationModels",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMObservability"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMBackendCoreML",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMModelLifecycle",
                "LLMObservability"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMBackendMLX",
            dependencies: [
                "LLMCore",
                "LLMSettings",
                "LLMProtocols",
                "LLMModelLifecycle",
                "LLMObservability",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers")
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "CLlama",
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMBackendLlamaCpp",
            dependencies: [
                "CLlama",
                "LLMCore",
                "LLMSettings",
                "LLMProtocols",
                "LLMModelLifecycle",
                "LLMObservability",
                .target(name: "llama")
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMBackendRemote",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMNetworking",
                "LLMObservability"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMUIStorage",
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMUIChat",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMOrchestrator",
                "LLMSessions",
                "LLMTools",
                "LLMObservability",
                "LLMUIObservability"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMUIModels",
            dependencies: [
                "LLMCore",
                "LLMProtocols",
                "LLMModelLifecycle",
                "LLMObservability",
                "LLMUIStorage"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMUIObservability",
            dependencies: [
                "LLMCore",
                "LLMObservability"
            ],
            exclude: ["Docs"]
        ),
        .target(
            name: "LLMUISettings",
            dependencies: [
                "LLMCore",
                "LLMSettings",
                "LLMUIStorage"
            ],
            exclude: ["Docs"]
        ),
        .testTarget(
            name: "LLMCoreTests",
            dependencies: ["LLMCore"]
        ),
        .testTarget(
            name: "LLMSettingsTests",
            dependencies: ["LLMSettings"]
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
            name: "LLMBackendLlamaCppTests",
            dependencies: ["LLMBackendLlamaCpp"]
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
            name: "LLMUIModelsTests",
            dependencies: ["LLMUIModels"]
        ),
        .testTarget(
            name: "LLMUIObservabilityTests",
            dependencies: ["LLMUIObservability"]
        ),
        .testTarget(
            name: "LLMUISettingsTests",
            dependencies: ["LLMUISettings"]
        ),
        .testTarget(
            name: "LLMKitDemoSkillTests",
            dependencies: ["LLMCore", "LLMSettings"],
            path: "Examples/LLMKitDemo/LLMKitDemo/State",
            exclude: [
                "DemoModelPreflight.swift",
                "DemoViewModel.swift"
            ],
            sources: [
                "DemoPromptSkill.swift",
                "DemoPromptSkillComposer.swift",
                "DemoPromptSkillStore.swift",
                "DemoPromptSkillTests.swift",
                "DemoRuntimeSettingsMigration.swift",
                "DemoSettingsMigrationTests.swift"
            ]
        ),
        .testTarget(
            name: "LLMArchitectureTests",
            dependencies: []
        ),
        .binaryTarget(
            name: "llama",
            path: "Vendor/llama.cpp/llama.xcframework"
        )
    ]
)
