# Una Companion

![Una](assets/una-banner.jpg)

**Your AI co-pilot, visualized.** Una is a desktop companion that watches your [Claude Code](https://claude.ai/code) session in real-time — walking around her command room, deploying drones, announcing what she's doing, and reacting to every tool you use.

She's not just an animation. She **speaks**, she **knows what tools you're using**, and she **patrols her room** when you're not working.

---

## What She Does

| You do this in Claude Code | Una does this |
|----------------------------|---------------|
| Type a prompt | Salutes, walks to the holographic table |
| `Edit` / `Write` / `Bash` | Walks to the console — *"Editing code."* |
| `Read` / `Grep` / `Glob` | Walks to the screen — *"Searching."* |
| `WebSearch` / Jira / Slack | Walks to the comm terminal — *"Checking Jira."* |
| Dispatch a subagent | Launches a drone — *"Agent deployed."* |
| Permission request | Room turns red — *"Commander, I need your approval."* |
| Task complete | Fist pump — *"Mission accomplished."* |
| Error | Confused pose — *"We hit a problem."* |
| Go idle for 8s | Starts patrolling the room |
| Go idle for 30s | Sits down |
| Go idle for 60s | Falls asleep |

---

## Install

1. Download **`UnaCompanion.dmg`**
2. Drag `UnaCompanion.app` to **Applications**
3. Launch — first-run setup auto-configures Claude Code hooks
4. Start working in Claude Code. Una is watching.

> **Note:** macOS may block unsigned apps. Right-click → Open to bypass Gatekeeper.

---

## Features

### Real-time Visualization
- 6 isometric pixel-art room states (idle, working, scanning, dispatch, attention, thinking)
- Sprite-based character with 24 unique poses and walk animations
- Drone system — subagents visualized as drones launching and returning
- Particle effects and triple-layer breathing aura

### Voice System
- **72+ pre-recorded voice lines** across 22 categories
- Tool-specific announcements — Una says what she's doing
- Priority system with cooldowns (won't spam you)
- Idle chatter when patrolling
- Self-introduction on launch

### Smart Behavior
- **Tool-aware routing** — different tools send Una to different workstations
- **Idle patrol** → sit → sleep progression
- **Salute on prompt**, **celebrate on task complete**, **confused on error**

### Setup
- **One-click auto-setup** — creates hook script + configures `settings.json`
- Backs up your settings before modifying
- Idempotent — safe to run multiple times
- Demo mode available without Claude Code

### Controls (Menu Bar)
- Size: Small / Medium / Large / XL / XXL
- Sound: On / Off
- Demo Mode
- Quit

---

## Requirements

- macOS 13+
- [Claude Code](https://claude.ai/code)

---

## How It Works

```
Claude Code hooks → una-hook.sh → HTTP POST localhost:45900
                                         |
                                 UnaCompanion.app
                                         |
                           ToolRouter → workstation + pose
                                         |
                      GameView renders at 30fps:
                        Room background (per state)
                        + Una sprite (walk/pose)
                        + Drones + Particles + Bubble
                        + Voice (pre-recorded WAV)
```

---

## Tech

- **Language:** Swift (single file, ~1500 lines)
- **Rendering:** Native macOS (NSView + CGContext), no game engine
- **Assets:** AI-generated pixel art (isometric backgrounds + character sprites)
- **Voice:** Pre-generated with XTTS v2, 72+ lines, ~7MB
- **Size:** ~20MB total (app + assets + voice)
- **Dependencies:** Zero. Everything bundled.

---

## Disclaimer

This is a personal open-source project. Character design is original, inspired by cyberpunk and mecha aesthetics. Not affiliated with any game franchise.

---

## License

MIT
