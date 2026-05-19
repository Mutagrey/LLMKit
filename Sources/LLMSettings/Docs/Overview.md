# LLMSettings Overview

`LLMSettings` owns backend-neutral runtime settings values used by apps and UI surfaces.

It keeps routing preferences, generation budgets, local memory limits, MLX memory knobs, and GGUF runtime knobs in one
codable model so host apps do not duplicate defaults and clamp logic.
