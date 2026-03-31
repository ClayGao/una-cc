import Cocoa
import Foundation
import AVFoundation
import CoreText
import NaturalLanguage

// MARK: - Types

enum UnaState: String, CaseIterable {
    case idle, working, dispatch, scanning, thinking, attention
}

enum Direction: Int { case down = 0, up, left, right }

struct StateEvent {
    let state: UnaState
    let tool: String
    let bubble: String
    let event: String
}

// MARK: - Sprite Atlas

class SpriteAtlas {
    var walk: [Direction: [NSImage]] = [:]
    var poses: [String: NSImage] = [:]
    var overlays: [String: NSImage] = [:]
    var drones: [String: NSImage] = [:]

    func load(dir: String) {
        // Walk cycles
        for (d, name) in [(Direction.down, "down"), (.up, "up"), (.left, "left"), (.right, "right")] {
            var frames: [NSImage] = []
            for i in 0..<3 {
                if let img = NSImage(contentsOfFile: "\(dir)/sprites/walk_\(name)_\(i).png") {
                    frames.append(img)
                }
            }
            if !frames.isEmpty { walk[d] = frames; print("  walk_\(name): \(frames.count)f") }
        }
        // Poses
        for name in ["idle", "thinking", "working", "scanning", "dispatch", "attention",
                      "celebrating", "waving", "sitting", "saluting", "sleeping", "confused"] {
            if let img = NSImage(contentsOfFile: "\(dir)/sprites/pose_\(name).png") {
                poses[name] = img
            }
        }
        // Overlays
        for name in ["screen_data", "screen_code", "screen_alert", "screen_radar",
                      "keyboard_glow", "hologram_ring", "antenna_signal", "warning_beacon"] {
            if let img = NSImage(contentsOfFile: "\(dir)/overlays/\(name).png") {
                overlays[name] = img; print("  overlay: \(name)")
            }
        }
        // Drones
        for name in ["drone_docked", "drone_active", "drone_flying", "drone_returning"] {
            if let img = NSImage(contentsOfFile: "\(dir)/drones/\(name).png") {
                drones[name] = img; print("  drone: \(name)")
            }
        }
    }
}

// MARK: - Workstation

struct Workstation {
    let position: CGPoint
    let pose: String
    let background: UnaState  // Which background to show
}

// MARK: - Tool Router

class ToolRouter {
    // Four workstations in the room
    static let holoTable  = Workstation(position: CGPoint(x: 500, y: 680), pose: "idle",     background: .thinking)
    static let console    = Workstation(position: CGPoint(x: 300, y: 660), pose: "working",  background: .working)
    static let mainScreen = Workstation(position: CGPoint(x: 510, y: 560), pose: "scanning", background: .scanning)
    static let commTerminal = Workstation(position: CGPoint(x: 300, y: 660), pose: "dispatch", background: .dispatch)
    static let centerIdle = Workstation(position: CGPoint(x: 500, y: 680), pose: "idle",     background: .idle)
    static let centerAlert = Workstation(position: CGPoint(x: 500, y: 680), pose: "attention", background: .attention)

    static func route(tool: String, event: String, state: UnaState) -> Workstation {
        // Priority: special events first
        if event == "PermissionRequest" || state == .attention { return centerAlert }
        if event == "UserPromptSubmit" { return holoTable }
        if state == .idle { return centerIdle }

        // Route by tool name
        switch tool {
        // Left console — coding & commands
        case "Edit", "Write", "NotebookEdit":           return console
        case "Bash":                                      return console

        // Back screen — reading & searching files
        case "Read", "Glob", "Grep":                     return mainScreen

        // Right terminal — communication & external
        case "Agent":                                     return commTerminal
        case "WebSearch", "WebFetch":                    return commTerminal
        case "Skill":                                     return commTerminal
        case let t where t.starts(with: "mcp__mcp-atlassian"): return commTerminal
        case let t where t.starts(with: "mcp__claude_ai_Slack"): return commTerminal

        // Holo table — planning & generation
        case "TaskCreate", "TaskUpdate":                 return holoTable
        case let t where t.starts(with: "mcp__mcp-image"): return holoTable

        // Default by state
        default:
            switch state {
            case .working:   return console
            case .scanning:  return mainScreen
            case .dispatch:  return commTerminal
            case .thinking:  return holoTable
            default:         return centerIdle
            }
        }
    }
}

// MARK: - Idle Patrol

class IdlePatrol {
    var isPatrolling = false
    var idleTime: CGFloat = 0
    var stayTimer: CGFloat = 0
    var currentStop: Int = 0
    let startDelay: CGFloat = 8.0  // Seconds before patrol starts

    let route: [(CGPoint, String)] = [
        (CGPoint(x: 500, y: 680), "idle"),
        (CGPoint(x: 300, y: 660), "working"),
        (CGPoint(x: 510, y: 560), "scanning"),
        (CGPoint(x: 600, y: 660), "dispatch"),
    ]

    func nextStop() -> (CGPoint, String) {
        currentStop = (currentStop + 1) % route.count
        return route[currentStop]
    }

    func randomStayDuration() -> CGFloat {
        CGFloat.random(in: 5.0...9.0)
    }
}

// MARK: - Character Controller

class CharacterController {
    var position: CGPoint = CGPoint(x: 500, y: 680)
    var targetPosition: CGPoint = CGPoint(x: 500, y: 680)
    var direction: Direction = .down
    var walkFrameIndex: Int = 0
    var walkFrameTick: Int = 0
    var isWalking: Bool = false
    var currentPose: String = "idle"
    var speed: CGFloat = 5.0
    let walkFrameRate: Int = 4

    func walkTo(position target: CGPoint, pose: String) {
        targetPosition = target
        currentPose = pose
        let dx = target.x - position.x, dy = target.y - position.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist < speed * 2 { position = target; isWalking = false; return }
        isWalking = true; walkFrameIndex = 0; walkFrameTick = 0
        direction = isoDirection(dx: dx, dy: dy)
    }

    func isoDirection(dx: CGFloat, dy: CGFloat) -> Direction {
        let adx = abs(dx), ady = abs(dy)
        if ady > adx * 0.6 { return dy < 0 ? .up : .down }
        return dx > 0 ? .right : .left
    }

    func update() {
        guard isWalking else { return }
        let dx = targetPosition.x - position.x, dy = targetPosition.y - position.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist < speed { position = targetPosition; isWalking = false; return }
        let nx = dx / dist, ny = dy / dist
        position.x += nx * speed; position.y += ny * speed
        walkFrameTick += 1
        if walkFrameTick >= walkFrameRate { walkFrameTick = 0; walkFrameIndex = (walkFrameIndex + 1) % 3 }
    }
}

