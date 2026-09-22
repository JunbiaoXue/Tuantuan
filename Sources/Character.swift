import SwiftUI

struct TuantuanCharacter: View {
    let phase: Double
    let sleeping: Bool
    let happy: Bool
    let lifted: Bool
    let gaze: CGSize
    let motion: Double
    let moving: Bool
    private let ink = Color(red: 0.26, green: 0.22, blue: 0.22)
    private let fur = Color(red: 0.94, green: 0.86, blue: 0.74)
    private var blink: Bool { phase.truncatingRemainder(dividingBy: 5.2) > 5.04 }
    var body: some View {
        let bounce = moving ? abs(sin(phase * 10)) * -5 : sin(phase * 2) * 1.5
        ZStack {
            // Tail remains behind the body, with a slow independent swish.
            Capsule().fill(fur).overlay(Capsule().stroke(ink.opacity(0.2), lineWidth: 1.3))
                .frame(width: 43, height: 23).rotationEffect(.degrees(-35 + sin(phase * 2.4) * 16))
                .offset(x: 53, y: 33)
            HStack(spacing: 47) {
                ear(angle: -23 + gaze.width * 5)
                ear(angle: 23 + gaze.width * 5)
            }.offset(y: sleeping ? -15 : -34)
            HStack(spacing: 45) {
                paw.rotationEffect(.degrees(lifted ? sin(phase * 14) * 20 : 0))
                paw.rotationEffect(.degrees(lifted ? -sin(phase * 14) * 20 : 0))
            }.offset(y: lifted ? 59 : 50)
            FuzzyBody().fill(LinearGradient(colors: [.init(red: 1, green: 0.97, blue: 0.90), fur], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(FuzzyBody().stroke(ink.opacity(0.24), lineWidth: 1.4))
                .frame(width: sleeping ? 125 : 116, height: lifted ? 125 : (sleeping ? 78 : 104))
                .shadow(color: ink.opacity(0.10), radius: 4, y: 3)
            Ellipse().fill(.white.opacity(0.30)).frame(width: 65, height: 46).offset(y: 21)
            HStack(spacing: 38) {
                eye
                eye
            }.offset(x: sleeping ? 2 : gaze.width * 3, y: sleeping ? 5 : -1)
            HStack(spacing: 52) {
                Ellipse().fill(Color.pink.opacity(happy ? 0.5 : 0.23)).frame(width: 19, height: 10)
                Ellipse().fill(Color.pink.opacity(happy ? 0.5 : 0.23)).frame(width: 19, height: 10)
            }.offset(y: 17)
            VStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 3).fill(ink).frame(width: 7, height: 5)
                Mouth().stroke(ink, style: StrokeStyle(lineWidth: 1.7, lineCap: .round)).frame(width: 17, height: 7)
            }.offset(x: gaze.width * 2, y: 12)
            if sleeping {
                Text("z z").font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(ink.opacity(0.5)).offset(x: 48, y: -36 + sin(phase) * 4)
            }
        }
        .scaleEffect(x: lifted ? 0.9 : 1 + sin(phase * 2) * 0.012, y: lifted ? 1.08 : 1)
        .rotationEffect(.degrees(lifted ? sin(phase * 7) * 6 : motion * 5))
        .offset(y: sleeping ? 18 : bounce + 8)
    }
    private var paw: some View {
        Capsule().fill(fur).overlay(Capsule().stroke(ink.opacity(0.2), lineWidth: 1))
            .frame(width: 23, height: 17)
    }
    private func ear(angle: Double) -> some View {
        ZStack {
            Capsule().fill(fur).overlay(Capsule().stroke(ink.opacity(0.2), lineWidth: 1.3)).frame(width: 29, height: 45)
            Capsule().fill(Color(red: 0.85, green: 0.64, blue: 0.60).opacity(0.7)).frame(width: 14, height: 27)
        }.rotationEffect(.degrees(angle))
    }
    @ViewBuilder private var eye: some View {
        if sleeping || happy || blink {
            ClosedEye().stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).frame(width: 12, height: 6)
        } else {
            ZStack {
                Ellipse().fill(ink).frame(width: 12, height: lifted ? 17 : 15)
                Circle().fill(.white).frame(width: 4, height: 4).offset(x: -2 + gaze.width, y: -3 + gaze.height)
            }
        }
    }
}
struct FuzzyBody: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let n = 100
        for i in 0...n {
            let a = Double(i) / Double(n) * .pi * 2
            let tuft = 1 + 0.019 * sin(a * 17) + 0.008 * cos(a * 29)
            let pt = CGPoint(x: r.midX + cos(a) * r.width * 0.48 * tuft,
                             y: r.midY + sin(a) * r.height * 0.47 * tuft)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath(); return p
    }
}
struct Mouth: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: .init(x: 0, y: 1))
        p.addQuadCurve(to: .init(x: r.midX, y: 1), control: .init(x: r.width * 0.25, y: r.maxY))
        p.addQuadCurve(to: .init(x: r.maxX, y: 1), control: .init(x: r.width * 0.75, y: r.maxY)); return p
    }
}
struct ClosedEye: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: .init(x: 0, y: 0))
        p.addQuadCurve(to: .init(x: r.maxX, y: 0), control: .init(x: r.midX, y: r.maxY)); return p
    }
}

struct NestView: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Color(red: 0.65, green: 0.72, blue: 0.59)).frame(width: 132, height: 48)
            Ellipse().fill(Color(red: 0.35, green: 0.44, blue: 0.32)).frame(width: 109, height: 33).offset(y: -5)
            Ellipse().fill(Color(red: 0.83, green: 0.87, blue: 0.74)).frame(width: 91, height: 22).offset(y: -3)
            Text("团团").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8)).offset(y: 16)
        }.frame(width: 160, height: 70)
    }
}
struct BallView: View {
    var body: some View {
        Circle().fill(LinearGradient(colors: [.init(red: 0.96, green: 0.71, blue: 0.57), .init(red: 0.83, green: 0.42, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 2).padding(5))
            .overlay(Circle().fill(.white.opacity(0.7)).frame(width: 6, height: 6).offset(x: -5, y: 6))
            .padding(5).frame(width: 38, height: 38)
    }
}
