# LLMKitDemo

Minimal iOS demo app for running LLMKit on a simulator or physical device.

Open `LLMKitDemo.xcodeproj`, select the `LLMKitDemo` scheme, choose a device, and run. For a physical device, set your signing team in Xcode if needed.

The demo uses the package `LLMExampleUI` tabbed shell with:

- Apple Intelligence through the Foundation Models backend when the OS and device support it.
- A simulator-safe in-app echo backend for validating routing and chat UI without network access or API keys.
- Model and settings tabs that exercise the same lifecycle and orchestration-facing UI used by package clients.