// MARK: - Drone Controller

struct Drone {
    enum Phase { case docked, launching, hovering, departing, returning, landing }
    var position: CGPoint
    var phase: Phase = .docked
    var target: CGPoint = .zero
    var life: CGFloat = 0  // Phase progress 0..1
    let id: Int
}

class DroneController {
    var drones: [Drone] = []
    private var nextId = 0
    let dockPosition = CGPoint(x: 780, y: 420)  // Right wall area
    let unaReceive = CGPoint(x: 640, y: 610) // Near Una at dispatch
    let exitPoint = CGPoint(x: 950, y: 300)      // Fly off screen

    func launchDrone() {
        let d = Drone(position: dockPosition, phase: .launching, target: unaReceive, id: nextId)
        nextId += 1
        drones.append(d)
    }

    func recallOne() {
        // Recall the oldest active drone
        for i in drones.indices {
            if drones[i].phase == .departing || drones[i].phase == .hovering {
                drones[i].phase = .returning
                drones[i].target = dockPosition
                drones[i].life = 0
                return
            }
        }
    }

    func recallAll() {
        for i in drones.indices where drones[i].phase == .departing || drones[i].phase == .hovering {
            drones[i].phase = .returning
            drones[i].target = dockPosition
            drones[i].life = 0
        }
    }

    func update() {
        var toRemove: [Int] = []
        for i in drones.indices {
            drones[i].life += 0.02
            // Offset per drone — wide spread formation
            let offset = CGFloat(drones[i].id % 7) * 60 - 180  // -180..+180
            let yOff = CGFloat(drones[i].id % 5) * 40 - 80     // -80..+80
            let myReceive = CGPoint(x: unaReceive.x + offset, y: unaReceive.y + yOff)
            let myExit = CGPoint(x: exitPoint.x + offset * 0.5, y: exitPoint.y + yOff)

            switch drones[i].phase {
            case .docked: break

            case .launching:
                let t = min(drones[i].life, 1.0)
                drones[i].position = lerp(dockPosition, myReceive, t: t)
                if t >= 1.0 { drones[i].phase = .hovering; drones[i].life = 0 }

            case .hovering:
                drones[i].position.x = myReceive.x
                drones[i].position.y = myReceive.y + sin(drones[i].life * 6) * 4

            case .departing:
                let t = min(drones[i].life, 1.0)
                drones[i].position = lerp(myReceive, myExit, t: t)
                if t >= 1.0 { toRemove.append(i) }

            case .returning:
                let t = min(drones[i].life, 1.0)
                drones[i].position = lerp(drones[i].position, dockPosition, t: t * 0.1)
                if distance(drones[i].position, dockPosition) < 5 { drones[i].phase = .landing; drones[i].life = 0 }

            case .landing:
                if drones[i].life > 0.5 { toRemove.append(i) }
            }
        }
        for i in toRemove.reversed() { drones.remove(at: i) }
    }

    func lerp(_ a: CGPoint, _ b: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }
    func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }
}

// MARK: - Particle System

struct Particle {
    var x, y, vx, vy: CGFloat
    var life: CGFloat       // 1.0 → 0.0
    var decay: CGFloat      // Life decrease per frame
    var r, g, b: CGFloat
    var size: CGFloat
}

class ParticleSystem {
    var particles: [Particle] = []

    func emit(x: CGFloat, y: CGFloat, count: Int, color: (CGFloat, CGFloat, CGFloat),
              spread: CGFloat = 2, speed: CGFloat = 1, size: CGFloat = 3, decay: CGFloat = 0.02) {
        for _ in 0..<count {
            let angle = CGFloat.random(in: 0 ..< .pi * 2)
            let spd = CGFloat.random(in: 0.2...1.0) * speed
            particles.append(Particle(
                x: x + CGFloat.random(in: -spread...spread),
                y: y + CGFloat.random(in: -spread...spread),
                vx: cos(angle) * spd, vy: sin(angle) * spd,
                life: 1.0, decay: decay,
                r: color.0, g: color.1, b: color.2,
                size: size
            ))
        }
    }

    func update() {
        for i in particles.indices {
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].life -= particles[i].decay
        }
        particles.removeAll { $0.life <= 0 }
    }
}

// MARK: - Equipment Overlay Controller

class EquipmentController {
    var activeOverlays: [String: CGFloat] = [:]  // name → alpha (0..1)
    var targetOverlays: Set<String> = []

    func setActive(_ names: [String]) {
        targetOverlays = Set(names)
    }

    func update() {
        // Fade in active overlays
        for name in targetOverlays {
            let current = activeOverlays[name] ?? 0
            activeOverlays[name] = min(1.0, current + 0.06)
        }
        // Fade out inactive
        for (name, alpha) in activeOverlays where !targetOverlays.contains(name) {
            activeOverlays[name] = max(0, alpha - 0.04)
            if activeOverlays[name]! <= 0 { activeOverlays.removeValue(forKey: name) }
        }
    }
}

// MARK: - Speech Controller (Pre-recorded voice lines)

class SpeechController {
    var enabled: Bool = true
    private var voiceLines: [String: [String]] = [:]
    private var isPlaying = false
    private var lastSpoke = Date.distantPast
    private var lastToolCategory = ""
    private var lastToolTime = Date.distantPast

    private let globalCooldown: TimeInterval = 3.0      // Min gap between any speech
    private let toolCooldown: TimeInterval = 15.0        // Same tool category cooldown
    private let idleChatInterval: TimeInterval = 25.0    // Time between idle chatter
    var lastIdleChat = Date.distantPast

    // Tool name → voice category mapping
    static let toolVoiceMap: [String: String] = [
        "Edit": "tool_edit", "Write": "tool_edit", "NotebookEdit": "tool_edit",
        "Bash": "tool_bash",
        "Read": "tool_read", "Glob": "tool_read",
        "Grep": "tool_grep",
        "Agent": "tool_agent",
        "WebSearch": "tool_web", "WebFetch": "tool_web",
        "TaskCreate": "tool_task", "TaskUpdate": "tool_task",
        "Skill": "tool_bash",
        // Bash sub-tools (detected by hook from command content)
        "Gmail": "tool_gmail",
        "Calendar": "tool_calendar",
        "GitHub": "tool_github",
        "Docker": "tool_docker",
        "NPM": "tool_npm",
        "Python": "tool_python",
        "Swift": "tool_swift",
        "Curl": "tool_web",
    ]

    // Prefix matching for MCP tools
    static let toolPrefixMap: [(String, String)] = [
        ("mcp__mcp-atlassian", "tool_jira"),
        ("mcp__claude_ai_Slack", "tool_slack"),
        ("mcp__mcp-image", "tool_image"),
    ]

