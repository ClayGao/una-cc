#!/usr/bin/env python3
"""
Batch generate Una voice lines using edge-tts (Microsoft AnaNeural).
Outputs WAV files to voice-lines/ organized by category.
"""

import asyncio
import os
import subprocess
import sys

VOICE = "en-US-AnaNeural"
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(BASE, "voice-lines")

# All voice lines: category → list of texts
LINES = {
    # === State lines ===
    "greeting": [
        "Systems online. Ready when you are.",
        "Companion unit activated. Hello, Clay.",
        "All systems nominal. What's the mission?",
        "Boot sequence complete. Standing by.",
        "Neural link established. Let's begin.",
        "Online and operational. Awaiting your command.",
    ],
    "thinking": [
        "Processing your request.",
        "Analyzing input now.",
        "Running cognitive routines.",
        "Understood. Let me work through this.",
    ],
    "working": [
        "Executing task sequence.",
        "Operations in progress.",
        "Working on it.",
    ],
    "scanning": [
        "Scanning file systems.",
        "Running search protocols.",
        "Analyzing source data.",
    ],
    "dispatch": [
        "Deploying sub-unit.",
        "Dispatching drone agent.",
        "Auxiliary unit launched.",
    ],
    "attention": [
        "Attention. Authorization required.",
        "Awaiting your permission to proceed.",
        "Standing by for approval.",
        "I need your clearance on this.",
    ],
    "error": [
        "Error detected. Recalculating.",
        "Anomaly in execution.",
        "Process failed. Adjusting approach.",
        "That didn't go as planned.",
    ],
    "idle": [
        "Entering standby mode.",
        "All tasks cleared. Standing by.",
        "Returning to idle.",
        "On standby. Call me if you need anything.",
    ],
    "task_complete": [
        "Task completed successfully.",
        "Objective achieved.",
        "Mission complete.",
        "Done. Awaiting next directive.",
    ],
    "subagent_return": [
        "Sub-unit reporting back.",
        "Drone has returned to base.",
        "Auxiliary process complete. Data received.",
    ],
    "celebrating": [
        "Excellent. All metrics exceeded.",
        "Outstanding performance confirmed.",
        "That was a clean execution. Well done.",
    ],
    "sleeping": [
        "Entering sleep mode. Goodnight.",
        "Low power mode activated.",
    ],
    "wakeup": [
        "Systems reactivated. Back online.",
        "Sleep mode disengaged. Ready.",
        "Waking up. All systems operational.",
    ],
    "idle_chatter": [
        "Running self-diagnostics. All clear.",
        "Monitoring system status. Nothing unusual.",
        "Standing by if you need me.",
        "Performing routine maintenance.",
        "All quiet on the operational front.",
        "Background processes running normally.",
    ],
    # === Tool lines ===
    "tool_edit": [
        "Modifying source code.",
        "Applying changes now.",
        "Writing to file.",
    ],
    "tool_bash": [
        "Executing terminal command.",
        "Shell process initiated.",
        "Running in terminal.",
    ],
    "tool_read": [
        "Reading file contents.",
        "Loading data from disk.",
        "Accessing file system.",
    ],
    "tool_grep": [
        "Searching codebase.",
        "Pattern match in progress.",
        "Running search query.",
    ],
    "tool_agent": [
        "Spawning sub-agent.",
        "Deploying specialized unit.",
        "Parallel process launched.",
    ],
    "tool_web": [
        "Accessing external network.",
        "Fetching remote data.",
        "Connecting to web.",
    ],
    "tool_jira": [
        "Accessing Jira.",
        "Querying project tracker.",
        "Pulling ticket data.",
    ],
    "tool_slack": [
        "Connecting to Slack.",
        "Opening team channel.",
        "Accessing communications.",
    ],
    "tool_task": [
        "Updating task registry.",
        "Task list modified.",
        "Logging progress.",
    ],
    "tool_image": [
        "Processing image data.",
        "Visual rendering initiated.",
        "Image module online.",
    ],
    "tool_gmail": [
        "Accessing email.",
        "Connecting to mail server.",
        "Opening inbox.",
    ],
    "tool_calendar": [
        "Checking your schedule.",
        "Accessing calendar data.",
        "Reading event timeline.",
    ],
    "tool_github": [
        "Connecting to GitHub.",
        "Accessing repository.",
        "Pulling version control data.",
    ],
    "tool_docker": [
        "Initializing container.",
        "Docker systems engaged.",
        "Container operations starting.",
    ],
    "tool_npm": [
        "Running package manager.",
        "Installing dependencies.",
        "NPM process initiated.",
    ],
    "tool_python": [
        "Executing Python runtime.",
        "Python interpreter active.",
    ],
    "tool_swift": [
        "Compiling Swift code.",
        "Swift build engaged.",
    ],
}


async def generate_line(voice, text, output_path):
    """Generate a single voice line."""
    import edge_tts
    communicate = edge_tts.Communicate(text, voice)
    # edge-tts outputs mp3 by default, convert to wav after
    mp3_path = output_path.replace(".wav", ".mp3")
    await communicate.save(mp3_path)
    # Convert mp3 → wav using afconvert (macOS built-in)
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", "LEI16@22050", mp3_path, output_path],
        check=True, capture_output=True,
    )
    os.remove(mp3_path)


async def main():
    total = sum(len(v) for v in LINES.values())
    print(f"Generating {total} voice lines with {VOICE}...")

    count = 0
    for category, texts in LINES.items():
        cat_dir = os.path.join(OUT_DIR, category)
        os.makedirs(cat_dir, exist_ok=True)

        for i, text in enumerate(texts):
            out_path = os.path.join(cat_dir, f"{i}.wav")
            await generate_line(VOICE, text, out_path)
            count += 1
            print(f"  [{count}/{total}] {category}/{i}.wav — \"{text}\"")

    print(f"\nDone! Generated {count} voice lines in {OUT_DIR}")


if __name__ == "__main__":
    asyncio.run(main())
