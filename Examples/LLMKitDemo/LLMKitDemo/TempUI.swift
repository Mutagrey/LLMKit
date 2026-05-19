//
//  TempUI.swift
//  LLMKitDemo
//
//  Created by Sergey Petrov on 5/20/26.
//

import LLMUISettings
import SwiftUI
import LLMUIModels

#Preview {
    NavigationStack {
        List {
            LLMSettingsOverviewContent(
                selectedModelName: "Apple LLM-2",
                metadata: "7B parameters · 4-bit quantized",
                effectiveInputTokens: 4096,
                effectiveOutputTokens: 1024,
                isLowMemoryConstrained: true,
                recommendation: "Для полной производительности выберите более мощную модель."
            )
            
            Section {
                StorageUsageView(
                    downloadedModelCount: 3,
                    totalModelCount: 8,
                    installedBytes: 2_147_483_648, // 2 GB
                    partialBytes: 536_870_912 // 512 MB
                )
            }
        }
    }
}
