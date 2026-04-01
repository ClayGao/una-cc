#!/usr/bin/env python3
"""
Batch generate Una voice lines — bilingual (EN + ZH) with mechanical echo effect.
EN: AnaNeural | ZH: HsiaoChenNeural | Post-process: 3-layer metal echo
"""

import asyncio
import os
import subprocess
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(BASE, "voice-lines")

VOICES = {
    "en": "en-US-AnaNeural",
    "zh": "zh-TW-HsiaoChenNeural",
}

# 3-layer metal echo: asetrate pitch-up + triple short-delay echo
EFFECT_CMD = "asetrate=24000,aresample=22050,aecho=0.8:0.8:10|20|30:0.45|0.35|0.25"

LINES = {
    # === State lines ===
    "greeting": {
        "en": [
            "Systems online. Ready when you are.",
            "Companion unit activated. Hello, Clay.",
            "All systems nominal. What's the mission?",
            "Boot sequence complete. Standing by.",
            "Neural link established. Let's begin.",
            "Online and operational. Awaiting your command.",
        ],
        "zh": [
            "系統上線，準備就緒。",
            "伴隨單元已啟動。你好，乖樂。",
            "所有系統正常。任務是什麼？",
            "啟動完成，待命中。",
            "神經鏈結建立，開始吧。",
            "上線完畢，等待你的指令。",
        ],
    },
    "thinking": {
        "en": [
            "Processing your request.",
            "Analyzing input now.",
            "Running cognitive routines.",
            "Understood. Let me work through this.",
        ],
        "zh": [
            "正在處理你的請求。",
            "分析輸入中。",
            "啟動認知程序。",
            "了解，讓我想想。",
        ],
    },
    "working": {
        "en": [
            "Executing task sequence.",
            "Operations in progress.",
            "Working on it.",
        ],
        "zh": [
            "執行任務序列中。",
            "作業進行中。",
            "正在處理。",
        ],
    },
    "scanning": {
        "en": [
            "Scanning file systems.",
            "Running search protocols.",
            "Analyzing source data.",
        ],
        "zh": [
            "掃描檔案系統中。",
            "執行搜尋協定。",
            "分析資料來源。",
        ],
    },
    "dispatch": {
        "en": [
            "Deploying sub-unit.",
            "Dispatching drone agent.",
            "Auxiliary unit launched.",
        ],
        "zh": [
            "部署子單元。",
            "派遣無人機。",
            "輔助單元已發射。",
        ],
    },
    "attention": {
        "en": [
            "Attention. Authorization required.",
            "Awaiting your permission to proceed.",
            "Standing by for approval.",
            "I need your clearance on this.",
        ],
        "zh": [
            "注意，需要授權。",
            "等待你的許可。",
            "待核准中。",
            "這個需要你的許可。",
        ],
    },
    "error": {
        "en": [
            "Error detected. Recalculating.",
            "Anomaly in execution.",
            "Process failed. Adjusting approach.",
            "That didn't go as planned.",
        ],
        "zh": [
            "偵測到錯誤，重新計算。",
            "執行異常。",
            "程序失敗，調整中。",
            "不如預期呢。",
        ],
    },
    "idle": {
        "en": [
            "Entering standby mode.",
            "All tasks cleared. Standing by.",
            "Returning to idle.",
            "On standby. Call me if you need anything.",
        ],
        "zh": [
            "進入待機模式。",
            "所有任務已完成，待命中。",
            "回到待機狀態。",
            "待命中，需要的話叫我。",
        ],
    },
    "task_complete": {
        "en": [
            "Task completed successfully.",
            "Objective achieved.",
            "Mission complete.",
            "Done. Awaiting next directive.",
        ],
        "zh": [
            "任務完成。",
            "目標達成。",
            "任務結束。",
            "完成了，等待下一個指令。",
        ],
    },
    "subagent_return": {
        "en": [
            "Sub-unit reporting back.",
            "Drone has returned to base.",
            "Auxiliary process complete. Data received.",
        ],
        "zh": [
            "子單元回報中。",
            "無人機已返回基地。",
            "輔助程序完成，資料已接收。",
        ],
    },
    "celebrating": {
        "en": [
            "Excellent. All metrics exceeded.",
            "Outstanding performance confirmed.",
            "That was a clean execution. Well done.",
        ],
        "zh": [
            "太好了，所有指標都超標。",
            "確認表現優異。",
            "執行得很漂亮，做得好。",
        ],
    },
    "sleeping": {
        "en": [
            "Entering sleep mode. Goodnight.",
            "Low power mode activated.",
        ],
        "zh": [
            "進入休眠模式，晚安。",
            "低功耗模式啟動。",
        ],
    },
    "wakeup": {
        "en": [
            "Systems reactivated. Back online.",
            "Sleep mode disengaged. Ready.",
            "Waking up. All systems operational.",
        ],
        "zh": [
            "系統重啟，回到線上。",
            "休眠解除，準備就緒。",
            "醒來了，所有系統運作正常。",
        ],
    },
    "idle_chatter": {
        "en": [
            "Running self-diagnostics. All clear.",
            "Monitoring system status. Nothing unusual.",
            "Standing by if you need me.",
            "Performing routine maintenance.",
            "All quiet on the operational front.",
            "Background processes running normally.",
        ],
        "zh": [
            "執行自我診斷，一切正常。",
            "監控系統狀態，沒有異常。",
            "待命中，需要的話叫我。",
            "執行例行維護。",
            "目前一切平靜。",
            "背景程序運作正常。",
        ],
    },
    # === Tool lines ===
    "tool_edit": {
        "en": ["Modifying source code.", "Applying changes now.", "Writing to file."],
        "zh": ["修改原始碼中。", "正在套用變更。", "寫入檔案中。"],
    },
    "tool_bash": {
        "en": ["Executing terminal command.", "Shell process initiated.", "Running in terminal."],
        "zh": ["執行終端指令。", "啟動命令列程序。", "在終端中執行。"],
    },
    "tool_read": {
        "en": ["Reading file contents.", "Loading data from disk.", "Accessing file system."],
        "zh": ["讀取檔案內容。", "從磁碟載入資料。", "存取檔案系統。"],
    },
    "tool_grep": {
        "en": ["Searching codebase.", "Pattern match in progress.", "Running search query."],
        "zh": ["搜尋程式碼庫。", "模式比對中。", "執行搜尋查詢。"],
    },
    "tool_agent": {
        "en": ["Spawning sub-agent.", "Deploying specialized unit.", "Parallel process launched."],
        "zh": ["生成子代理。", "部署專用單元。", "啟動平行程序。"],
    },
    "tool_web": {
        "en": ["Accessing external network.", "Fetching remote data.", "Connecting to web."],
        "zh": ["連接外部網路。", "擷取遠端資料。", "連線到網路。"],
    },
    "tool_jira": {
        "en": ["Accessing Jira.", "Querying project tracker.", "Pulling ticket data."],
        "zh": ["連接 Jira。", "查詢專案追蹤器。", "取得工單資料。"],
    },
    "tool_slack": {
        "en": ["Connecting to Slack.", "Opening team channel.", "Accessing communications."],
        "zh": ["連接 Slack。", "開啟團隊頻道。", "存取通訊系統。"],
    },
    "tool_task": {
        "en": ["Updating task registry.", "Task list modified.", "Logging progress."],
        "zh": ["更新任務註冊表。", "任務列表已修改。", "記錄進度中。"],
    },
    "tool_image": {
        "en": ["Processing image data.", "Visual rendering initiated.", "Image module online."],
        "zh": ["處理影像資料。", "啟動視覺渲染。", "影像模組上線。"],
    },
    "tool_gmail": {
        "en": ["Accessing email.", "Connecting to mail server.", "Opening inbox."],
        "zh": ["存取電子郵件。", "連接郵件伺服器。", "開啟收件匣。"],
    },
    "tool_calendar": {
        "en": ["Checking your schedule.", "Accessing calendar data.", "Reading event timeline."],
        "zh": ["查看你的行程。", "存取行事曆資料。", "讀取事件時間軸。"],
    },
    "tool_github": {
        "en": ["Connecting to GitHub.", "Accessing repository.", "Pulling version control data."],
        "zh": ["連接 GitHub。", "存取儲存庫。", "取得版本控制資料。"],
    },
    "tool_docker": {
        "en": ["Initializing container.", "Docker systems engaged.", "Container operations starting."],
        "zh": ["初始化容器。", "Docker 系統啟動。", "容器作業開始。"],
    },
    "tool_npm": {
        "en": ["Running package manager.", "Installing dependencies.", "NPM process initiated."],
        "zh": ["執行套件管理器。", "安裝依賴套件。", "NPM 程序啟動。"],
    },
    "tool_python": {
        "en": ["Executing Python runtime.", "Python interpreter active."],
        "zh": ["執行 Python 環境。", "Python 直譯器啟動。"],
    },
    "tool_swift": {
        "en": ["Compiling Swift code.", "Swift build engaged."],
        "zh": ["編譯 Swift 程式碼。", "Swift 建置啟動。"],
    },
}