    func loadVoiceLines(dir: String) {
        let fm = FileManager.default
        guard let categories = try? fm.contentsOfDirectory(atPath: dir) else { return }
        for cat in categories {
            let catPath = "\(dir)/\(cat)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: catPath, isDirectory: &isDir), isDir.boolValue else { continue }
            if let files = try? fm.contentsOfDirectory(atPath: catPath) {
                let wavs = files.filter { $0.hasSuffix(".wav") }.map { "\(catPath)/\($0)" }.sorted()
                if !wavs.isEmpty { voiceLines[cat] = wavs; print("  voice[\(cat)]: \(wavs.count)") }
            }
        }
    }

    func play(_ category: String, priority: Int = 2) {
        guard enabled else { return }
        // Priority 1 = force (attention/error), skip all checks
        if priority > 1 {
            guard !isPlaying else { return }
            guard Date().timeIntervalSince(lastSpoke) > globalCooldown else { return }
        }
        guard let wavs = voiceLines[category], !wavs.isEmpty else { return }

        if isPlaying && priority <= 1 {
            // Kill current playback for high priority
            // (afplay will be in a background thread — we just set flag and start new)
        }

        lastSpoke = Date()
        isPlaying = true

        let wav = wavs.randomElement()!
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
            proc.arguments = [wav]
            try? proc.run(); proc.waitUntilExit()
            self?.isPlaying = false
        }
    }

    func playToolVoice(tool: String) {
        guard enabled, !isPlaying else { return }

        // Find voice category for this tool
        var category: String?
        if let cat = Self.toolVoiceMap[tool] {
            category = cat
        } else {
            for (prefix, cat) in Self.toolPrefixMap {
                if tool.hasPrefix(prefix) { category = cat; break }
            }
        }
        guard let cat = category else { return }

        // Tool-specific cooldown: same category within 15s = skip
        if cat == lastToolCategory && Date().timeIntervalSince(lastToolTime) < toolCooldown { return }
        lastToolCategory = cat
        lastToolTime = Date()

        play(cat, priority: 2)
    }

    func onEvent(_ evt: StateEvent) {
        guard enabled else { return }

        switch evt.event {
        case "PermissionRequest":
            play("attention", priority: 1)
        case "PostToolUseFailure":
            play("error", priority: 1)
        case "SubagentStart":
            play("dispatch", priority: 2)
        case "SubagentStop":
            play("subagent_return", priority: 3)
        case "TaskCompleted":
            play("celebrating", priority: 2)
        case "Stop", "SessionEnd":
            play("idle", priority: 3)
        case "UserPromptSubmit":
            play("thinking", priority: 3)
        case "PreToolUse":
            playToolVoice(tool: evt.tool)
        default:
            break
        }
    }

    func greet() { play("greeting", priority: 1) }

    func tryIdleChatter() {
        guard enabled, !isPlaying else { return }
        guard Date().timeIntervalSince(lastIdleChat) > idleChatInterval else { return }
        lastIdleChat = Date()
        play("idle_chatter", priority: 4)
    }

    func wakeUp() { play("wakeup", priority: 2) }
    func goSleep() { play("sleeping", priority: 3) }
}

// MARK: - Game View

class GameView: NSView {
    var backgrounds: [UnaState: NSImage] = [:]
    var currentBg: NSImage?

    var atlas: SpriteAtlas?
    var character = CharacterController()
    var droneCtrl = DroneController()
    var particles = ParticleSystem()

    var bubbleText: String = ""
    var bubbleAlpha: CGFloat = 0.0
    var bubbleFadeTarget: CGFloat = 0.0
    var bubbleFadeTimer: Timer?

    var effectPhase: Double = 0.0
    var currentState: UnaState = .idle
    let spriteHeight: CGFloat = 150.0

    func switchBackground(to state: UnaState) {
        if let newBg = backgrounds[state] {
            currentBg = newBg
        }
    }

