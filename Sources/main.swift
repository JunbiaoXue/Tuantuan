import AppKit
import SwiftUI

@MainActor final class Application: NSObject, NSApplicationDelegate {
    let life = Life()
    let brain = LocalBrain()
    var desktop: Desktop!
    var home: NSWindow!
    var status: NSStatusItem?
    var decisions: Timer?
    var saving: Timer?
    var thinking = false
    var failures = 0
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--render") { renderArtifacts(); NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu(), appMenu = NSMenu(), item = NSMenuItem()
        appMenu.addItem(withTitle: "团团的小屋…", action: #selector(showHome), keyEquivalent: "1").target = self
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "退出团团", action: #selector(quit), keyEquivalent: "q").target = self
        item.submenu = appMenu; menu.addItem(item); NSApp.mainMenu = menu
        desktop = Desktop(life: life); desktop.panelRequest = { [weak self] in self?.showHome() }
        home = NSWindow(contentViewController: NSHostingController(rootView: HomeView(life: life, reset: { [weak self] in self?.desktop.resetPositions() })))
        home.title = "团团的小屋"; home.styleMask = [.titled, .closable, .miniaturizable]; home.isReleasedWhenClosed = false
        home.titlebarAppearsTransparent = true; home.backgroundColor = NSColor(red: 0.95, green: 0.94, blue: 0.87, alpha: 1); home.center()
        desktop.start(); showHome()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status?.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "团团")
        status?.menu = desktop.menu()
        decisions = Timer.scheduledTimer(withTimeInterval: 7, repeats: true) { [weak self] _ in Task { @MainActor in self?.think() } }
        saving = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in Task { @MainActor in self?.life.save() } }
        think(); life.say(life.bubble, seconds: 4)
    }
    func think() {
        guard !thinking, !life.paused, life.activity != .carried else { return }
        if life.modelReady && Date() < life.gate.until { return }
        if failures > 0 && failures % 4 != 0 { failures += 1; return }
        thinking = true
        let revision = life.gate.revision, p = desktop.middle(desktop.pet), mouse = NSEvent.mouseLocation
        let state: [String: Any] = ["energy": life.energy, "trust": life.affection, "last_activity": life.activity.rawValue,
                                   "pointer_distance": Int(hypot(p.x - mouse.x, p.y - mouse.y)), "quiet_requested": life.quiet,
                                   "played_together": life.plays, "personality": "curious, shy, gentle",
                                   "recent_events": Array(life.events.prefix(2))]
        brain.decide(state) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }; self.thinking = false
                switch result {
                case .success(let reply): self.failures = 0; self.life.apply(reply, revision: revision)
                case .failure:
                    self.failures += 1; self.life.modelReady = false; self.life.brain = "Laya 暂不可用 · 基础互动可用"
                    if self.life.gate.accepts(revision), !self.life.paused { self.life.lastThought = "先安静待着，你仍然可以摸头、玩球和叫它回窝。" }
                }
            }
        }
    }
    @objc func showHome() { home?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showHome(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { guard !CommandLine.arguments.contains("--render") else { return }; decisions?.invalidate(); saving?.invalidate(); desktop?.stop(); life.save(); brain.stop() }
    func renderArtifacts() {
        let directory = URL(fileURLWithPath: CommandLine.arguments.last!)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func render<V: View>(_ view: V, _ name: String, scale: Double = 2) {
            let renderer = ImageRenderer(content: view); renderer.scale = scale
            if let cg = renderer.cgImage { let bitmap = NSBitmapImageRep(cgImage: cg); try? bitmap.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent(name)) }
        }
        render(AppIcon(), "icon.png")
        render(HomeView(life: life, reset: {}), "团团预览.png")
        render(HStack(spacing: 20) {
            ForEach(0..<4) { i in
                TuantuanCharacter(phase: 1, sleeping: i == 1, happy: i == 2, lifted: i == 3, gaze: .zero, motion: 0, moving: false).frame(width: 170, height: 190)
            }
        }.padding(20).background(Color(red: 0.97, green: 0.96, blue: 0.92)), "角色状态.png")
    }
}
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = Application()
    app.delegate = delegate
    app.run()
}
