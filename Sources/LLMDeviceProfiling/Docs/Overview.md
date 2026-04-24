# LLMDeviceProfiling Overview

`LLMDeviceProfiling` exposes backend-neutral device and runtime signals for routing inputs.

`DeviceProfileCollector` snapshots stable hardware facts such as operating system version, physical memory,
and processor count. `RuntimeConstraintsCollector` captures ephemeral execution constraints such as low power
mode preference and currently available free disk budget for the active volume.
