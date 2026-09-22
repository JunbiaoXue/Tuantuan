import SwiftUI

struct HomeView: View {
    @ObservedObject var life: Life
    var reset: () -> Void
    private let ink = Color(red: 0.24, green: 0.28, blue: 0.23)
    private let sage = Color(red: 0.39, green: 0.49, blue: 0.35)
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Circle().fill(sage).frame(width: 6, height: 6)
                    Text("一个小小的桌面住客").font(.system(size: 11, weight: .medium)).tracking(1)
                }.foregroundStyle(sage)
                Text("团团").font(.system(size: 43, weight: .semibold, design: .rounded)).padding(.top, 14)
                Text("有自己的小日子，也喜欢你。").font(.system(size: 13)).foregroundStyle(ink.opacity(0.6)).padding(.top, 5)
                Spacer(minLength: 5)
                ZStack {
                    Circle().fill(Color(red: 0.90, green: 0.90, blue: 0.80)).frame(width: 228, height: 228)
                    Circle().stroke(.white.opacity(0.65), lineWidth: 1).frame(width: 250, height: 250)
                    NestView().offset(y: 66)
                    TuantuanCharacter(phase: 1.1, sleeping: life.activity == .sleep, happy: life.bubble == "♡", lifted: false, gaze: .zero, motion: 0, moving: false).scaleEffect(1.32).offset(y: 8)
                    BallView().offset(x: 87, y: 83)
                }.frame(maxWidth: .infinity).frame(height: 260)
                Spacer(minLength: 4)
                Text(life.activity.title).font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity)
                Text("摸摸它，或者给它一点自己的时间。")
                    .font(.system(size: 11)).foregroundStyle(ink.opacity(0.52)).frame(maxWidth: .infinity).padding(.top, 7)
            }
            .padding(28).frame(width: 310)
            .background(Color(red: 0.95, green: 0.94, blue: 0.87))
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("今天的小生活").font(.system(size: 19, weight: .semibold))
                    Spacer()
                    Text("本地陪伴").font(.system(size: 10, weight: .medium)).padding(.horizontal, 9).padding(.vertical, 5).background(sage.opacity(0.09), in: Capsule())
                }
                HStack(spacing: 22) {
                    meter("精力", life.energy, "sun.max")
                    meter("熟悉你", life.affection, "heart")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("一起做点什么").font(.system(size: 12, weight: .medium)).foregroundStyle(ink.opacity(0.55))
                    HStack(spacing: 10) {
                        interaction("摸摸头", "hand.draw", { life.pet() })
                        interaction("丢小球", "circle.dotted", { life.play() })
                        interaction(life.activity == .sleep ? "叫醒它" : "回窝睡", "moon", { life.activity == .sleep ? life.wake() : life.goHome() })
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("刚刚发生").font(.system(size: 12, weight: .medium)).foregroundStyle(ink.opacity(0.55))
                        Spacer(); Text("玩球 \(life.plays) 次").font(.system(size: 10)).foregroundStyle(ink.opacity(0.45))
                    }
                    ForEach(Array(life.events.prefix(3).enumerated()), id: \.offset) { index, event in
                        HStack(alignment: .top, spacing: 9) {
                            Circle().fill(sage.opacity(index == 0 ? 0.7 : 0.25)).frame(width: 5, height: 5).padding(.top, 5)
                            Text(event).font(.system(size: 12)).foregroundStyle(ink.opacity(index == 0 ? 0.9 : 0.55)).lineLimit(2)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.frame(height: 96, alignment: .top)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        Circle().fill(life.modelReady ? sage : Color.orange).frame(width: 6, height: 6)
                        Text(life.brain).font(.system(size: 11, weight: .medium))
                        Spacer()
                        if life.modelReady { Text("\(Int(life.latency)) ms").font(.system(size: 10, design: .monospaced)).foregroundStyle(ink.opacity(0.4)) }
                    }
                    Text(life.lastThought).font(.system(size: 11)).foregroundStyle(ink.opacity(0.55)).lineLimit(2)
                }.padding(13).frame(maxWidth: .infinity, alignment: .leading).background(sage.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                HStack {
                    Button(life.quiet ? "恢复自在活动" : "安静陪我") { life.toggleQuiet() }
                    Spacer()
                    Button(life.paused ? "继续" : "暂停") { life.pause() }
                    Button("找回团团") { reset() }
                }.font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(sage)
                Text("点击摸头 · 拖动提起 · 右键更多\n窝可以拖动；会记住窝的位置、亲密度和玩球次数。")
                    .font(.system(size: 10)).foregroundStyle(ink.opacity(0.43)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }.padding(28).frame(width: 418).background(Color(red: 0.99, green: 0.98, blue: 0.94))
        }.foregroundStyle(ink).frame(width: 728, height: 540)
    }
    func meter(_ title: String, _ value: Double, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack { Label(title, systemImage: icon); Spacer(); Text("\(Int(value * 100))").monospacedDigit() }
                .font(.system(size: 11)).foregroundStyle(ink.opacity(0.7))
            GeometryReader { g in
                Capsule().fill(sage.opacity(0.1)).overlay(alignment: .leading) { Capsule().fill(sage.opacity(0.7)).frame(width: max(3, g.size.width * value)) }
            }.frame(height: 5)
        }
    }
    func interaction(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 19, weight: .light))
                Text(title).font(.system(size: 12, weight: .medium))
            }.frame(maxWidth: .infinity).frame(height: 76).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(sage.opacity(0.13), lineWidth: 1))
        }.buttonStyle(.plain).foregroundStyle(ink)
    }
}
struct AppIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 104).fill(LinearGradient(colors: [.init(red: 0.91, green: 0.94, blue: 0.82), .init(red: 0.71, green: 0.80, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(.white.opacity(0.23)).frame(width: 345, height: 345).offset(y: -5)
            TuantuanCharacter(phase: 1, sleeping: false, happy: false, lifted: false, gaze: .zero, motion: 0, moving: false).scaleEffect(2.85).offset(y: 12)
        }.padding(20).frame(width: 512, height: 512)
    }
}