    // NO isFlipped — use standard macOS coords (y=0 bottom, y-up)
    // Scene coords are y-down. Convert: viewY = S - sceneY
    let S: CGFloat = 1024.0
    func vy(_ y: CGFloat) -> CGFloat { S - y }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let scale = bounds.width / S

        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)

        // 1. Background — standard NSImage.draw, no flip needed
        if let bg = currentBg {
            bg.draw(in: NSRect(x: 0, y: 0, width: S, height: S))
        }

        // 2. Drones
        drawDrones(ctx)

        // 3. Una
        drawCharacter(ctx)

        // 4. Particles
        drawParticles(ctx)

        // 5. Bubble
        drawBubble(ctx)

        ctx.restoreGState()
    }

    // (LED strips, overlays, holo table removed — all baked into state backgrounds)

    // MARK: - Drones

    func drawDrones(_ ctx: CGContext) {
        guard let atlas = atlas else { return }
        for drone in droneCtrl.drones {
            let spriteName: String
            switch drone.phase {
            case .docked: spriteName = "drone_docked"
            case .launching, .landing: spriteName = "drone_active"
            case .hovering: spriteName = "drone_active"
            case .departing, .returning: spriteName = "drone_flying"
            }

            let dvY = vy(drone.position.y)

            if let img = atlas.drones[spriteName] {
                let size: CGFloat = 80
                let aspect = img.size.width / img.size.height
                let rect = NSRect(x: drone.position.x - size * aspect / 2,
                                  y: dvY,
                                  width: size * aspect, height: size)
                img.draw(in: rect)
            } else {
                // Fallback: draw a cyan circle so we can see the drone exists
                ctx.saveGState()
                ctx.setFillColor(CGColor(red: 0, green: 1, blue: 1, alpha: 0.8))
                ctx.fillEllipse(in: CGRect(x: drone.position.x - 15, y: dvY - 15, width: 30, height: 30))
                ctx.restoreGState()
            }
        }
    }

    // MARK: - Character

    func drawCharacter(_ ctx: CGContext) {
        guard let atlas = atlas else { return }
        let sprite: NSImage?
        if character.isWalking {
            let frames = atlas.walk[character.direction]
            sprite = frames?[character.walkFrameIndex % (frames?.count ?? 1)]
        } else {
            sprite = atlas.poses[character.currentPose] ?? atlas.poses["idle"]
        }
        guard let img = sprite else { return }

        let aspect = img.size.width / img.size.height
        let drawH = spriteHeight
        let drawW = drawH * aspect
        let drawX = character.position.x - drawW / 2
        // Feet at vy(position.y), sprite extends upward
        // Add padding below feet so bottom pixels don't get clipped during scaling
        let footPad: CGFloat = 18
        let feetViewY = vy(character.position.y) - footPad
        let rect = NSRect(x: drawX, y: feetViewY, width: drawW, height: drawH + footPad)

        // Outer aura — wide, soft, slow breathing
        ctx.saveGState()
        let breathe = CGFloat(0.5 + 0.4 * sin(effectPhase * 0.6 * .pi))
        ctx.setShadow(offset: .zero, blur: 40,
                      color: CGColor(red: 0.15, green: 0.4, blue: 1.0, alpha: breathe))
        img.draw(in: rect)
        ctx.restoreGState()

        // Middle ring — slightly faster offset
        ctx.saveGState()
        let midBreathe = CGFloat(0.4 + 0.35 * sin(effectPhase * 0.8 * .pi + 0.8))
        ctx.setShadow(offset: .zero, blur: 20,
                      color: CGColor(red: 0.3, green: 0.55, blue: 1.0, alpha: midBreathe))
        img.draw(in: rect)
        ctx.restoreGState()

        // Inner core — tight, bright, gentle
        ctx.saveGState()
        let innerBreathe = CGFloat(0.3 + 0.25 * sin(effectPhase * 1.0 * .pi + 1.5))
        ctx.setShadow(offset: .zero, blur: 8,
                      color: CGColor(red: 0.5, green: 0.75, blue: 1.0, alpha: innerBreathe))
        img.draw(in: rect)
        ctx.restoreGState()

        // Sharp sprite on top
        img.draw(in: rect)
    }

    // MARK: - Particles

    func drawParticles(_ ctx: CGContext) {
        ctx.saveGState()
        ctx.setBlendMode(.plusLighter)
        for p in particles.particles {
            let alpha = p.life
            ctx.setFillColor(CGColor(red: p.r, green: p.g, blue: p.b, alpha: alpha))
            let pvY = vy(p.y)
            ctx.fillEllipse(in: CGRect(x: p.x - p.size / 2, y: pvY - p.size / 2,
                                       width: p.size, height: p.size))
        }
        ctx.restoreGState()
    }

    // MARK: - Bubble

    func drawBubble(_ ctx: CGContext) {
        guard !bubbleText.isEmpty, bubbleAlpha > 0.01 else { return }

        let font = NSFont(name: "SF Mono", size: 38) ?? NSFont(name: "Monaco", size: 38) ?? NSFont.monospacedSystemFont(ofSize: 38, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.85, green: 0.95, blue: 1.0, alpha: bubbleAlpha)
        ]
        let textSize = (bubbleText as NSString).size(withAttributes: attrs)

        let padding: CGFloat = 26
        let bubbleW = textSize.width + padding * 2
        let bubbleH = textSize.height + padding * 2
        let tailH: CGFloat = 12

        // In view coords: character head = vy(position.y) + spriteHeight
        let headViewY = vy(character.position.y) + spriteHeight
        let bubbleViewY = headViewY + tailH + 6
        let bubbleX = character.position.x - bubbleW / 2
        let clampedX = max(10, min(S - bubbleW - 10, bubbleX))

        ctx.saveGState()

        // Background
        ctx.setFillColor(CGColor(red: 0.04, green: 0.08, blue: 0.18, alpha: 0.92 * bubbleAlpha))
        let rect = CGRect(x: clampedX, y: bubbleViewY, width: bubbleW, height: bubbleH)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.fillPath()

        // Border
        ctx.setStrokeColor(CGColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.7 * bubbleAlpha))
        ctx.setLineWidth(2)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.strokePath()

        // Tail pointing down to character
        let tailCX = character.position.x
        ctx.move(to: CGPoint(x: tailCX - 8, y: bubbleViewY))
        ctx.addLine(to: CGPoint(x: tailCX, y: bubbleViewY - tailH))
        ctx.addLine(to: CGPoint(x: tailCX + 8, y: bubbleViewY))
        ctx.closePath()
        ctx.setFillColor(CGColor(red: 0.04, green: 0.08, blue: 0.18, alpha: 0.92 * bubbleAlpha))
        ctx.fillPath()

        // Text — NSString.draw works in standard (non-flipped) view
        (bubbleText as NSString).draw(at: NSPoint(x: clampedX + padding, y: bubbleViewY + padding),
                                       withAttributes: attrs)

        ctx.restoreGState()
    }

    func showBubble(_ text: String) {
        bubbleText = text; bubbleFadeTarget = 1.0
        bubbleFadeTimer?.invalidate()
        bubbleFadeTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.bubbleFadeTarget = 0.0
        }
    }

    func updateBubbleAlpha() {
        let speed: CGFloat = 0.08
        if bubbleAlpha < bubbleFadeTarget { bubbleAlpha = min(bubbleFadeTarget, bubbleAlpha + speed) }
        else if bubbleAlpha > bubbleFadeTarget {
            bubbleAlpha = max(bubbleFadeTarget, bubbleAlpha - speed * 0.5)
            if bubbleAlpha < 0.01 { bubbleText = "" }
        }
    }

    // MARK: - Ambient + State Effects

    func applyStateEffects() {
        let t = effectPhase
        let cx = character.position.x
        let cy = character.position.y
        let headY = cy - spriteHeight

        // === AMBIENT (always active) ===

        // Floating dust motes — more at edges, sparse at center
        if Int(t * 30) % 8 == 0 {
            // Left side of room
            particles.emit(
                x: CGFloat.random(in: 120...320), y: CGFloat.random(in: 350...650),
                count: 1, color: (0.4, 0.5, 0.7), spread: 5, speed: 0.15, size: 6, decay: 0.004)
        }
        if Int(t * 30) % 8 == 4 {
            // Right side of room
            particles.emit(
                x: CGFloat.random(in: 700...880), y: CGFloat.random(in: 350...650),
                count: 1, color: (0.4, 0.5, 0.7), spread: 5, speed: 0.15, size: 6, decay: 0.004)
        }
        if Int(t * 30) % 10 == 0 {
            // Back wall area (upper part)
            particles.emit(
                x: CGFloat.random(in: 250...750), y: CGFloat.random(in: 280...420),
                count: 1, color: (0.35, 0.45, 0.65), spread: 5, speed: 0.12, size: 5, decay: 0.004)
        }


        // === STATE-SPECIFIC ===

        switch currentState {
        case .idle:
            break  // Room ambient dust is enough

        case .thinking:
            // Wisps around back wall screens (not center)
            if Int(t * 30) % 4 == 0 {
                particles.emit(
                    x: CGFloat.random(in: 300...700), y: CGFloat.random(in: 300...420),
                    count: 1, color: (0.4, 0.5, 1.0), spread: 20, speed: 0.4, size: 9, decay: 0.006)
            }

        case .working:
            // Console sparks — at the LEFT CONSOLE, not on Una
            if Int(t * 30) % 3 == 0 {
                particles.emit(
                    x: 200 + CGFloat.random(in: -30...30), y: 500 + CGFloat.random(in: -20...20),
                    count: 2, color: (0.1, 1.0, 0.5), spread: 15, speed: 0.8, size: 8, decay: 0.035)
            }

        case .scanning:
            // Data particles at BACK WALL screens area
            if Int(t * 30) % 2 == 0 {
                particles.emit(
                    x: 500 + CGFloat.random(in: -150...150), y: 350 + CGFloat.random(in: -50...50),
                    count: 2, color: (0.15, 0.8, 1.0), spread: 10, speed: 1.5, size: 7, decay: 0.01)
            }

        case .dispatch:
            // Signal pulses at RIGHT TERMINAL antenna area
            if Int(t * 30) % 3 == 0 {
                particles.emit(
                    x: 760 + CGFloat.random(in: -20...20), y: 450 + CGFloat.random(in: -30...30),
                    count: 2, color: (0.2, 1.0, 0.4), spread: 15, speed: 2.0, size: 9, decay: 0.02)
            }

        case .attention:
            // Red alert sparks — scattered around ROOM, not on Una
            if Int(t * 30) % 2 == 0 {
                particles.emit(
                    x: CGFloat.random(in: 150...850), y: CGFloat.random(in: 300...750),
                    count: 2, color: (1.0, 0.1, 0.02), spread: 15, speed: 0.8, size: 10, decay: 0.018)
            }
            if Int(t * 30) % 6 == 0 {
                particles.emit(
                    x: CGFloat.random(in: 200...800), y: CGFloat.random(in: 250...650),
                    count: 3, color: (1.0, 0.25, 0.0), spread: 25, speed: 0.5, size: 8, decay: 0.012)
            }
        }
    }
}

