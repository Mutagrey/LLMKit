//
//  TempUI.swift
//  LLMKitDemo
//
//  Created by Sergey Petrov on 5/20/26.
//

import LLMUISettings
import SwiftUI

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
        }
    }
}
