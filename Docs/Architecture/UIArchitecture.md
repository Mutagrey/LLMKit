# UI Architecture

UI modules are optional SwiftUI layers. They render chat and model lifecycle state using public service protocols and domain types. UI code must not own routing, transport, persistence, provider DTOs, or backend SDK calls.
