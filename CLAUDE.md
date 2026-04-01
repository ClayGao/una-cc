# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build universal binary (arm64 + x86_64) + DMG
bash scripts/build-dmg.sh
# Output: build/una-cc.dmg (~128MB)

# Launch
open build/una-cc.app

# Dev compile (no DMG)
swiftc -O -framework Cocoa -framework AVFoundation -framework CoreText \
  -framework NaturalLanguage UnaCompanion.swift -o una-cc && ./una-cc

# Kill running instance
pkill -f una-cc
```

## Architecture

Single-file Swift app (`UnaCompanion.swift`, ~2100 lines). No dependencies — pure Cocoa + AVFoundation.

### Event Flow

```
Claude Code hooks → ~/.claude/hooks/una-hook.sh → HTTP POST localhost:45900/state
                                                          │
                                                  StateServer (raw socket)
                                                          │
                                                  AppDelegate.onEvent
                                                          │
                              ┌──────────────┬────────────┼────────────┐
                              │              │            │            │
                        ToolRouter     SpeechController  DroneCtrl  GameView
                        (workstation   (voice lines)    (subagent  (30fps render)
                         + pose)                         drones)
```

### Key Classes

| Class | Role |
|-------|------|
| `StateServer` | Raw HTTP socket on port 45900, parses hook JSON, emits `StateEvent` |
| `ToolRouter` | Maps tool name → workstation position + animation pose |
| `SpeechController` | 3 voice packs (en/zh/og), cooldown system, tool→category mapping |
| `GameView` | NSView rendering: background → Una → drones → particles → bubble |
| `CharacterController` | Walk pathfinding, animation state machine, direction tracking |
| `DroneController` | Subagent drones: launch/hover/recall lifecycle |
| `SciFiMenuController` | Custom right-click context menu (dark sci-fi theme) |
| `SetupManager` | First-run: installs hook script + registers in Claude Code settings |
| `SpriteAtlas` | Loads animation frames from manifest + PNG sprites |

### States

`idle` / `working` / `scanning` / `dispatch` / `thinking` / `attention` — each has its own room background, workstation position, and particle effects.

### Hook Script

Embedded in `SetupManager.hookScript` (Swift string literal). Installed to `~/.claude/hooks/una-hook.sh` on first launch. Extracts tool context (file_path, command, pattern, description) for context-aware bubble text.

15 registered events: PreToolUse, PostToolUse, PostToolUseFailure, UserPromptSubmit, SubagentStart, SubagentStop, PermissionRequest, Notification, Stop, SessionStart, SessionEnd, PreCompact, PostCompact, StopFailure, TaskCompleted.

## Asset Structure

- `assets-v11/animation-manifest.json` — animation definitions (dir, frames, fps, loop, scale, mirror)
- `assets-v11/sprites/{dir}/` — PNG sprite frames (632x848, binary alpha)
- `assets-v11/room-{state}.png` — 6 isometric room backgrounds
- `voice-lines/{en,zh,og}/{category}/{N}.wav` — 300+ voice lines, 28 categories, 3 packs
- `sounds/` — SFX (idle, working, thinking, attention, power_up, glitch)

## Voice Generation

```bash
# Edge-TTS (EN + ZH with metal echo effect)
python3 -m venv /tmp/tts-env && /tmp/tts-env/bin/pip install edge-tts
/tmp/tts-env/bin/python scripts/generate-voice-lines-v2.py

# XTTS v2 (Original voice clone — requires Python 3.11, ~4GB disk)
/tmp/tts-xtts/bin/python scripts/generate-voice-lines-xtts.py
```

Voice packs: EN (AnaNeural), ZH (HsiaoChenNeural), OG (Cortana clone via XTTS v2). EN/ZH have 3-layer metal echo post-processing.

## Test State Server

```bash
curl -X POST "http://localhost:45900/state" \
  -H "Content-Type: application/json" \
  -d '{"state":"scanning","tool":"Grep","bubble":"Testing...","event":"PreToolUse"}'
```

## Release

CI/CD via `.github/workflows/release.yml` — push to main triggers build + GitHub Release with DMG. Version tracked in `Info.plist`.
