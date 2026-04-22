# LLMKit

LLMKit is a modular Swift package for LLM orchestration on Apple platforms.

The architecture documents in `Docs/Architecture/` are the source of truth. The package is organized around backend-neutral domain types, service contracts, orchestration, model lifecycle, backend adapters, and optional SwiftUI surfaces.

## Current status

This repository is past the initial scaffold and contract phase. Core contracts, orchestration, lifecycle persistence, backend availability gates, remote transport/stream mapping, optional SwiftUI view models, and an iOS demo app are in place.

## Demo

An iOS demo project is available at `Examples/LLMKitDemo/LLMKitDemo.xcodeproj`.

The demo uses a fake in-app backend so it can run on a simulator or physical device without API keys. It exercises LLMKit routing, streaming chat events, and model lifecycle install state.
