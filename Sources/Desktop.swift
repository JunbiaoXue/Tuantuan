import AppKit
import SwiftUI

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor final class TouchSurface: NSView {
    var click: () -> Void = {}
    var dragStart: () -> Void = {}
    var dragEnd: () -> Void = {}
    var context: () -> NSMenu = { NSMenu() }
    var down = CGPoint.zero
    var origin = CGPoint.zero
    var dragging = false
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.insetBy(dx: 12, dy: 8).contains(point) ? self : nil }
    override func mouseDown(with event: NSEvent) {
        down = NSEvent.mouseLocation; origin = window?.frame.origin ?? .zero; dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        let cursor = NSEvent.mouseLocation
        if !dragging && hypot(cursor.x - down.x, cursor.y - down.y) > 4 { dragging = true; dragStart() }
        if dragging { window?.setFrameOrigin(.init(x: origin.x + cursor.x - down.x, y: origin.y + cursor.y - down.y)) }
    }
    override func mouseUp(with event: NSEvent) { if dragging { dragEnd() } else { click() }; dragging = false }
    override func rightMouseDown(with event: NSEvent) { NSMenu.popUpContextMenu(context(), with: event, for: self) }
}

@MainActor final class Desktop: NSObject {
    let life: Life
    var pet: PetPanel!
    var nest: PetPanel!
    var ball: PetPanel!
    var timer: Timer?
    var target: CGPoint?
    var lastMouse = NSEvent.mouseLocation
    var lastStartle = Date.distantPast
    var lastNudge = Date.distantPast
    var ballVelocity = CGPoint.zero
    var lastTick = Date()
    var panelRequest: () -> Void = {}
    var ballTouches = 0
    private var screenObserver: NSObjectProtocol?