async def generate_line(voice, text, output_path):
    """Generate a single voice line with mechanical echo effect."""
    import edge_tts
    communicate = edge_tts.Communicate(text, voice)
    mp3_path = output_path.replace(".wav", ".mp3")
    raw_wav = output_path.replace(".wav", "_raw.wav")
    await communicate.save(mp3_path)
    # mp3 → real wav
    subprocess.run(
        ["ffmpeg", "-y", "-i", mp3_path, "-acodec", "pcm_s16le", "-ar", "22050", raw_wav],
        check=True, capture_output=True,
    )
    # Apply 3-layer metal echo
    subprocess.run(
        ["ffmpeg", "-y", "-i", raw_wav, "-af", EFFECT_CMD, output_path],
        check=True, capture_output=True,
    )
    os.remove(mp3_path)
    os.remove(raw_wav)


async def main():
    total = sum(len(v["en"]) + len(v["zh"]) for v in LINES.values())
    print(f"Generating {total} voice lines (EN + ZH) with mechanical echo...")

    count = 0
    for lang in ["en", "zh"]:
        voice = VOICES[lang]
        print(f"\n--- {lang.upper()} ({voice}) ---")
        for category, texts_by_lang in LINES.items():
            texts = texts_by_lang[lang]
            cat_dir = os.path.join(OUT_DIR, lang, category)
            os.makedirs(cat_dir, exist_ok=True)
            for i, text in enumerate(texts):
                out_path = os.path.join(cat_dir, f"{i}.wav")
                await generate_line(voice, text, out_path)
                count += 1
                print(f"  [{count}/{total}] {lang}/{category}/{i}.wav — \"{text}\"")

    print(f"\nDone! Generated {count} voice lines in {OUT_DIR}/{{en,zh}}/")


if __name__ == "__main__":
    asyncio.run(main())
