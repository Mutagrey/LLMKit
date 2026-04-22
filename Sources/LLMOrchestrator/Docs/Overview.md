# LLMOrchestrator Overview

`LLMOrchestrator` owns runtime composition, routing, planning, fallback, and service façades.

Current services build an execution plan from catalog models, prioritize a requested preferred model when it satisfies the requirements, and try remaining candidates when an earlier backend is missing or fails before completion.