// MARK: - HTTP Server

class StateServer {
    var onEvent: ((StateEvent) -> Void)?
    private var sock: Int32 = -1, on = false

    func start(port: UInt16 = 45900) {
        sock = socket(AF_INET, SOCK_STREAM, 0); guard sock >= 0 else { return }
        var y: Int32 = 1; setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &y, socklen_t(MemoryLayout<Int32>.size))
        var a = sockaddr_in(); a.sin_family = sa_family_t(AF_INET); a.sin_port = port.bigEndian; a.sin_addr.s_addr = INADDR_ANY
        let ok = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard ok >= 0 else { return }; listen(sock, 5); on = true
        print("  State server :\(port)")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while self?.on == true {
                var ca = sockaddr_in(); var cl = socklen_t(MemoryLayout<sockaddr_in>.size)
                let cs = withUnsafeMutablePointer(to: &ca) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { accept(self!.sock, $0, &cl) } }
                guard cs >= 0 else { continue }
                DispatchQueue.global(qos: .utility).async { [weak self] in self?.handle(cs) }
            }
        }
    }

    private func parseField(_ body: String, _ key: String) -> String {
        let search = "\"\(key)\":\""
        guard let m = body.range(of: search), let se = body[m.upperBound...].firstIndex(of: "\"") else { return "" }
        return String(body[m.upperBound..<se])
    }

    private func handle(_ s: Int32) {
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = recv(s, &buf, buf.count, 0); guard n > 0 else { close(s); return }
        let req = String(bytes: buf[0..<n], encoding: .utf8) ?? ""
        if req.contains("POST /state"), let bs = req.range(of: "\r\n\r\n") {
            let body = String(req[bs.upperBound...])
            let stateStr = parseField(body, "state")
            let tool = parseField(body, "tool")
            let bubble = parseField(body, "bubble")
            let event = parseField(body, "event")
            if let state = UnaState(rawValue: stateStr) {
                let evt = StateEvent(state: state, tool: tool, bubble: bubble, event: event)
                DispatchQueue.main.async { [weak self] in self?.onEvent?(evt) }
            }
        }
        let r = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
        _ = r.withCString { send(s, $0, strlen($0), 0) }; close(s)
    }

    func stop() { on = false; if sock >= 0 { close(sock) } }
}

// MARK: - Setup Manager

class SetupManager {
    let claudeDir = NSString(string: "~/.claude").expandingTildeInPath
    let hooksDir: String
    let hookPath: String
    let settingsPath: String

    init() {
        hooksDir = "\(claudeDir)/hooks"
        hookPath = "\(hooksDir)/una-hook.sh"
        settingsPath = "\(claudeDir)/settings.json"
    }

    var isClaudeInstalled: Bool {
        FileManager.default.fileExists(atPath: claudeDir)
    }

    var isHookInstalled: Bool {
        FileManager.default.fileExists(atPath: hookPath)
    }

