# REA tooling status — 2026-10-29 (updated)

Read-only recovery diagnosis for the saved native-analysis frontier. This is a tooling observation, not binary evidence.

## Findings

- The current Codex session exposes the `mcp__rea__*` tools. The active tool catalog contains REA operations, so registration is present in this session.
- `/Users/isaac/.codex/config.toml` contains `[mcp_servers.rea]` with `command = "npx"`, pinned arguments `-y rea-agents@6.5.0 mcp`, `REA_ANALYSIS_PROVIDER = "ghidra"`, and `GHIDRA_INSTALL_DIR = "/Applications/ghidra_12.1.4_PUBLIC"`; configured startup/tool timeouts are 30/450 seconds.
- `node` and `npx` resolve to `/opt/homebrew/bin`; Node reports `v26.12.0`. The configured Ghidra directory exists and its `ghidraRun` launcher is executable. These checks establish local path availability only; they do not prove the running Ghidra provider is healthy.
- A read-only shell process-list attempt (`ps -axo pid,etime,comm,args`) was denied by the sandbox (`operation not permitted`). Therefore no process or provider log status is established.
- A later normal `mcp__rea__binary_session({})` request succeeded after the transient approval-review capacity failure cleared. A peer verified the configured Ghidra 12.1.4 and Java 25 prerequisites are available. This confirms the current REA route is usable; the earlier review rejection was transient and did not indicate provider unavailability.
- The `rea` executable is not on PATH, so the installed CLI doctor route was not used. No package acquisition, setup, configuration change, or install was performed.

## Recovery step

Continue using the normal `mcp__rea__binary_session({})` route for read-only REA sessions. If a future request reports provider unavailability, follow its returned reason; the current session has working REA access and verified local Ghidra/Java prerequisites.
