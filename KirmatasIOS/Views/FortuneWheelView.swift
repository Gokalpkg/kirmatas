import SwiftUI

struct FortuneWheelView: View {
    @ObservedObject private var save = SaveManager.shared
    @ObservedObject private var ads = AdManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var prize: WheelSector?
    @State private var message: String?

    private let sectors: [WheelSector] = WheelSector.all

    var body: some View {
        ZStack {
            Color(hex: 0xF0101320).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Label(I18n.pick("ŞANS ÇARKI", "LUCKY WHEEL"), systemImage: "star.fill")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: 0xFFFFD54F))
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .disabled(spinning)
                }

                Text(save.canSpinFortuneWheel
                     ? I18n.pick("Bugün kalan hak", "Spins left today") + ": \(save.remainingWheelSpins) / 3"
                     : I18n.pick("Günlük hak bitti. Yarın tekrar gel.", "No spins left today. Come back tomorrow."))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(save.canSpinFortuneWheel ? Color(hex: 0xFF00E5FF) : Color(hex: 0xFFFF8A80))

                ZStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: 0xFFFFD54F))
                        .offset(y: -128)
                    wheel
                        .frame(width: 260, height: 260)
                        .rotationEffect(.radians(rotation))
                }
                .padding(.top, 8)

                Button {
                    spinAfterAd()
                } label: {
                    Text(I18n.tr("watch_ad_spin"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(save.canSpinFortuneWheel ? Color(hex: 0xFFFFD54F) : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(spinning || !save.canSpinFortuneWheel || ads.isShowing)

                if let message {
                    Text(message)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(22)
        }
        .alert(prize.map { I18n.name($0.label) } ?? "", isPresented: Binding(
            get: { prize != nil },
            set: { if !$0 { prize = nil } }
        )) {
            Button(I18n.pick("HARİKA", "AWESOME")) { prize = nil }
        } message: {
            Text(prize.map { I18n.name($0.subtitle) + "\n" + I18n.pick("Ödül hesabına aktarıldı.", "Reward added to your account.") } ?? "")
        }
    }

    private var wheel: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let sweep = (2 * Double.pi) / Double(sectors.count)
            for (index, sector) in sectors.enumerated() {
                var path = Path()
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .radians(Double(index) * sweep - .pi / 2),
                    endAngle: .radians(Double(index + 1) * sweep - .pi / 2),
                    clockwise: false
                )
                path.closeSubpath()
                context.fill(path, with: .color(sector.color))
                let mid = Double(index) * sweep + sweep / 2 - .pi / 2
                let labelPoint = CGPoint(
                    x: center.x + CGFloat(cos(mid) * radius * 0.62),
                    y: center.y + CGFloat(sin(mid) * radius * 0.62)
                )
                context.draw(
                    Text(I18n.name(sector.label))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.black),
                    at: labelPoint
                )
            }
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36)),
                with: .color(Color(hex: 0xFF101320))
            )
        }
    }

    private func spinAfterAd() {
        guard save.canSpinFortuneWheel, !spinning else {
            message = I18n.pick("Bugünkü 3 çark hakkını kullandın.", "You used all 3 spins for today.")
            return
        }
        ads.watchSkippableAd {
            guard save.recordWheelSpin() else { return }
            spin()
        }
        if let note = ads.statusMessage {
            message = note
        }
    }

    private func spin() {
        spinning = true
        let weights = [2.5, 4.5, 6.0, 9.0, 20.0, 10.0, 23.0, 25.0]
        var roll = Double.random(in: 0...weights.reduce(0, +))
        var target = 0
        for (index, weight) in weights.enumerated() {
            if roll <= weight {
                target = index
                break
            }
            roll -= weight
        }
        let sweep = (2 * Double.pi) / Double(sectors.count)
        let targetOffset = (3 * Double.pi / 2) - (Double(target) * sweep + sweep / 2)
        let turns = Double(5 + Int.random(in: 0...2)) * 2 * Double.pi
        let finalRotation = rotation + turns + (targetOffset - rotation.truncatingRemainder(dividingBy: 2 * .pi))
        withAnimation(.easeOut(duration: 4.6)) {
            rotation = finalRotation
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
            let sector = sectors[target]
            sector.claim(save)
            AudioManager.shared.playSfx(.ulti)
            prize = sector
            spinning = false
        }
    }
}

struct WheelSector: Identifiable {
    let id = UUID()
    let label: String
    let subtitle: String
    let color: Color
    let claim: (SaveManager) -> Void

    static let all: [WheelSector] = [
        WheelSector(label: "500", subtitle: "JACKPOT!", color: Color(hex: 0xFFFFD700)) { $0.addGold(500) },
        WheelSector(label: "SANDIK", subtitle: "Gizemli ödül", color: Color(hex: 0xFFE040FB)) { save in
            _ = save.openCrate(tier: CrateItem.allCrates[0], spendCost: false)
        },
        WheelSector(label: "PARÇA", subtitle: "+1 parça", color: Color(hex: 0xFF00E5FF)) { save in
            let cats = ["balls", "paddles", "trails", "bricks"]
            save.addShard(cats.randomElement() ?? "balls")
        },
        WheelSector(label: "250", subtitle: "Büyük ödül", color: Color(hex: 0xFFFF9100)) { $0.addGold(250) },
        WheelSector(label: "150", subtitle: "Altın", color: Color(hex: 0xFFFFD54F)) { $0.addGold(150) },
        WheelSector(label: "+1 CAN", subtitle: "Can boostu", color: Color(hex: 0xFFFF1744)) { $0.grantBoost("life") },
        WheelSector(label: "100", subtitle: "Altın", color: Color(hex: 0xFF26A69A)) { $0.addGold(100) },
        WheelSector(label: "75", subtitle: "Altın", color: Color(hex: 0xFFAB47BC)) { $0.addGold(75) }
    ]
}
