import AppKit
import SwiftUI

enum Activity: String, CaseIterable, Codable {
    case idle, explore, chase, ball, home, sleep, startled, carried
    var title: String {
        switch self {
        case .idle: return "发一会儿呆"
        case .explore: return "散步，看看四周"
        case .chase: return "偷偷跟着鼠标"
        case .ball: return "和小球玩"
        case .home: return "回自己的窝"
        case .sleep: return "窝里打盹"
        case .startled: return "吓了一跳"
        case .carried: return "被你提起来了"
        }
    }
}
struct Choice: Codable { let action: String; let probability: Double }
struct BrainReply: Codable {
    let action: String
    let probabilities: [Choice]
    let milliseconds: Double
}
struct Memory: Codable {
    var affection = 0.35
    var playCount = 0
    var greetingCount = 0
}
struct InteractionGate {
    private(set) var revision = 0
    private(set) var until = Date.distantPast
    mutating func hold(_ seconds: Double, now: Date = Date()) { revision += 1; until = now.addingTimeInterval(seconds) }
    func accepts(_ requestRevision: Int, now: Date = Date()) -> Bool { revision == requestRevision && now >= until }
}
func clamped(_ value: Double, _ lower: Double, _ upper: Double) -> Double { min(max(value, lower), max(lower, upper)) }
func inside(_ point: CGPoint, _ rect: CGRect, margin: CGFloat) -> CGPoint {
    .init(x: clamped(point.x, rect.minX + margin, rect.maxX - margin), y: clamped(point.y, rect.minY + margin, rect.maxY - margin))
}

@MainActor final class Life: ObservableObject {
    @Published var activity: Activity = .idle
    @Published var energy = 0.8
    @Published var affection = 0.35
    @Published var plays = 0
    @Published var bubble = "你好呀"
    @Published var gaze = CGSize.zero
    @Published var motion = 0.0
    @Published var moving = false
    @Published var paused = false
    @Published var quiet = false
    @Published var brain = "Laya 正在醒来"
    @Published var lastThought = "今天，从认识你开始。"
    @Published var choices: [Choice] = []
    @Published var latency = 0.0
    @Published var events = ["搬进了自己的小窝。"]
    @Published var modelReady = false
    var command: (Activity) -> Void = { _ in }
    var gate = InteractionGate()
    private var bubbleID = 0
    private let memoryURL: URL

    init(memoryURL: URL? = nil) {
        self.memoryURL = memoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Tuantuan/memory.json")
        if let data = try? Data(contentsOf: self.memoryURL), let memory = try? JSONDecoder().decode(Memory.self, from: data) {
            affection = clamped(memory.affection, 0, 1); plays = max(0, memory.playCount)
            bubble = "又见面啦"; lastThought = "记得你，也记得我们玩过的小球。"
        }
    }
    func save() {
        do {
            try FileManager.default.createDirectory(at: memoryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(Memory(affection: affection, playCount: plays)).write(to: memoryURL, options: .atomic)
        } catch { lastThought = "这次的记忆没能保存，仍然可以继续玩。" }
    }
    func say(_ message: String, seconds: Double = 2.5) {
        bubbleID += 1; let id = bubbleID; bubble = message
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            if self?.bubbleID == id { self?.bubble = "" }
        }
    }
    func record(_ message: String) { lastThought = message; events.insert(message, at: 0); events = Array(events.prefix(5)) }
    func pet() {
        gate.hold(5); activity = .idle; affection = min(1, affection + 0.025)
        say("♡"); record("眯着眼睛，蹭了蹭你的手。"); command(.idle)
    }
    func play() {
        guard !paused else { say("先让我继续活动吧"); return }
        gate.hold(22); activity = .ball; plays += 1; energy = max(0.1, energy - 0.02)
        say("小球！"); record("第 \(plays) 次一起玩球。"); command(.ball)
    }
    func goHome() { gate.hold(90); activity = .home; say("回窝啦"); record("准备回窝，舒舒服服睡一会儿。"); command(.home) }
    func wake() { gate.hold(5); activity = .idle; say("睡好啦"); command(.idle) }
    func pause() { gate.hold(1); paused.toggle(); say(paused ? "等你回来" : "继续玩吧") }
    func toggleQuiet() { quiet.toggle(); gate.hold(5); activity = .idle; command(.idle); say(quiet ? "安静陪你" : "去玩啦") }
    func beginCarry() { gate.hold(5); activity = .carried; say("轻一点～") }
    func endCarry() { gate.hold(5); activity = .idle; say("整理一下毛"); record("被你放到了一个新地方。"); command(.idle) }
    func apply(_ reply: BrainReply, revision: Int) {
        modelReady = true; brain = "Laya · 本机运行"; latency = reply.milliseconds
        guard gate.accepts(revision), !paused, activity != .carried else { return }
        choices = reply.probabilities
        guard var next = Activity(rawValue: reply.action), [.idle, .explore, .chase, .ball, .home].contains(next) else { return }
        if quiet && next != .home { next = .idle }
        if energy < 0.18 { next = .home }
        activity = next; lastThought = next.title; command(next)
        gate.hold(next == .home ? 60 : 7)
    }
}
