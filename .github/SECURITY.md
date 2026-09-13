# Security Policy

## Supported Versions

The following versions of **VirtualPiano Auto Player** receive security updates and maintenance patches:

| Version | Supported | Status |
| :--- | :--- | :--- |
| `v1.1.x` | Yes | Active maintenance |
| `< v1.1.0` | No | End of Life (upgrade recommended) |

---

## Architecture & Security Model

VirtualPiano Auto Player is built with strict privacy and security standards for desktop automation:

- **Zero Network Activity:** The script contains no webhooks, analytics, telemetry, or external network requests. All parsing and playback execution is strictly local.
- **No Arbitrary Code Execution:** The parser processes note tokens and keystrokes exclusively. It does not execute shell scripts, evaluate dynamic code, or invoke external command binaries.
- **Display Privacy (WDA):** Uses Windows `SetWindowDisplayAffinity` (`WDA_EXCLUDEFROMCAPTURE`) to ensure the automation interface remains invisible during screen capture, streaming (OBS, Discord), and recording sessions.
- **Scheduler Hygiene:** Uses `timeBeginPeriod(1)` and properly releases it via `timeEndPeriod(1)` on exit to prevent system timer interrupt degradation.

---

## Reporting a Vulnerability

We appreciate responsible disclosure. If you discover a potential vulnerability or security flaw, please do **not** open a public GitHub issue.

### Preferred Method:
Use GitHub's **Private Vulnerability Reporting**:
▸ [Submit Security Advisory](https://github.com/FLUXXFALCON/VirtualPiano-Auto-Player/security/advisories/new)

### Alternative Method:
Contact the repository maintainer directly:
- **Maintainer:** [@FLUXXFALCON](https://github.com/FLUXXFALCON)
- Include:
  1. Detailed description of the vulnerability.
  2. Reproduction steps or proof of concept.
  3. Affected script versions or operating system environments.

### Response Timeline
- **Initial Acknowledgment:** Within 48 hours.
- **Triage & Status Update:** Within 5 business days.
- **Fix & Public Advisory Release:** Coordinated with the reporter after testing.