    var isHookRegistered: Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else { return false }
        for (_, value) in hooks {
            if let arr = value as? [[String: Any]] {
                for entry in arr {
                    // Check nested hooks array format
                    if let innerHooks = entry["hooks"] as? [[String: Any]] {
                        for h in innerHooks {
                            if let cmd = h["command"] as? String, cmd.contains("una-hook") {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    var needsSetup: Bool {
        !isHookInstalled || !isHookRegistered
    }

    // MARK: - Hook Script Content

    static let hookScript = """
    #!/bin/bash
    # una-hook.sh — v0.1 Tool-aware routing for una-cc
    curl -s --connect-timeout 0.2 "http://localhost:45900/health" >/dev/null 2>&1 || exit 0

    INPUT=$(cat 2>/dev/null || echo '{}')
    EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | head -1 | cut -d'"' -f4)
    TOOL=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | head -1 | cut -d'"' -f4)
    BUBBLE=""

    case "$EVENT" in
      UserPromptSubmit)
        STATE="thinking"; BUBBLE="Thinking..." ;;
      PreToolUse)
        case "$TOOL" in
          Read)                  STATE="scanning"; BUBBLE="Reading file..." ;;
          Glob)                  STATE="scanning"; BUBBLE="Finding files..." ;;
          Grep)                  STATE="scanning"; BUBBLE="Searching code..." ;;
          Edit)                  STATE="working";  BUBBLE="Editing code..." ;;
          Write)                 STATE="working";  BUBBLE="Writing file..." ;;
          Bash)                  STATE="working";  BUBBLE="Running command..." ;;
          NotebookEdit)          STATE="working";  BUBBLE="Editing notebook..." ;;
          Agent)                 STATE="dispatch"; BUBBLE="Dispatching agent..." ;;
          WebSearch)             STATE="dispatch"; BUBBLE="Searching web..." ;;
          WebFetch)              STATE="dispatch"; BUBBLE="Fetching page..." ;;
          TaskCreate)            STATE="thinking"; BUBBLE="Creating task..." ;;
          TaskUpdate)            STATE="thinking"; BUBBLE="Updating task..." ;;
          Skill)                 STATE="working";  BUBBLE="Running skill..." ;;
          mcp__mcp-atlassian*)   STATE="dispatch"; BUBBLE="Checking Jira..." ;;
          mcp__claude_ai_Slack*) STATE="dispatch"; BUBBLE="Reading Slack..." ;;
          mcp__mcp-image*)       STATE="thinking"; BUBBLE="Generating image..." ;;
          mcp__playwright*)      STATE="dispatch"; BUBBLE="Browser automation..." ;;
          mcp__claude-in-chrome*) STATE="dispatch"; BUBBLE="Chrome action..." ;;
          *)                     STATE="working";  BUBBLE="Working..." ;;
        esac ;;
      PostToolUse)
        STATE="working"; BUBBLE="" ;;
      PostToolUseFailure)
        STATE="attention"; BUBBLE="Something went wrong!" ;;
      SubagentStart)
        STATE="dispatch"; BUBBLE="Agent deployed!" ;;
      SubagentStop)
        STATE="working"; BUBBLE="Agent returned." ;;
      PermissionRequest)
        STATE="attention"; BUBBLE="Need your approval!" ;;
      PreCompact|PostCompact)
        STATE="thinking"; BUBBLE="Reorganizing..." ;;
      Notification)
        STATE="attention"; BUBBLE="Notification!" ;;
      TaskCompleted)
        STATE="idle"; BUBBLE="Done." ;;
      Stop)
        STATE="idle"; BUBBLE="" ;;
      StopFailure)
        STATE="attention"; BUBBLE="Stop failed!" ;;
      SessionStart)
        STATE="working"; BUBBLE="Waking up..." ;;
      SessionEnd)
        STATE="idle"; BUBBLE="" ;;
      *)
        exit 0 ;;
    esac

    curl -s -X POST "http://localhost:45900/state" \\
      -H "Content-Type: application/json" \\
      -d "{\\"state\\":\\"$STATE\\",\\"tool\\":\\"$TOOL\\",\\"bubble\\":\\"$BUBBLE\\",\\"event\\":\\"$EVENT\\"}" \\
      --connect-timeout 0.5 --max-time 1 2>/dev/null || true
    exit 0
    """

    // MARK: - Install Hook Script

    func installHookScript() -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)
            try SetupManager.hookScript.write(toFile: hookPath, atomically: true, encoding: .utf8)
            // chmod +x
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/chmod")
            proc.arguments = ["+x", hookPath]
            try proc.run(); proc.waitUntilExit()
            print("  Hook script installed: \(hookPath)")
            return true
        } catch {
            print("  Failed to install hook: \(error)")
            return false
        }
    }

    // MARK: - Register Hook in settings.json

    static let hookEvents = [
        "PreToolUse", "PostToolUse", "PostToolUseFailure",
        "UserPromptSubmit", "SubagentStart", "SubagentStop",
        "PermissionRequest", "Notification", "Stop",
        "SessionStart", "SessionEnd", "PreCompact", "PostCompact",
        "StopFailure", "TaskCompleted"
    ]

    func registerHookInSettings() -> Bool {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: settingsPath)

        // Read existing or start fresh
        var settings: [String: Any] = [:]
        if fm.fileExists(atPath: settingsPath) {
            // Backup first
            let backup = settingsPath + ".backup-\(Int(Date().timeIntervalSince1970))"
            try? fm.copyItem(atPath: settingsPath, toPath: backup)
            print("  Backup: \(backup)")

            if let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                settings = json
            }
        }

        // Get or create hooks dict
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        // Correct Claude Code hook format: {matcher, hooks: [{type, command, async}]}
        let hookEntry: [String: Any] = [
            "matcher": "",
            "hooks": [
                [
                    "type": "command",
                    "command": hookPath,
                    "async": true
                ] as [String: Any]
            ]
        ]

        for event in SetupManager.hookEvents {
            var eventHooks = hooks[event] as? [[String: Any]] ?? []
            // Check if already registered (idempotent)
            let alreadyExists = eventHooks.contains { entry in
                if let innerHooks = entry["hooks"] as? [[String: Any]] {
                    return innerHooks.contains { ($0["command"] as? String)?.contains("una-hook") == true }
                }
                return false
            }
            if !alreadyExists {
                eventHooks.append(hookEntry)
            }
            hooks[event] = eventHooks
        }

        settings["hooks"] = hooks

        // Write back
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url)
            print("  Settings updated: \(settingsPath)")
            return true
        } catch {
            print("  Failed to update settings: \(error)")
            return false
        }
    }

    // MARK: - Full Setup

    func runSetup() -> (hookOk: Bool, settingsOk: Bool) {
        let h = isHookInstalled || installHookScript()
        let s = isHookRegistered || registerHookInSettings()
        return (h, s)
    }
}

// MARK: - Floating Window

class FloatingWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false)
        level = .floating; isOpaque = false; backgroundColor = .clear; hasShadow = false
        ignoresMouseEvents = false; isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: FloatingWindow!
    var gameView: GameView!
    var stateServer: StateServer!
    var statusItem: NSStatusItem?
    var sounds: [String: AVAudioPlayer] = [:]

    var currentState: UnaState = .idle
    var currentSize: CGFloat = 300
    var soundEnabled: Bool = true
    var speech = SpeechController()
    var lastEventTime = Date()
    var explicitStop = false
    var patrol = IdlePatrol()

    var gameTimer: Timer?
    var idleTimer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Use bundle resources if running as .app, otherwise fallback to dev path
        let base: String
        if let resourcePath = Bundle.main.resourcePath,
           FileManager.default.fileExists(atPath: "\(resourcePath)/assets-v10") {
            base = resourcePath
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            base = "\(home)/Documents/una/companion"
        }
        let assetsDir = "\(base)/assets-v10"

        let atlas = SpriteAtlas()
        atlas.load(dir: assetsDir)

        // Load state-specific backgrounds (no flip needed — CGContext handles it)
        var bgs: [UnaState: NSImage] = [:]
        for state in UnaState.allCases {
            let path = "\(assetsDir)/room-\(state.rawValue).png"
            if let img = NSImage(contentsOfFile: path) {
                bgs[state] = img
                print("  bg-\(state.rawValue): loaded")
            } else {
                print("  bg-\(state.rawValue): MISSING")
            }
        }

        loadSounds(base: base)
        setupWindow(backgrounds: bgs, atlas: atlas)
        setupStatusItem()
        startGameLoop()
        startStateServer()
        speech.loadVoiceLines(dir: "\(base)/voice-lines")

        print("una-cc v0.1 — Tool-Aware + Idle Patrol")

        // First-run setup check
        let setup = SetupManager()
        if setup.needsSetup {
            showSetupDialog(setup)
        } else {
            gameView.character.currentPose = "waving"
            speech.greet()
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.gameView.character.currentPose = "idle"
            }
        }
    }

    func showSetupDialog(_ setup: SetupManager) {
        let alert = NSAlert()
        alert.messageText = "una-cc"
        alert.informativeText = """
        ◆ Claude Code: \(setup.isClaudeInstalled ? "Detected ✓" : "Not found ✗")
        ◆ Hook script: \(setup.isHookInstalled ? "Installed ✓" : "Will install")
        ◆ Settings: \(setup.isHookRegistered ? "Configured ✓" : "Will configure")

        Setup will connect Una to your Claude Code session.
        """
        alert.alertStyle = .informational

        if setup.isClaudeInstalled {
            alert.addButton(withTitle: "Setup & Connect")
        }
        alert.addButton(withTitle: "Demo Only")

        if !setup.isClaudeInstalled {
            alert.addButton(withTitle: "Quit")
        }

        let response = alert.runModal()

        if setup.isClaudeInstalled && response == .alertFirstButtonReturn {
            // Setup & Connect
            let result = setup.runSetup()
            let resultAlert = NSAlert()
            resultAlert.messageText = "Setup Complete"
            resultAlert.informativeText = """
            ◆ Hook script: \(result.hookOk ? "Installed ✓" : "Failed ✗")
            ◆ Settings: \(result.settingsOk ? "Configured ✓" : "Failed ✗")

            \(result.hookOk && result.settingsOk ? "Una is now connected to Claude Code!" : "Some steps failed. Check ~/.claude/ permissions.")
            """
            resultAlert.alertStyle = result.hookOk && result.settingsOk ? .informational : .warning
            resultAlert.runModal()
            gameView.character.currentPose = "waving"
            speech.greet()
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.gameView.character.currentPose = "idle"
            }
        } else if (!setup.isClaudeInstalled && response == .alertSecondButtonReturn) {
            NSApp.terminate(nil)
        } else {
            // Demo Only
            gameView.character.currentPose = "waving"
            speech.greet()
            Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.gameView.character.currentPose = "idle"
            }
            startDemo()
        }
    }

    var demoRunning = false
    var demoTimers: [Timer] = []

    func stopDemo() {
        demoRunning = false
        demoTimers.forEach { $0.invalidate() }
        demoTimers.removeAll()
    }

    func startDemo() {
        stopDemo()
        demoRunning = true
        let sequence: [(String, String, UnaState, String)] = [
            ("", "UserPromptSubmit", .thinking, "thinking"),
            ("Edit", "PreToolUse", .working, "working"),
            ("Grep", "PreToolUse", .scanning, "scanning"),
            ("Agent", "SubagentStart", .dispatch, "dispatch"),
            ("", "PermissionRequest", .attention, "attention"),
            ("", "Stop", .idle, "idle"),
        ]

        for (i, (tool, event, state, voiceCat)) in sequence.enumerated() {
            let t = Timer.scheduledTimer(withTimeInterval: Double(i) * 5.0 + 2.0, repeats: false) { [weak self] _ in
                guard let self = self, self.demoRunning else { return }
                let ws = ToolRouter.route(tool: tool, event: event, state: state)
                self.goToWorkstation(ws, state: state)
                self.speech.play(voiceCat)

                if event == "SubagentStart" {
                    self.gameView.droneCtrl.launchDrone()
                }
            }
            demoTimers.append(t)
        }

        // Loop demo only if still running
        let loopTimer = Timer.scheduledTimer(withTimeInterval: Double(sequence.count) * 5.0 + 4.0, repeats: false) { [weak self] _ in
            guard self?.demoRunning == true else { return }
            self?.startDemo()
        }
        demoTimers.append(loopTimer)
    }

    var sfx: [String: [AVAudioPlayer]] = [:]  // SFX with variations
    var typingTimer: Timer?

    func loadSounds(base: String) {
        let dir = "\(base)/sounds"
        for name in ["idle", "working", "attention", "thinking", "glitch"] {
            if let url = URL(string: "file://\(dir)/\(name).wav"),
               let p = try? AVAudioPlayer(contentsOf: url) { p.prepareToPlay(); sounds[name] = p }
        }
        // Load SFX
        let powerUpPath = "\(dir)/power_up.wav"
        if let url = URL(string: "file://\(powerUpPath)"),
           let p = try? AVAudioPlayer(contentsOf: url) {
            p.prepareToPlay(); p.volume = 0.35
            sfx["power_up"] = [p]
            print("  sfx[power_up]: loaded")
        }
    }

    func playSFX(_ category: String) {
        guard soundEnabled, let players = sfx[category], !players.isEmpty else { return }
        let p = players.randomElement()!
        p.currentTime = 0; p.play()
    }

    func startTypingSFX() {
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.playSFX("typing")
        }
    }

    func stopTypingSFX() {
        typingTimer?.invalidate()
        typingTimer = nil
    }

    func playSound(_ name: String) {
        guard soundEnabled else { return }
        let mapped: String
        switch name { case "dispatch", "scanning": mapped = "working"; default: mapped = name }
        if let p = sounds[mapped] { p.currentTime = 0; p.play() }
    }

    func setupWindow(backgrounds: [UnaState: NSImage], atlas: SpriteAtlas) {
        let scr = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1512, height: 948)
        let rect = NSRect(x: scr.maxX - currentSize - 20, y: scr.minY + 20,
                          width: currentSize, height: currentSize)
        window = FloatingWindow(contentRect: rect)

        gameView = GameView(frame: NSRect(x: 0, y: 0, width: currentSize, height: currentSize))
        gameView.wantsLayer = true
        gameView.backgrounds = backgrounds
        gameView.currentBg = backgrounds[.idle]
        gameView.atlas = atlas

        window.contentView = gameView
        window.makeKeyAndOrderFront(nil)
    }

    func startGameLoop() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self, let gv = self.gameView else { return }
            gv.character.update()
            gv.droneCtrl.update()
            gv.particles.update()
            gv.effectPhase += 1.0 / 30.0
            gv.updateBubbleAlpha()
            gv.applyStateEffects()
            self.updatePatrol(dt: 1.0 / 30.0)
            gv.needsDisplay = true
        }
    }

    func startStateServer() {
        stateServer = StateServer()
        stateServer.onEvent = { [weak self] evt in
            guard let self = self else { return }
            self.lastEventTime = Date()

            // Stop patrol + demo on any real event
            self.patrol.isPatrolling = false
            self.stopDemo()
            self.patrol.idleTime = 0

            if evt.state == .idle { self.explicitStop = true } else { self.explicitStop = false }

            // Special pose overrides based on event
            switch evt.event {
            case "UserPromptSubmit":
                // Salute then go to workstation
                self.gameView.character.currentPose = "saluting"
                Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                    let ws = ToolRouter.route(tool: evt.tool, event: evt.event, state: evt.state)
                    self?.goToWorkstation(ws, state: evt.state)
                }

            case "TaskCompleted":
                self.gameView.character.currentPose = "celebrating"
                Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    self?.goToWorkstation(ToolRouter.centerIdle, state: .idle)
                }

            case "PostToolUseFailure":
                self.gameView.character.currentPose = "confused"
                let ws = ToolRouter.route(tool: evt.tool, event: evt.event, state: evt.state)
                self.goToWorkstation(ws, state: evt.state)

            default:
                let ws = ToolRouter.route(tool: evt.tool, event: evt.event, state: evt.state)
                self.goToWorkstation(ws, state: evt.state)
            }

            if !evt.bubble.isEmpty { self.gameView.showBubble(evt.bubble) }

            // Speech (handles all voice + tool announcements)
            self.speech.onEvent(evt)

            // Drone = SubAgent + power-up SFX
            if evt.event == "SubagentStart" {
                self.gameView.droneCtrl.launchDrone()
                self.playSFX("power_up")
            }
            if evt.event == "SubagentStop" {
                self.gameView.droneCtrl.recallOne()
            }
        }
        stateServer.start(port: 45900)

        idleTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.currentState != .idle &&
               Date().timeIntervalSince(self.lastEventTime) > 8 {
                self.goToWorkstation(ToolRouter.centerIdle, state: .idle)
            }
        }
    }

    func goToWorkstation(_ ws: Workstation, state: UnaState) {
        let old = currentState
        currentState = state
        gameView.currentState = state
        gameView.character.walkTo(position: ws.position, pose: ws.pose)
        gameView.switchBackground(to: ws.background)

        // Drones are only recalled on SubagentStop, not on state change

        print("  \(old.rawValue) → \(state.rawValue) [\(ws.pose)]")
        playSound(state.rawValue)
    }


    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Menu bar icon from app icon
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            icon.size = NSSize(width: 18, height: 18)
            statusItem?.button?.image = icon
        } else {
            // Fallback: load from assets dir
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let iconFile = "\(home)/Documents/una/companion/assets/una-icon.png"
            if let icon = NSImage(contentsOfFile: iconFile) {
                icon.size = NSSize(width: 18, height: 18)
                statusItem?.button?.image = icon
            } else {
                statusItem?.button?.title = "U"
            }
        }
        let menu = NSMenu()

        let t = NSMenuItem(title: "una-cc v0.1", action: nil, keyEquivalent: "")
        t.isEnabled = false; menu.addItem(t)
        menu.addItem(NSMenuItem.separator())

        let sm = NSMenu()
        for (l, s) in [("Small (200)", 200), ("Medium (300)", 300), ("Large (380)", 380), ("XL (480)", 480), ("XXL (580)", 580)] as [(String, Int)] {
            let i = NSMenuItem(title: l, action: #selector(changeSize(_:)), keyEquivalent: "")
            i.tag = s; i.target = self
            if CGFloat(s) == currentSize { i.state = .on }
            sm.addItem(i)
        }
        let si = NSMenuItem(title: "Size", action: nil, keyEquivalent: ""); si.submenu = sm; menu.addItem(si)

        let soundItem = NSMenuItem(title: "Sound", action: #selector(toggleSound(_:)), keyEquivalent: "s")
        soundItem.target = self; soundItem.state = soundEnabled ? .on : .off
        menu.addItem(soundItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Demo Mode", action: #selector(triggerDemo), keyEquivalent: "d"))
        menu.items.last?.target = self

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func toggleSound(_ sender: NSMenuItem) {
        soundEnabled = !soundEnabled
        speech.enabled = soundEnabled
        sender.state = soundEnabled ? .on : .off
    }

    @objc func changeSize(_ sender: NSMenuItem) {
        currentSize = CGFloat(sender.tag)
        let f = window.frame
        let nf = NSRect(x: f.origin.x + (f.width - currentSize), y: f.origin.y,
                        width: currentSize, height: currentSize)
        window.setFrame(nf, display: true, animate: true)
        gameView.frame = NSRect(x: 0, y: 0, width: currentSize, height: currentSize)
        if let sm = statusItem?.menu?.item(withTitle: "Size")?.submenu {
            sm.items.forEach { $0.state = CGFloat($0.tag) == currentSize ? .on : .off }
        }
    }

    @objc func triggerDemo() {
        if demoRunning {
            stopDemo()
            goToWorkstation(ToolRouter.centerIdle, state: .idle)
        } else {
            startDemo()
        }
    }

    func updatePatrol(dt: CGFloat) {
        guard currentState == .idle else {
            // Wakeup if was sleeping/sitting
            if patrol.idleTime > 30 && (gameView.character.currentPose == "sleeping" || gameView.character.currentPose == "sitting") {
                speech.wakeUp()
            }
            patrol.isPatrolling = false
            patrol.idleTime = 0
            return
        }

        patrol.idleTime += dt

        // Phase 4: sleeping (60s+)
        if patrol.idleTime > 60 {
            if gameView.character.currentPose != "sleeping" {
                gameView.character.walkTo(position: CGPoint(x: 500, y: 680), pose: "sleeping")
                speech.goSleep()
            }
            return
        }

        // Phase 3: sitting (30-60s)
        if patrol.idleTime > 30 {
            if gameView.character.currentPose != "sitting" {
                gameView.character.walkTo(position: CGPoint(x: 500, y: 680), pose: "sitting")
            }
            return
        }

        // Idle chatter during patrol
        speech.tryIdleChatter()

        // Phase 2: patrol (8-30s)
        if !patrol.isPatrolling {
            if patrol.idleTime >= patrol.startDelay {
                patrol.isPatrolling = true
                patrol.stayTimer = 0
                let (pos, pose) = patrol.nextStop()
                gameView.character.walkTo(position: pos, pose: pose)
            }
        } else {
            if !gameView.character.isWalking {
                patrol.stayTimer += dt
                if patrol.stayTimer >= patrol.randomStayDuration() {
                    patrol.stayTimer = 0
                    let (pos, pose) = patrol.nextStop()
                    gameView.character.walkTo(position: pos, pose: pose)
                }
            }
        }
    }

    @objc func quit() {
        stateServer.stop(); NSApp.terminate(nil)
    }
}

// MARK: - Entry
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