    init(life: Life) {
        self.life = life
        super.init()
        pet = panel(size: .init(width: 180, height: 180), content: PetDrawing(life: life))
        nest = panel(size: .init(width: 160, height: 70), content: NestView())
        ball = panel(size: .init(width: 38, height: 38), content: BallView())
        nest.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        pet.title = "团团 · 桌面宠物"; nest.title = "团团 · 小窝"; ball.title = "团团 · 小球"
        configureTouches()
        resetPositions()
        life.command = { [weak self] action in self?.respond(action) }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.resetPositions() }
        }
    }
    private func panel<V: View>(size: NSSize, content: V) -> PetPanel {
        let p = PetPanel(contentRect: .init(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false; p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; p.hidesOnDeactivate = false; p.isReleasedWhenClosed = false
        let surface = TouchSurface(frame: .init(origin: .zero, size: size))
        let view = NSHostingView(rootView: content); view.frame = surface.bounds; view.autoresizingMask = [.width, .height]
        surface.addSubview(view); p.contentView = surface; return p
    }
    private func configureTouches() {
        let surface = pet.contentView as! TouchSurface
        surface.click = { [weak self] in self?.life.pet() }
        surface.dragStart = { [weak self] in self?.life.beginCarry() }
        surface.dragEnd = { [weak self] in self?.constrainPet(); self?.life.endCarry() }
        surface.context = { [weak self] in self?.menu() ?? NSMenu() }
        (nest.contentView as! TouchSurface).click = { [weak self] in self?.life.goHome() }
        (nest.contentView as! TouchSurface).dragEnd = { [weak self] in self?.constrainProps(); self?.saveNest() }
        (ball.contentView as! TouchSurface).click = { [weak self] in self?.life.play() }
        (ball.contentView as! TouchSurface).dragStart = { [weak self] in self?.ballVelocity = .zero }
        (ball.contentView as! TouchSurface).dragEnd = { [weak self] in self?.constrainProps(); self?.life.play() }
    }
    func menu() -> NSMenu {
        let menu = NSMenu()
        for (name, action) in [("团团的小屋…", #selector(openPanel)), ("摸摸头", #selector(petHead)), ("丢个小球", #selector(playBall)), ("回窝睡觉", #selector(goHome)), ("退出团团", #selector(quit))] {
            let item = NSMenuItem(title: name, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        return menu
    }
    @objc func openPanel() { panelRequest() }
    @objc func petHead() { life.pet() }
    @objc func playBall() { life.play() }
    @objc func goHome() { life.goHome() }
    @objc func quit() { NSApp.terminate(nil) }
    func start() {
        [nest, ball, pet].forEach { $0?.orderFrontRegardless() }
        lastTick = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.step() }
        }
    }
    func stop() { timer?.invalidate(); saveNest(); if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) } }
    func resetPositions() {
        guard let frame = NSScreen.main?.visibleFrame else { return }
        var home = CGPoint(x: frame.maxX - 160, y: frame.minY + 62)
        if let saved = UserDefaults.standard.array(forKey: "nestPosition") as? [Double], saved.count == 2 {
            let candidate = CGPoint(x: saved[0], y: saved[1])
            if NSScreen.screens.contains(where: { $0.visibleFrame.insetBy(dx: 90, dy: 90).contains(candidate) }) { home = candidate }
        }
        center(nest, at: home)
        center(pet, at: .init(x: home.x - 165, y: home.y + 100))
        center(ball, at: .init(x: home.x - 90, y: home.y + 25))
        target = nil; ballVelocity = .zero; constrainPet(); constrainProps()
    }
    func saveNest() { let c = middle(nest); UserDefaults.standard.set([c.x, c.y], forKey: "nestPosition") }
    func middle(_ w: NSWindow) -> CGPoint { .init(x: w.frame.midX, y: w.frame.midY) }
    func center(_ w: NSWindow, at p: CGPoint) { w.setFrameOrigin(.init(x: p.x - w.frame.width / 2, y: p.y - w.frame.height / 2)) }
    func screenRect(for p: CGPoint) -> CGRect {
        let frames = NSScreen.screens.map(\.visibleFrame)
        if let match = frames.first(where: { $0.contains(p) }) { return match }
        return frames.min(by: { distance(inside(p, $0, margin: 0), p) < distance(inside(p, $1, margin: 0), p) }) ?? .init(x: 0, y: 0, width: 1000, height: 800)
    }
    func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }
    func constrainPet() { let p = middle(pet); center(pet, at: inside(p, screenRect(for: p), margin: 90)) }
    func constrainProps() {
        for w in [nest!, ball!] { let p = middle(w); center(w, at: inside(p, screenRect(for: p), margin: w == nest ? 85 : 22)) }
    }
    func respond(_ action: Activity) {
        let p = middle(pet); let rect = screenRect(for: p)
        switch action {
        case .idle, .sleep: target = nil
        case .explore: target = inside(.init(x: p.x + Double.random(in: -190...190), y: p.y + Double.random(in: -95...95)), rect, margin: 90)
        case .home: target = homeTarget()
        case .ball:
            ballTouches = 0
            let b = middle(ball)
            if distance(p, b) > 600 { center(ball, at: inside(.init(x: p.x + 110, y: p.y - 25), rect, margin: 25)) }
            ballVelocity = .init(x: Double.random(in: -55...55), y: 25)
            target = middle(ball)
        case .chase: target = nil
        case .startled, .carried: break
        }
    }
    func homeTarget() -> CGPoint {
        let n = middle(nest)
        return inside(.init(x: n.x, y: n.y + 30), screenRect(for: n), margin: 90)
    }
    func step() {
        let now = Date(); let dt = min(0.05, now.timeIntervalSince(lastTick)); lastTick = now
        let mouse = NSEvent.mouseLocation
        let p = middle(pet)
        let delta = CGPoint(x: mouse.x - p.x, y: mouse.y - p.y)
        let d = max(1, hypot(delta.x, delta.y))
        pet.ignoresMouseEvents = life.activity != .carried && (pow(delta.x / 78, 2) + pow(delta.y / 70, 2) > 1)
        life.gaze = .init(width: clamped(delta.x / d, -1, 1), height: -clamped(delta.y / d, -1, 1))
        defer { lastMouse = mouse }
        guard !life.paused, life.activity != .carried else { life.moving = false; return }
        life.energy = clamped(life.energy + (life.activity == .sleep ? 0.008 : -0.00045) * dt, 0, 1)
        let cursorSpeed = distance(mouse, lastMouse) / max(0.01, dt)
        if !life.quiet, d < 65, cursorSpeed > 1100, now.timeIntervalSince(lastStartle) > 12, life.activity != .sleep {
            lastStartle = now; life.gate.hold(3); life.activity = .startled; life.say("呀！")
            target = inside(.init(x: p.x - delta.x / d * 100, y: p.y - delta.y / d * 80), screenRect(for: p), margin: 90)
        }
        updateBall(dt)
        if life.activity == .chase {
            target = inside(.init(x: mouse.x - delta.x / d * 90, y: mouse.y - delta.y / d * 90), screenRect(for: p), margin: 90)
        } else if life.activity == .home { target = homeTarget() }
        else if life.activity == .ball {
            let b = middle(ball); target = inside(.init(x: b.x, y: b.y + 25), screenRect(for: b), margin: 90)
            if distance(p, target!) < 38 && now.timeIntervalSince(lastNudge) > 1.5 {
                lastNudge = now; ballTouches += 1
                let direction: Double = b.x >= p.x ? 1 : -1
                ballVelocity = .init(x: direction * 160, y: Double.random(in: -35...65))
                life.say(ballTouches > 2 ? "还会滚耶" : "嘿！")
                if ballTouches >= 4 { life.activity = .idle; target = nil; life.record("推了几下小球，满意地坐下。") }
            }
        }
        guard let goal = target else { life.moving = false; life.motion *= 0.8; return }
        let dx = goal.x - p.x, dy = goal.y - p.y, remaining = hypot(dx, dy)
        if remaining < 4 {
            life.moving = false; life.motion = 0
            if life.activity == .home { life.activity = .sleep; life.record("窝里正暖和，团团睡着了。") }
            else if life.activity == .startled || life.activity == .explore { life.activity = .idle }
            if life.activity != .ball { target = nil }; return
        }
        let speed: Double = life.activity == .startled ? 220 : life.activity == .ball ? 125 : life.activity == .home ? 80 : 62
        let step = min(remaining, speed * dt)
        let next = inside(.init(x: p.x + dx / remaining * step, y: p.y + dy / remaining * step), screenRect(for: p), margin: 90)
        center(pet, at: next); life.moving = true; life.motion = dx / remaining
    }
    private func updateBall(_ dt: Double) {
        guard !(ball.contentView as! TouchSurface).dragging else { return }
        let p = middle(ball), r = screenRect(for: p)
        let raw = CGPoint(x: p.x + ballVelocity.x * dt, y: p.y + ballVelocity.y * dt)
        let next = inside(raw, r, margin: 22)
        if next.x != raw.x { ballVelocity.x *= -0.7 }
        if next.y != raw.y { ballVelocity.y *= -0.7 }
        ballVelocity.x *= pow(0.98, dt * 30); ballVelocity.y *= pow(0.98, dt * 30)
        center(ball, at: next)
    }
}
struct PetDrawing: View {
    @ObservedObject var life: Life
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: life.paused)) { context in
            ZStack {
                TuantuanCharacter(phase: context.date.timeIntervalSinceReferenceDate, sleeping: life.activity == .sleep, happy: life.bubble == "♡", lifted: life.activity == .carried, gaze: life.gaze, motion: life.motion, moving: life.moving)
                if !life.bubble.isEmpty {
                    Text(life.bubble).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Color(red: 0.32, green: 0.26, blue: 0.23))
                        .padding(.horizontal, 12).padding(.vertical, 6).background(.white.opacity(0.95), in: Capsule()).offset(y: -65)
                }
            }
        }.frame(width: 180, height: 180)
    }
}
