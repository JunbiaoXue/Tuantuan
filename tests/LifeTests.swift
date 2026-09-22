import XCTest
@testable import Tuantuan

final class LifeTests: XCTestCase {
    func testLateModelReplyCannotOverrideUserInteraction() {
        var gate = InteractionGate()
        let before = gate.revision
        let now = Date(timeIntervalSince1970: 100)
        gate.hold(5, now: now)
        XCTAssertFalse(gate.accepts(before, now: now.addingTimeInterval(100)))
        XCTAssertFalse(gate.accepts(gate.revision, now: now.addingTimeInterval(2)))
        XCTAssertTrue(gate.accepts(gate.revision, now: now.addingTimeInterval(6)))
    }
    func testClampingHandlesSmallAndNegativeScreens() {
        let screen = CGRect(x: -1280, y: 0, width: 1280, height: 800)
        let p = inside(CGPoint(x: -2000, y: 2000), screen, margin: 90)
        XCTAssertEqual(p, CGPoint(x: -1190, y: 710))
        XCTAssertTrue(clamped(10, 50, 20).isFinite)
    }
    @MainActor func testPettingSupersedesSleepAndIncreasesTrust() {
        let life = freshLife(); life.goHome(); let before = life.affection
        life.pet()
        XCTAssertEqual(life.activity, .idle); XCTAssertGreaterThan(life.affection, before)
        XCTAssertEqual(life.bubble, "♡")
    }
    @MainActor func testPlayIsIgnoredWhilePaused() {
        let life = freshLife(); life.pause(); life.play()
        XCTAssertEqual(life.plays, 0)
    }
    @MainActor func testQuietModeBlocksModelChase() {
        let life = freshLife(); life.quiet = true
        life.apply(reply("chase"), revision: life.gate.revision)
        XCTAssertEqual(life.activity, .idle)
    }
    @MainActor func testExhaustedPetReturnsHome() {
        let life = freshLife(); life.energy = 0.05
        life.apply(reply("ball"), revision: life.gate.revision)
        XCTAssertEqual(life.activity, .home)
    }
    @MainActor func testUnknownActionDoesNotStartMotion() {
        let life = freshLife(); life.apply(reply("unknown"), revision: life.gate.revision)
        XCTAssertEqual(life.activity, .idle)
    }
    @MainActor func testPersistentMemoryRestoresTrustAndPlayCount() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("memory.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = Life(memoryURL: url); first.pet(); first.play(); first.save()
        let second = Life(memoryURL: url)
        XCTAssertEqual(second.plays, 1); XCTAssertEqual(first.affection, second.affection)
        XCTAssertEqual(second.bubble, "又见面啦")
    }
    @MainActor func freshLife() -> Life { Life(memoryURL: URL(fileURLWithPath: "/tmp/tuantuan-test-\(UUID().uuidString)/memory.json")) }
    func reply(_ action: String) -> BrainReply { BrainReply(action: action, probabilities: [Choice(action: action, probability: 1)], milliseconds: 10) }
}
