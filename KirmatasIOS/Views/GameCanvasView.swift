import SwiftUI

struct GameCanvasView: View {
    @ObservedObject var controller: GameController
    @State private var lastTickDate: Date?
    @State private var lastDragX: CGFloat?

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let _ = controller.frameTick
                    let shake = controller.particles.getShakeOffset()
                    var ctx = context
                    ctx.translateBy(x: shake.x, y: shake.y)

                    drawBackground(context: &ctx, size: size, time: controller.gameTime)
                    drawPlayfieldBorder(context: &ctx, size: size)
                    drawBricks(context: &ctx, time: controller.gameTime)
                    drawBlackHoles(context: &ctx, time: controller.gameTime)
                    drawPortals(context: &ctx, time: controller.gameTime)
                    drawNet(context: &ctx, size: size)
                    if controller.currentMode == .chaos {
                        drawChaosAim(context: &ctx)
                    } else {
                        drawPaddle(context: &ctx)
                    }
                    drawCapsules(context: &ctx)
                    drawProjectiles(context: &ctx)
                    drawBalls(context: &ctx)
                    drawDrone(context: &ctx)
                    drawVortex(context: &ctx, time: controller.gameTime)

                    if let bee = controller.activeBee, bee.isAlive {
                        drawBee(context: &ctx, bee: bee)
                    }

                    drawParticles(context: &ctx)

                    drawBossWarningBanner(context: &ctx, size: size, time: controller.gameTime)
                    drawLevelClearCelebration(context: &ctx, size: size, time: controller.gameTime)

                    if let splat = controller.activeSplat, !splat.isDead {
                        drawWindshieldSplat(context: &ctx, splat: splat, size: size)
                    }
                }
                .onChange(of: timeline.date) { newDate in
                    if let last = lastTickDate {
                        let dt = min(max(newDate.timeIntervalSince(last), 0.001), 0.05)
                        controller.update(dt: dt)
                    }
                    lastTickDate = newDate
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if controller.currentMode == .chaos {
                            controller.aimChaos(x: value.location.x, y: value.location.y)
                            return
                        }
                        if lastDragX == nil {
                            if controller.status == .ready || controller.hasStuckBall {
                                controller.launchBall()
                            }
                        }
                        controller.movePaddleTo(targetX: value.location.x)
                        lastDragX = value.location.x
                    }
                    .onEnded { _ in
                        if controller.currentMode == .chaos {
                            controller.fireChaos()
                        }
                        lastDragX = nil
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        if controller.currentMode == .chaos {
                            controller.toggleChaosTurboOrRecall()
                        } else {
                            controller.triggerUlti()
                        }
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        controller.handleCanvasTap(at: value.location)
                    }
            )
            .onAppear {
                controller.setDimensions(width: geo.size.width, height: geo.size.height)
                lastTickDate = Date()
            }
            .onChange(of: geo.size) { newSize in
                controller.setDimensions(width: newSize.width, height: newSize.height)
            }
        }
    }

    // MARK: - Background
    private func drawBackground(context: inout GraphicsContext, size: CGSize, time: Double) {
        // We removed the full-screen RadialGradient fill here because it causes massive GPU fill-rate lag.
        // It is now strictly handled by GameContainerView's static background behind this Canvas!

        let safeW = max(Int(size.width), 1)
        let safeH = max(size.height, 1.0)
        for i in 0..<36 {
            let speed = 10.0 + Double(i % 4) * 4.0
            let x = Double((i * 97 + 23) % safeW)
            let y = (Double(i * 139) + time * speed).truncatingRemainder(dividingBy: safeH)
            let twinkle = 0.15 * sin(time * 2.5 + Double(i))
            let alpha = min(max(0.25 + Double(i % 4) * 0.15 + twinkle, 0.1), 0.85)
            let r: Double = (i % 5 == 0) ? 1.8 : 1.0
            let starColor = (i % 3 == 0) ? Color(hex: 0xFF80D8FF) : Color.white
            context.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(starColor.opacity(alpha))
            )
        }
    }

    private func drawPlayfieldBorder(context: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let ceilingY: CGFloat = 56
        let equippedId = SaveManager.shared.equippedPaddleSkin
        let glow = (PaddleSkinItem.allSkins.first { $0.id == equippedId } ?? PaddleSkinItem.allSkins[0]).glowColor

        context.fill(
            Path(CGRect(x: 0, y: 0, width: 10, height: h)),
            with: .linearGradient(
                Gradient(colors: [Color.black.opacity(0.6), .clear]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 10, y: 0)
            )
        )
        context.fill(
            Path(CGRect(x: w - 10, y: 0, width: 10, height: h)),
            with: .linearGradient(
                Gradient(colors: [.clear, Color.black.opacity(0.6)]),
                startPoint: CGPoint(x: w - 10, y: 0),
                endPoint: CGPoint(x: w, y: 0)
            )
        )
        context.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: ceilingY + 12)),
            with: .linearGradient(
                Gradient(colors: [Color.black.opacity(0.73), .clear]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: ceilingY + 12)
            )
        )

        var frame = Path()
        frame.move(to: CGPoint(x: 0, y: ceilingY))
        frame.addLine(to: CGPoint(x: w, y: ceilingY))
        frame.move(to: CGPoint(x: 0.5, y: ceilingY))
        frame.addLine(to: CGPoint(x: 0.5, y: h))
        frame.move(to: CGPoint(x: w - 0.5, y: ceilingY))
        frame.addLine(to: CGPoint(x: w - 0.5, y: h))
        context.stroke(frame, with: .color(glow.opacity(0.22)), lineWidth: 2)

        var brackets = Path()
        brackets.move(to: CGPoint(x: 0, y: ceilingY))
        brackets.addLine(to: CGPoint(x: 16, y: ceilingY))
        brackets.move(to: CGPoint(x: 0, y: ceilingY))
        brackets.addLine(to: CGPoint(x: 0, y: ceilingY + 16))
        brackets.move(to: CGPoint(x: w - 16, y: ceilingY))
        brackets.addLine(to: CGPoint(x: w, y: ceilingY))
        brackets.move(to: CGPoint(x: w, y: ceilingY))
        brackets.addLine(to: CGPoint(x: w, y: ceilingY + 16))
        context.stroke(brackets, with: .color(.white.opacity(0.7)), lineWidth: 1.5)
        context.fill(Path(ellipseIn: CGRect(x: 1.2, y: ceilingY + 1.2, width: 3.6, height: 3.6)), with: .color(glow.opacity(0.9)))
        context.fill(Path(ellipseIn: CGRect(x: w - 4.8, y: ceilingY + 1.2, width: 3.6, height: 3.6)), with: .color(glow.opacity(0.9)))
    }

    private func drawBlackHoles(context: inout GraphicsContext, time: Double) {
        for hole in controller.blackHoles {
            var ctx = context
            ctx.translateBy(x: hole.x, y: hole.y)
            let field = hole.isVortexTrap
                ? Color(hex: 0xFFFF1744)
                : (hole.isSupercharged ? Color(hex: 0xFF00E5FF) : Color(hex: 0xFFB388FF))
            let maxDist = hole.maxInfluenceDist
            ctx.stroke(
                Path(ellipseIn: CGRect(x: -maxDist, y: -maxDist, width: maxDist * 2, height: maxDist * 2)),
                with: .color(field.opacity(0.22 + 0.08 * sin(time * 4))),
                lineWidth: 1.2
            )
            for wave in 0..<3 {
                let phase = (time * 0.85 + Double(wave) / 3.0).truncatingRemainder(dividingBy: 1.0)
                let waveR = maxDist * (1.0 - phase * 0.72)
                let alpha = min(max(sin(phase * .pi) * 0.28, 0), 0.35)
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: -waveR, y: -waveR, width: waveR * 2, height: waveR * 2)),
                    with: .color(field.opacity(alpha)),
                    lineWidth: 1.4
                )
            }

            ctx.rotate(by: .radians(hole.rotation))
            let halo = hole.radius * (hole.isVortexTrap ? 3.4 : (hole.isSupercharged ? 3.2 : 2.8))
            let colors: [Color]
            if hole.isVortexTrap {
                colors = [Color.black, Color(hex: 0xFF1A0000), Color(hex: 0xFFB71C1C), Color(hex: 0xFFFF1744), Color(hex: 0xFFFF80AB), .clear]
            } else if hole.isSupercharged {
                colors = [Color.black, Color(hex: 0xFF120700), Color(hex: 0xFFFF6D00), Color(hex: 0xFFFFAB00), Color(hex: 0xFF00E5FF), .clear]
            } else {
                colors = [Color.black, Color(hex: 0xFF0D0318), Color(hex: 0xFF4A148C), Color(hex: 0xFF7C4DFF), Color(hex: 0xFFE040FB), .clear]
            }
            ctx.fill(
                Path(ellipseIn: CGRect(x: -halo, y: -halo, width: halo * 2, height: halo * 2)),
                with: .radialGradient(
                    Gradient(colors: colors),
                    center: .zero,
                    startRadius: hole.radius * 0.4,
                    endRadius: halo
                )
            )

            let armCount = hole.isVortexTrap ? 8 : (hole.isSupercharged ? 7 : 5)
            let sweep = .pi * (hole.isVortexTrap ? 1.6 : (hole.isSupercharged ? 1.5 : 1.35))
            for i in 0..<armCount {
                let start = (2 * .pi / Double(armCount)) * Double(i) + sin(time * 3 + Double(i)) * 0.15
                let radius = hole.radius * (0.55 + 0.35 * Double(i % 5))
                var arc = Path()
                arc.addArc(
                    center: .zero,
                    radius: radius,
                    startAngle: .radians(start),
                    endAngle: .radians(start + sweep),
                    clockwise: false
                )
                let arm: Color
                if hole.isVortexTrap {
                    arm = i % 2 == 0 ? Color(hex: 0xFFFF1744) : Color(hex: 0xFFFF80AB)
                } else if hole.isSupercharged {
                    arm = i % 2 == 0 ? Color(hex: 0xFFFFD54F) : Color(hex: 0xFF00E5FF)
                } else {
                    arm = i % 2 == 0 ? Color(hex: 0xFFE040FB) : Color(hex: 0xFF7C4DFF)
                }
                ctx.stroke(arc, with: .color(arm.opacity(max(0.2, 0.70 - Double(i) * 0.05))), lineWidth: max(0.8, 2.4 - Double(i) * 0.15))
            }

            let core = hole.radius * 0.48
            let rim = hole.isSupercharged ? Color(hex: 0xFF00E5FF) : Color(hex: 0xFFB388FF)
            ctx.stroke(
                Path(ellipseIn: CGRect(x: -core, y: -core, width: core * 2, height: core * 2)),
                with: .color(rim.opacity(0.55)),
                lineWidth: 3.2
            )
            ctx.stroke(
                Path(ellipseIn: CGRect(x: -core, y: -core, width: core * 2, height: core * 2)),
                with: .color(.white.opacity(0.95)),
                lineWidth: 1.3
            )
            let voidR = hole.radius * 0.45
            ctx.fill(
                Path(ellipseIn: CGRect(x: -voidR, y: -voidR, width: voidR * 2, height: voidR * 2)),
                with: .color(.black)
            )
        }
    }

    private func drawPortals(context: inout GraphicsContext, time: Double) {
        guard controller.portals.count >= 2 else { return }
        let first = controller.portals[0]
        let second = controller.portals[1]
        let pulse = 0.18 + 0.12 * sin(time * 3.5)
        var beam = Path()
        let dx = second.x - first.x
        let dy = second.y - first.y
        let distance = sqrt(dx * dx + dy * dy)
        if distance > 0 {
            let dirX = dx / distance
            let dirY = dy / distance
            var cursor = 0.0
            while cursor < distance {
                let length = min(6.0, distance - cursor)
                beam.move(to: CGPoint(x: first.x + dirX * cursor, y: first.y + dirY * cursor))
                beam.addLine(to: CGPoint(x: first.x + dirX * (cursor + length), y: first.y + dirY * (cursor + length)))
                cursor += 14
            }
            context.stroke(beam, with: .color(.white.opacity(pulse)), lineWidth: 2)
        }

        for portal in controller.portals {
            var ctx = context
            ctx.translateBy(x: portal.x, y: portal.y)
            let scale = 1.0 + 0.08 * sin(time * 4 + (portal.isBlue ? 0 : .pi))
            let radius = portal.radius * scale
            ctx.fill(Path(ellipseIn: CGRect(x: -radius * 1.55, y: -radius * 1.55, width: radius * 3.1, height: radius * 3.1)), with: .color(portal.color.opacity(0.16)))
            ctx.fill(Path(ellipseIn: CGRect(x: -radius * 1.25, y: -radius * 1.25, width: radius * 2.5, height: radius * 2.5)), with: .color(portal.color.opacity(0.28)))
            ctx.rotate(by: .radians(portal.rotation))
            ctx.stroke(
                Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
                with: .color(portal.color.opacity(0.95)),
                lineWidth: 2.4
            )
            ctx.rotate(by: .radians(-portal.rotation * 2))
            let inner = radius * 0.62
            ctx.stroke(
                Path(ellipseIn: CGRect(x: -inner, y: -inner, width: inner * 2, height: inner * 2)),
                with: .color(.white.opacity(0.8)),
                lineWidth: 1.4
            )
            let core = radius * 0.34
            ctx.fill(Path(ellipseIn: CGRect(x: -core, y: -core, width: core * 2, height: core * 2)), with: .color(portal.color.opacity(0.85)))
        }
    }

    // MARK: - Bricks & Mecha Boss
    private func drawBricks(context: inout GraphicsContext, time: Double) {
        for b in controller.bricks where b.isAlive {
            var bCtx = context
            let cx = b.x + b.width / 2.0
            let cy = b.y + b.height / 2.0
            bCtx.translateBy(x: cx, y: cy)

            if b.isBallPickup {
                let orb = min(b.width, b.height) * 0.42
                bCtx.fill(
                    Path(ellipseIn: CGRect(x: -orb, y: -orb, width: orb * 2, height: orb * 2)),
                    with: .color(Color(hex: 0xFF00E5FF))
                )
                bCtx.fill(
                    Path(ellipseIn: CGRect(x: -orb * 0.35, y: -orb * 0.35, width: orb * 0.7, height: orb * 0.7)),
                    with: .color(.white)
                )
                continue
            }

            if b.jelly > 0 {
                let scale = 1.0 + sin(b.jelly * .pi * 3.0) * 0.15
                bCtx.scaleBy(x: scale, y: 1.0 / scale)
            }

            let halfW = b.width / 2.0
            let halfH = b.height / 2.0
            let rect = CGRect(x: -halfW, y: -halfH, width: b.width, height: b.height)
            let rrect = Path(roundedRect: rect, cornerRadius: 6.0)

            if b.isSteel {
                bCtx.fill(rrect, with: .color(Color(hex: 0xFF37474F)))

                var topLine = Path()
                topLine.move(to: CGPoint(x: -halfW + 2, y: -halfH + 1))
                topLine.addLine(to: CGPoint(x: halfW - 2, y: -halfH + 1))
                bCtx.stroke(topLine, with: .color(Color(hex: 0xFF78909C)), lineWidth: 2.0)

                var botLine = Path()
                botLine.move(to: CGPoint(x: -halfW + 2, y: halfH - 1))
                botLine.addLine(to: CGPoint(x: halfW - 2, y: halfH - 1))
                bCtx.stroke(botLine, with: .color(Color(hex: 0xFF1C2833)), lineWidth: 2.0)

                var stripes = Path()
                var sx = -halfW + 4
                while sx < halfW - 6 {
                    stripes.move(to: CGPoint(x: sx, y: halfH - 3))
                    stripes.addLine(to: CGPoint(x: sx + 8, y: -halfH + 3))
                    sx += 12
                }
                bCtx.stroke(stripes, with: .color(Color(hex: 0xFFCFD8DC).opacity(0.22)), lineWidth: 2.5)

                let rivets = [
                    CGPoint(x: -halfW + 4, y: -halfH + 4),
                    CGPoint(x: halfW - 4, y: -halfH + 4),
                    CGPoint(x: -halfW + 4, y: halfH - 4),
                    CGPoint(x: halfW - 4, y: halfH - 4)
                ]
                for pt in rivets {
                    bCtx.fill(
                        Path(ellipseIn: CGRect(x: pt.x - 1.5, y: pt.y - 1.5, width: 3, height: 3)),
                        with: .color(.white.opacity(0.7))
                    )
                }

            } else if b.isBoss {
                drawBoss(context: &bCtx, brick: b, time: time, halfW: halfW, halfH: halfH)
            } else {
                // High-Quality Glassy Neon Gem
                
                bCtx.fill(rrect, with: .linearGradient(b.gradient, startPoint: CGPoint(x: 0, y: -halfH), endPoint: CGPoint(x: 0, y: halfH)))
                
                // Outer neon glow
                bCtx.stroke(rrect, with: .color(b.color.opacity(0.4)), lineWidth: 3.5)

                // Glossy top reflection (glass effect)
                let glossRect = CGRect(x: -halfW + 1.5, y: -halfH + 1.5, width: max(0, b.width - 3.0), height: b.height * 0.45)
                var glossPath = Path(roundedRect: glossRect, cornerRadius: 4.0)
                bCtx.fill(glossPath, with: .color(.white.opacity(0.4)))
                
                // Sharp inner white highlight edge
                var hiPath = Path()
                hiPath.move(to: CGPoint(x: -halfW + 3, y: -halfH + 1.5))
                hiPath.addLine(to: CGPoint(x: halfW - 3, y: -halfH + 1.5))
                hiPath.move(to: CGPoint(x: -halfW + 1.5, y: -halfH + 3))
                hiPath.addLine(to: CGPoint(x: -halfW + 1.5, y: halfH - 3))
                bCtx.stroke(hiPath, with: .color(.white.opacity(0.55)), lineWidth: 1.5)

                // Deep inner shadow edge
                var shPath = Path()
                shPath.move(to: CGPoint(x: -halfW + 3, y: halfH - 1.5))
                shPath.addLine(to: CGPoint(x: halfW - 3, y: halfH - 1.5))
                shPath.move(to: CGPoint(x: halfW - 1.5, y: -halfH + 3))
                shPath.addLine(to: CGPoint(x: halfW - 1.5, y: halfH - 3))
                bCtx.stroke(shPath, with: .color(.black.opacity(0.6)), lineWidth: 1.5)

                if b.maxHp >= 2 {
                    // Health Pips
                    let pipSpacing = 10.0
                    let totalPipsW = Double(b.maxHp - 1) * pipSpacing
                    let startPipX = -totalPipsW / 2.0

                    for p in 0..<b.maxHp {
                        let pipX = startPipX + Double(p) * pipSpacing
                        let isFull = p < b.hp
                        let r: Double = isFull ? 2.5 : 2.0
                        bCtx.fill(
                            Path(ellipseIn: CGRect(x: pipX - r, y: -r, width: r * 2, height: r * 2)),
                            with: .color(isFull ? .white : .black.opacity(0.45))
                        )
                        if isFull {
                            bCtx.fill(
                                Path(ellipseIn: CGRect(x: pipX - 1.2, y: -1.2, width: 2.4, height: 2.4)),
                                with: .color(Color(hex: 0xFFFFD54F))
                            )
                        }
                    }

                    // Damage crack lines
                    if b.hp < b.maxHp {
                        var crack = Path()
                        crack.move(to: CGPoint(x: -halfW * 0.45, y: -halfH * 0.6))
                        crack.addLine(to: CGPoint(x: -halfW * 0.15, y: -halfH * 0.1))
                        crack.addLine(to: CGPoint(x: -halfW * 0.35, y: halfH * 0.2))
                        crack.addLine(to: CGPoint(x: -halfW * 0.1, y: halfH * 0.65))
                        crack.move(to: CGPoint(x: -halfW * 0.15, y: -halfH * 0.1))
                        crack.addLine(to: CGPoint(x: halfW * 0.25, y: -halfH * 0.3))
                        crack.addLine(to: CGPoint(x: halfW * 0.45, y: -halfH * 0.65))
                        bCtx.stroke(crack, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                    }
                }
            }
        }
    }

    private func drawBoss(context: inout GraphicsContext, brick b: Brick, time: Double, halfW: Double, halfH: Double) {
        let hpPct = min(max(Double(b.hp) / Double(max(b.maxHp, 1)), 0.0), 1.0)

        // 1. Dual Thruster Exhaust
        let thrustPulse = 3.5 + sin(time * 12.0) * 2.0
        let leftThrust = CGRect(x: -halfW * 0.65 - 7, y: -halfH - 2 - thrustPulse / 2, width: 14, height: thrustPulse)
        let rightThrust = CGRect(x: halfW * 0.65 - 7, y: -halfH - 2 - thrustPulse / 2, width: 14, height: thrustPulse)
        context.fill(Path(ellipseIn: leftThrust), with: .color(Color(hex: 0xFFFF5722).opacity(0.85)))
        context.fill(Path(ellipseIn: rightThrust), with: .color(Color(hex: 0xFFFF5722).opacity(0.85)))

        // 2. Heavy Armored Hull
        let hullRect = CGRect(x: -halfW, y: -halfH, width: b.width, height: b.height)
        let hullPath = Path(roundedRect: hullRect, cornerRadius: 8.0)
        context.fill(hullPath, with: .color(Color(hex: 0xFF141724)))

        // 3. Wing Armor Plates
        let wingW = halfW * 0.35
        let leftWing = Path(roundedRect: CGRect(x: -halfW, y: -halfH, width: wingW, height: b.height), cornerRadius: 6.0)
        let rightWing = Path(roundedRect: CGRect(x: halfW - wingW, y: -halfH, width: wingW, height: b.height), cornerRadius: 6.0)
        context.fill(leftWing, with: .color(Color(hex: 0xFF1F2538)))
        context.fill(rightWing, with: .color(Color(hex: 0xFF1F2538)))

        // 4. Dual Plasma Cannons
        let leftCannon = Path(roundedRect: CGRect(x: -halfW * 0.5 - 5, y: halfH - 2, width: 10, height: 12), cornerRadius: 2.0)
        let rightCannon = Path(roundedRect: CGRect(x: halfW * 0.5 - 5, y: halfH - 2, width: 10, height: 12), cornerRadius: 2.0)
        context.fill(leftCannon, with: .color(Color(hex: 0xFF37474F)))
        context.fill(rightCannon, with: .color(Color(hex: 0xFF37474F)))

        let isTelegraphing = b.shootTimer <= 0.6
        let muzzleColor = isTelegraphing
            ? (sin(time * 24.0) > 0 ? Color(hex: 0xFFFFEB3B) : Color(hex: 0xFFFF1744))
            : Color(hex: 0xFFFF1744)
        let muzzle = isTelegraphing ? 5.0 : 3.0
        let cannonAlpha = isTelegraphing ? 1.0 : (0.75 + sin(time * 8.0) * 0.25)
        context.fill(Path(ellipseIn: CGRect(x: -halfW * 0.5 - muzzle, y: halfH + 9 - muzzle, width: muzzle * 2, height: muzzle * 2)), with: .color(muzzleColor.opacity(cannonAlpha)))
        context.fill(Path(ellipseIn: CGRect(x: halfW * 0.5 - muzzle, y: halfH + 9 - muzzle, width: muzzle * 2, height: muzzle * 2)), with: .color(muzzleColor.opacity(cannonAlpha)))
        if isTelegraphing {
            context.fill(Path(ellipseIn: CGRect(x: -halfW * 0.5 - 2.2, y: halfH + 6.8, width: 4.4, height: 4.4)), with: .color(.white.opacity(0.85)))
            context.fill(Path(ellipseIn: CGRect(x: halfW * 0.5 - 2.2, y: halfH + 6.8, width: 4.4, height: 4.4)), with: .color(.white.opacity(0.85)))
        }

        // 5. Central Reactor Chassis & Scanning Visor
        let centerW = halfW * 0.65
        let centerPath = Path(roundedRect: CGRect(x: -centerW, y: -halfH + 2, width: centerW * 2, height: b.height - 4), cornerRadius: 5.0)
        context.fill(centerPath, with: .color(Color(hex: 0xFF262D42)))

        let eyeW = centerW * 0.7
        let eyePath = Path(roundedRect: CGRect(x: -eyeW, y: -5.5, width: eyeW * 2, height: 13.0), cornerRadius: 3.0)
        context.fill(eyePath, with: .color(Color(hex: 0xFF0A0D14)))

        let scanX = sin(time * 5.0) * (eyeW - 6.0)
        context.fill(Path(ellipseIn: CGRect(x: scanX - 4.5, y: 1 - 4.5, width: 9, height: 9)), with: .color(Color(hex: 0xFFFF1744)))
        context.fill(Path(ellipseIn: CGRect(x: scanX - 2.0, y: 1 - 2.0, width: 4, height: 4)), with: .color(.white))

        // 6. Pulsing Forcefield & Floating Boss HP Bar
        let shieldPulse = sin(time * 4.0) * 0.2 + 0.8
        context.stroke(hullPath, with: .color(Color(hex: 0xFFFF1744).opacity(0.38 * shieldPulse)), lineWidth: 2.0)

        let barW = b.width
        let barH = 5.5
        let barY = -halfH - 12.0
        let barBg = Path(roundedRect: CGRect(x: -halfW, y: barY, width: barW, height: barH), cornerRadius: 2.5)
        context.fill(barBg, with: .color(Color.black.opacity(0.85)))

        let hpColor = hpPct > 0.5
            ? Color.lerp(Color(hex: 0xFFFFEB3B), Color(hex: 0xFF00E676), (hpPct - 0.5) * 2.0)
            : Color.lerp(Color(hex: 0xFFFF1744), Color(hex: 0xFFFFEB3B), hpPct * 2.0)
        let barFill = Path(roundedRect: CGRect(x: -halfW, y: barY, width: barW * hpPct, height: barH), cornerRadius: 2.5)
        context.fill(barFill, with: .color(hpColor))
    }

    private func drawChaosAim(context: inout GraphicsContext) {
        let home = CGPoint(x: controller.chaosHomeX, y: controller.chaosFloorY)
        context.fill(
            Path(ellipseIn: CGRect(x: home.x - 10, y: home.y - 10, width: 20, height: 20)),
            with: .color(Color(hex: 0xFF00E5FF))
        )
        guard controller.status == .ready, controller.chaosAiming else { return }
        var line = Path()
        line.move(to: home)
        line.addLine(to: CGPoint(x: controller.chaosAimX, y: controller.chaosAimY))
        context.stroke(line, with: .color(Color(hex: 0xFFFFD54F).opacity(0.9)), lineWidth: 2)
        context.fill(
            Path(ellipseIn: CGRect(x: controller.chaosAimX - 5, y: controller.chaosAimY - 5, width: 10, height: 10)),
            with: .color(Color(hex: 0xFFFFD54F))
        )
    }

    // MARK: - Safety Net
    private func drawNet(context: inout GraphicsContext, size: CGSize) {
        guard controller.paddle.hasNet else { return }
        let y = size.height - 28.0
        var line = Path()
        line.move(to: CGPoint(x: 0, y: y))
        line.addLine(to: CGPoint(x: size.width, y: y))
        context.stroke(line, with: .color(Color(hex: 0xFF8BC34A).opacity(0.25)), lineWidth: 6.0)
        context.stroke(line, with: .color(Color(hex: 0xFF8BC34A).opacity(0.8)), lineWidth: 2.5)
    }

    // MARK: - Paddle
    private func drawPaddle(context: inout GraphicsContext) {
        let p = controller.paddle
        let rect = p.rect
        let rrect = Path(roundedRect: rect, cornerRadius: rect.height / 2.0)
        let alphaMul = p.isGhost ? 0.35 : 1.0

        let equippedPaddleId = SaveManager.shared.equippedPaddleSkin
        let paddleDef = PaddleSkinItem.allSkins.first(where: { $0.id == equippedPaddleId }) ?? PaddleSkinItem.allSkins[0]

        let glowRect = rect.insetBy(dx: -2.0, dy: -2.0)
        let glowPath = Path(roundedRect: glowRect, cornerRadius: glowRect.height / 2.0)
        context.stroke(glowPath, with: .color(paddleDef.glowColor.opacity(0.4 * alphaMul)), lineWidth: 3.5)

        context.fill(
            rrect,
            with: .linearGradient(
                Gradient(colors: [paddleDef.color1.opacity(alphaMul), paddleDef.color2.opacity(alphaMul)]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            )
        )

        // Inner neon band
        let innerRect = rect.insetBy(dx: 3.0, dy: 3.0)
        context.stroke(Path(roundedRect: innerRect, cornerRadius: innerRect.height / 2.0), with: .color(paddleDef.glowColor.opacity(0.6 * alphaMul)), lineWidth: 1.5)

        // Glassy gloss reflection
        let glossRect = CGRect(x: rect.minX + 4, y: rect.minY + 1.5, width: max(rect.width - 8, 2), height: rect.height * 0.4)
        context.fill(Path(roundedRect: glossRect, cornerRadius: glossRect.height / 2.0), with: .color(.white.opacity(0.45 * alphaMul)))

        if p.hasLaser {
            let cx1 = rect.minX + 8
            let cx2 = rect.maxX - 8
            let r = 3.5
            context.fill(Path(ellipseIn: CGRect(x: cx1 - r, y: rect.minY - r, width: r*2, height: r*2)), with: .color(Color(hex: 0xFFFFD740)))
            context.fill(Path(ellipseIn: CGRect(x: cx2 - r, y: rect.minY - r, width: r*2, height: r*2)), with: .color(Color(hex: 0xFFFFD740)))
        }
    }

    // MARK: - Balls
    private func drawBalls(context: inout GraphicsContext) {
        let equippedBallId = SaveManager.shared.equippedBallSkin
        let ballSkin = BallSkinItem.allSkins.first(where: { $0.id == equippedBallId }) ?? BallSkinItem.allSkins[0]
        let gameTime = controller.gameTime

        for ball in controller.balls {
            // Trail
            let count = ball.trail.count
            if count > 0 {
                for i in 0..<count {
                    let pt = ball.trail[i]
                    let progress = 1.0 - (Double(i) / Double(count))
                    let isBlueFlame = ball.isFireball && ball.fireballCombo >= 8
                    let baseRadius = isBlueFlame ? ball.radius * 1.2 : ball.radius
                    let trailRadius = baseRadius * progress * 0.85
                    
                    let trailColor: Color
                    if isBlueFlame {
                        trailColor = Color(hex: 0xFF00E5FF)
                    } else if ball.isFireball {
                        trailColor = Color(hex: 0xFFFF6D00)
                    } else if ballSkin.isRainbow {
                        trailColor = ballSkin.currentGlowColor(time: gameTime - Double(i) * 0.05)
                    } else {
                        trailColor = ballSkin.glowColor
                    }
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: pt.position.x - trailRadius, y: pt.position.y - trailRadius, width: trailRadius * 2, height: trailRadius * 2)),
                        with: .color(trailColor.opacity(progress * (isBlueFlame ? 0.65 : 0.45)))
                    )
                }
            }

            var bCtx = context
            bCtx.translateBy(x: ball.x, y: ball.y)

            if ball.squashTimer > 0 {
                bCtx.rotate(by: .radians(ball.squashAngle))
                let factor = 1.0 + (ball.squashTimer / 0.22) * 0.4
                bCtx.scaleBy(x: factor, y: 1.0 / factor)
                bCtx.rotate(by: .radians(-ball.squashAngle))
            }

            if ball.cornerBoostTimer > 0 {
                let r = ball.radius + 6.0
                bCtx.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xFFFFD54F).opacity(0.45)))
            }

            let isBlueFlame = ball.isFireball && ball.fireballCombo >= 8
            let glowR = ball.radius + (isBlueFlame ? 5.0 : 3.0)
            
            let glowColor: Color
            if isBlueFlame {
                glowColor = Color(hex: 0xFF00B0FF)
            } else if ball.isFireball {
                glowColor = Color(hex: 0xFFFF6D00)
            } else if ballSkin.isRainbow {
                glowColor = ballSkin.currentGlowColor(time: gameTime)
            } else {
                glowColor = ballSkin.glowColor
            }
            
            bCtx.fill(Path(ellipseIn: CGRect(x: -glowR, y: -glowR, width: glowR * 2, height: glowR * 2)), with: .color(glowColor.opacity(isBlueFlame ? 0.4 : 0.28)))

            let coreColor: Color
            if isBlueFlame {
                coreColor = .white
            } else if ball.isFireball {
                coreColor = Color(hex: 0xFFFFD54F)
            } else if ball.isBomb {
                coreColor = Color(hex: 0xFFFF5252)
            } else if ballSkin.isRainbow {
                coreColor = ballSkin.currentMainColor(time: gameTime)
            } else {
                coreColor = ballSkin.mainColor
            }
            
            let r = ball.radius
            bCtx.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(coreColor))

            let specR = r * 0.35
            bCtx.fill(
                Path(ellipseIn: CGRect(x: -r * 0.35 - specR, y: -r * 0.35 - specR, width: specR * 2, height: specR * 2)),
                with: .color(.white.opacity(0.85))
            )
        }
    }

    // MARK: - Drone
    private func drawDrone(context: inout GraphicsContext) {
        guard controller.paddle.hasDrone else { return }
        let p = controller.paddle
        let dx = p.x + p.width / 2.0 + cos(p.droneAngle) * 44.0
        let dy = p.y - 20.0 + sin(p.droneAngle) * 16.0

        context.fill(Path(ellipseIn: CGRect(x: dx - 6, y: dy - 6, width: 12, height: 12)), with: .color(Color(hex: 0xFF00E676)))
        context.fill(Path(ellipseIn: CGRect(x: dx - 2.5, y: dy - 2.5, width: 5, height: 5)), with: .color(.white))
    }

    // MARK: - Capsules
    // MARK: - Vortex (Blackhole)
    private func drawVortex(context: inout GraphicsContext, time: Double) {
        guard controller.activePowerUps.contains(where: { $0.type == .vortex }) else { return }
        let p = controller.paddle
        let cx = p.x + p.width / 2.0
        let cy = p.y - 40.0 // Appears slightly above the paddle
        var vCtx = context
        vCtx.translateBy(x: cx, y: cy)
        vCtx.rotate(by: .radians(time * -4.0)) // spinning fast
        let r = 25.0 + sin(time * 5.0) * 3.0
        // Dark outer rim
        vCtx.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xFF10002B).opacity(0.8)))
        // Swirl lines
        for i in 0..<4 {
            var swirl = Path()
            swirl.move(to: .zero)
            swirl.addQuadCurve(to: CGPoint(x: cos(Double(i) * .pi/2) * r, y: sin(Double(i) * .pi/2) * r),
                               control: CGPoint(x: cos(Double(i) * .pi/2 + 0.5) * r * 0.5, y: sin(Double(i) * .pi/2 + 0.5) * r * 0.5))
            vCtx.stroke(swirl, with: .color(Color(hex: 0xFFE040FB).opacity(0.6)), lineWidth: 2.0)
        }
        // Core
        vCtx.fill(Path(ellipseIn: CGRect(x: -6, y: -6, width: 12, height: 12)), with: .color(.black))
        vCtx.stroke(Path(ellipseIn: CGRect(x: -6, y: -6, width: 12, height: 12)), with: .color(Color(hex: 0xFFE040FB)), lineWidth: 1.5)
    }

    private func drawCapsules(context: inout GraphicsContext) {
        for cap in controller.capsules {
            let bob = sin(cap.animTimer * 6.0) * 2.5
            let cx = cap.x
            let cy = cap.y + bob

            if cap.type == .life {
                let pulse = 1.0 + sin(cap.animTimer * 7.0) * 0.12
                drawPixelHeart(context: &context, center: CGPoint(x: cx, y: cy), size: 30.0 * pulse)
                continue
            }

            let dst = CGRect(x: cx - 17.0, y: cy - 17.0, width: 34.0, height: 34.0)

            let resolved = context.resolve(Image(cap.type.assetName))
            if resolved.size.width > 0 {
                context.draw(resolved, in: dst)
            } else {
                let bgPath = Path(roundedRect: dst, cornerRadius: 8.0)
                context.fill(bgPath, with: .color(Color(hex: 0xDD0C0F1A)))
                context.stroke(bgPath, with: .color(cap.type.color), lineWidth: 2.0)
                let sym = context.resolve(Image(systemName: cap.type.sfSymbol))
                context.draw(sym, in: dst.insetBy(dx: 7, dy: 7))
            }
        }
    }

    private func drawPixelHeart(context: inout GraphicsContext, center: CGPoint, size: Double) {
        let pixelSize = size / 8.0
        let left = center.x - size / 2.0
        let top = center.y - size / 2.0

        let matrix: [[Int]] = [
            [0, 1, 1, 0, 0, 1, 1, 0],
            [1, 2, 1, 1, 1, 1, 1, 1],
            [1, 1, 1, 1, 1, 1, 1, 1],
            [1, 1, 1, 1, 1, 1, 1, 1],
            [0, 1, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
            [0, 0, 0, 1, 1, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0]
        ]

        let glowRect = CGRect(x: center.x - size * 0.6, y: center.y - size * 0.6, width: size * 1.2, height: size * 1.2)
        context.fill(Path(ellipseIn: glowRect), with: .color(Color(hex: 0xFFFF1744).opacity(0.25)))

        for r in 0..<8 {
            for c in 0..<8 {
                let val = matrix[r][c]
                guard val > 0 else { continue }
                let px = left + Double(c) * pixelSize
                let py = top + Double(r) * pixelSize
                let pRect = CGRect(x: px, y: py, width: pixelSize, height: pixelSize)

                let color: Color = (val == 2) ? Color(hex: 0xFFFF8A80) : Color(hex: 0xFFFF1744)
                context.fill(Path(pRect), with: .color(color))
            }
        }
    }

    // MARK: - Projectiles
    private func drawProjectiles(context: inout GraphicsContext) {
        for p in controller.projectiles {
            if p.isBossBullet {
                let r = p.radius
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xFFFF1744)))
            } else if p.isRocket {
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 7, width: 6, height: 14)), with: .color(Color(hex: 0xFFFF5722)))
            } else {
                var laserLine = Path()
                laserLine.move(to: CGPoint(x: p.x, y: p.y))
                laserLine.addLine(to: CGPoint(x: p.x, y: p.y - 14.0))
                context.stroke(laserLine, with: .color(Color(hex: 0xFFFFD740)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }
        }
    }

    // MARK: - Particles, Shockwaves & Floating Texts
    private func drawParticles(context: inout GraphicsContext) {
        for p in controller.particles.particles {
            let progress = min(max(p.life / p.maxLife, 0.0), 1.0)
            let r = p.size * progress
            context.fill(
                Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                with: .color(p.color.opacity(progress))
            )
        }

        for s in controller.particles.shockwaves {
            let alpha = min(max(1.0 - s.progress, 0.0), 1.0)
            let r = s.currentRadius
            let lw = 2.5 * alpha + 0.5
            context.stroke(
                Path(ellipseIn: CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)),
                with: .color(s.color.opacity(alpha * 0.75)),
                lineWidth: lw
            )
        }

        for f in controller.particles.floatingTexts {
            let alpha = min(max(f.life / f.maxLife, 0.0), 1.0)
            let text = Text(f.text)
                .font(.system(size: f.isLarge ? 22 : 13, weight: .black, design: .rounded))
                .foregroundColor(f.color.opacity(alpha))
            context.draw(text, at: CGPoint(x: f.x, y: f.y), anchor: .center)
        }
    }

    // MARK: - Easter Egg Bee
    private func drawBee(context: inout GraphicsContext, bee: EasterEggBee) {
        var beeCtx = context
        beeCtx.translateBy(x: bee.x, y: bee.y)
        beeCtx.scaleBy(x: 0.58, y: 0.58)
        beeCtx.rotate(by: Angle(radians: bee.tiltAngle))
        if !bee.isFacingRight {
            beeCtx.scaleBy(x: -1.0, y: 1.0)
        }

        // 1. Triangular Stinger at the rear
        var stinger = Path()
        stinger.move(to: CGPoint(x: -15.0, y: -2.0))
        stinger.addLine(to: CGPoint(x: -23.0, y: 0.0))
        stinger.addLine(to: CGPoint(x: -15.0, y: 2.0))
        stinger.closeSubpath()
        beeCtx.fill(stinger, with: .color(Color(hex: 0xFF1B1B1B)))

        // 2. Dangling Little Legs (3 bent black legs underneath)
        for legX in [-5.0, 1.0, 7.0] {
            var leg = Path()
            leg.move(to: CGPoint(x: legX, y: 10.0))
            leg.addLine(to: CGPoint(x: legX - 2.0, y: 14.5))
            leg.addLine(to: CGPoint(x: legX - 5.0, y: 17.5))
            beeCtx.stroke(leg, with: .color(Color(hex: 0xFF1B1B1B)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
        }

        // 3. Plump Oval Body
        let bodyRect = CGRect(x: -16.0, y: -12.0, width: 32.0, height: 24.0)
        let bodyPath = Path(ellipseIn: bodyRect)
        beeCtx.fill(bodyPath, with: .color(Color(hex: 0xFFFFD600)))

        // 4. Bold Black Stripes (Curved within body contour)
        var clippedCtx = beeCtx
        clippedCtx.clip(to: bodyPath)
        clippedCtx.fill(Path(CGRect(x: -7.0, y: -14.0, width: 5.0, height: 28.0)), with: .color(Color(hex: 0xFF1B1B1B)))
        clippedCtx.fill(Path(CGRect(x: 2.0, y: -14.0, width: 5.0, height: 28.0)), with: .color(Color(hex: 0xFF1B1B1B)))

        // Body Outline
        beeCtx.stroke(bodyPath, with: .color(Color(hex: 0xFF1B1B1B)), lineWidth: 2.2)

        // 5. Delicate Fluttering Wings on Back (Rapid vibration oscillation)
        let flap = bee.wingFlap
        let wingAngle1 = -0.32 + flap * 0.28
        let wingAngle2 = -0.12 - flap * 0.25

        // Rear Wing
        var rearWingCtx = beeCtx
        rearWingCtx.translateBy(x: -4.0, y: -10.0)
        rearWingCtx.rotate(by: Angle(radians: wingAngle1))
        let wing1Rect = CGRect(x: -6.0, y: -14.0, width: 12.0, height: 14.0)
        rearWingCtx.fill(Path(ellipseIn: wing1Rect), with: .color(Color(hex: 0xDDE2E8F0)))
        rearWingCtx.stroke(Path(ellipseIn: wing1Rect), with: .color(Color(hex: 0xFF78909C)), lineWidth: 1.4)

        // Front Wing
        var frontWingCtx = beeCtx
        frontWingCtx.translateBy(x: 2.0, y: -10.0)
        frontWingCtx.rotate(by: Angle(radians: wingAngle2))
        let wing2Rect = CGRect(x: -6.0, y: -16.0, width: 13.0, height: 16.0)
        frontWingCtx.fill(Path(ellipseIn: wing2Rect), with: .color(Color(hex: 0xEEEDF2F7)))
        frontWingCtx.stroke(Path(ellipseIn: wing2Rect), with: .color(Color(hex: 0xFF78909C)), lineWidth: 1.4)

        // 6. Cute Chibi Face (Dot Eyes with Catchlights & Curved Smile)
        beeCtx.fill(Path(ellipseIn: CGRect(x: 10.0 - 1.6, y: -2.5 - 1.6, width: 3.2, height: 3.2)), with: .color(Color(hex: 0xFF1B1B1B)))
        beeCtx.fill(Path(ellipseIn: CGRect(x: 13.5 - 1.4, y: -2.0 - 1.4, width: 2.8, height: 2.8)), with: .color(Color(hex: 0xFF1B1B1B)))

        // White eye glint catchlights
        beeCtx.fill(Path(ellipseIn: CGRect(x: 9.6 - 0.6, y: -3.0 - 0.6, width: 1.2, height: 1.2)), with: .color(.white))
        beeCtx.fill(Path(ellipseIn: CGRect(x: 13.1 - 0.5, y: -2.5 - 0.5, width: 1.0, height: 1.0)), with: .color(.white))

        // Smiling curved mouth
        var smile = Path()
        smile.move(to: CGPoint(x: 9.8, y: 1.8))
        smile.addQuadCurve(to: CGPoint(x: 13.8, y: 1.8), control: CGPoint(x: 11.8, y: 4.2))
        beeCtx.stroke(smile, with: .color(Color(hex: 0xFF1B1B1B)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

        // Rosy cheek blush
        beeCtx.fill(Path(ellipseIn: CGRect(x: 11.5 - 2.2, y: 3.8 - 2.2, width: 4.4, height: 4.4)), with: .color(Color(hex: 0xFFFF8A80).opacity(0.45)))
    }

    // MARK: - Windshield Bug Splat
    private func drawWindshieldSplat(context: inout GraphicsContext, splat: WindshieldSplat, size: CGSize) {
        let alpha = splat.alpha
        guard alpha > 0 else { return }

        // 1. Wet glass translucent smudge halo
        let smudgeRect = CGRect(x: splat.x - 24.0, y: splat.y - 24.0, width: 48.0, height: 48.0)
        context.fill(Path(ellipseIn: smudgeRect), with: .color(Color(hex: 0xFFCC1122).opacity(0.12 * alpha)))

        // 2. Pixel Splatter drops
        var splatCtx = context
        splatCtx.translateBy(x: splat.x, y: splat.y)

        let splatBlobs: [(Double, Double, Double, Color)] = [
            (0, 0, 7.5, Color(hex: 0xFFCC1122)),
            (-4, -3, 4.5, Color(hex: 0xFF8E070D)),
            (5, -2, 5.0, Color(hex: 0xFFCC1122)),
            (-2, 5, 5.5, Color(hex: 0xFFFF2E3D)),
            (4, 4, 4.0, Color(hex: 0xFF8E070D)),
            (-8, 2, 2.5, Color(hex: 0xFFCC1122)),
            (8, -6, 2.8, Color(hex: 0xFFFF2E3D)),
            (-5, -8, 2.2, Color(hex: 0xFF8E070D)),
            (2, 9, 3.0, Color(hex: 0xFFCC1122)),
            (11, 5, 1.8, Color(hex: 0xFFFF2E3D)),
            (-10, -5, 1.8, Color(hex: 0xFF8E070D)),
            (0, -10, 2.0, Color(hex: 0xFFCC1122))
        ]

        for blob in splatBlobs {
            let bRect = CGRect(x: blob.0 - blob.2, y: blob.1 - blob.2, width: blob.2 * 2, height: blob.2 * 2)
            splatCtx.fill(Path(ellipseIn: bRect), with: .color(blob.3.opacity(alpha * 0.95)))
        }

        // Wet dripping mark
        var drip = Path()
        drip.move(to: CGPoint(x: 0, y: 6))
        drip.addLine(to: CGPoint(x: 1, y: 16))
        splatCtx.stroke(drip, with: .color(Color(hex: 0xFF8E070D).opacity(alpha * 0.7)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        splatCtx.fill(Path(ellipseIn: CGRect(x: 0.2, y: 16, width: 2.2, height: 2.2)), with: .color(Color(hex: 0xFFCC1122).opacity(alpha * 0.85)))
    }

    // MARK: - Boss Warning Banner
    private func drawBossWarningBanner(context: inout GraphicsContext, size: CGSize, time: Double) {
        guard controller.bossWarningTimer > 0 else { return }
        let timer = controller.bossWarningTimer
        let alpha = min(max(timer < 0.3 ? timer / 0.3 : (timer > 2.0 ? (2.4 - timer) / 0.4 : 1.0), 0.0), 1.0)
        let bannerH: Double = 52.0
        let bannerY = size.height * 0.32
        let bannerRect = CGRect(x: 0, y: bannerY - bannerH / 2.0, width: size.width, height: bannerH)

        // Holographic warning container
        context.fill(Path(bannerRect), with: .color(Color(hex: 0xEE160408).opacity(alpha * 0.92)))

        // Animated diagonal danger stripes across width
        let stripeOffset = (time * 42.0).truncatingRemainder(dividingBy: 24.0)
        var stripes = Path()
        var sx = -stripeOffset
        while sx < size.width + 30 {
            stripes.move(to: CGPoint(x: sx, y: bannerRect.maxY))
            stripes.addLine(to: CGPoint(x: sx + 14.0, y: bannerRect.minY))
            sx += 24.0
        }
        var clippedCtx = context
        clippedCtx.clip(to: Path(bannerRect))
        clippedCtx.stroke(stripes, with: .color(Color(hex: 0xFFFF1744).opacity(alpha * 0.18)), lineWidth: 6.0)

        // Laser borders on top & bottom
        var topBorder = Path()
        topBorder.move(to: CGPoint(x: 0, y: bannerRect.minY))
        topBorder.addLine(to: CGPoint(x: size.width, y: bannerRect.minY))
        context.stroke(topBorder, with: .color(Color(hex: 0xFFFF1744).opacity(alpha * 0.95)), lineWidth: 2.0)

        var bottomBorder = Path()
        bottomBorder.move(to: CGPoint(x: 0, y: bannerRect.maxY))
        bottomBorder.addLine(to: CGPoint(x: size.width, y: bannerRect.maxY))
        context.stroke(bottomBorder, with: .color(Color(hex: 0xFFFF1744).opacity(alpha * 0.95)), lineWidth: 2.0)

        // Pulsating Warning Text
        let textPulse = 1.0 + 0.06 * sin(time * 12.0)
        let text = Text(I18n.tr("boss_incoming_warning"))
            .font(.system(size: 16.0 * textPulse, weight: .black, design: .monospaced))
            .foregroundColor(Color(hex: 0xFFFF1744).opacity(alpha))
        context.draw(text, at: CGPoint(x: size.width / 2.0, y: bannerY), anchor: .center)
    }

    // MARK: - Level Clear Celebration Banner
    private func drawLevelClearCelebration(context: inout GraphicsContext, size: CGSize, time: Double) {
        guard controller.levelTransitionTimer > 0 else { return }
        let timer = controller.levelTransitionTimer
        let progress = min(max(1.0 - timer / 1.0, 0.0), 1.0)
        let alpha = min(max(progress < 0.2 ? progress / 0.2 : (progress > 0.8 ? (1.0 - progress) / 0.2 : 1.0), 0.0), 1.0)
        let bannerH: Double = 60.0
        let bannerY = size.height * 0.38
        let bannerRect = CGRect(x: 0, y: bannerY - bannerH / 2.0, width: size.width, height: bannerH)

        // Holographic celebration container
        context.fill(Path(bannerRect), with: .color(Color(hex: 0xEE0B1A24).opacity(alpha * 0.95)))

        // Glowing cyan & gold celebratory borders
        var topBorder = Path()
        topBorder.move(to: CGPoint(x: 0, y: bannerRect.minY))
        topBorder.addLine(to: CGPoint(x: size.width, y: bannerRect.minY))
        context.stroke(topBorder, with: .color(Color(hex: 0xFF00E5FF).opacity(alpha * 0.95)), lineWidth: 2.2)

        var bottomBorder = Path()
        bottomBorder.move(to: CGPoint(x: 0, y: bannerRect.maxY))
        bottomBorder.addLine(to: CGPoint(x: size.width, y: bannerRect.maxY))
        context.stroke(bottomBorder, with: .color(Color(hex: 0xFFFFD54F).opacity(alpha * 0.95)), lineWidth: 2.2)

        // Sparkling celebratory confetti stars
        for i in 0..<16 {
            let cx = (Double(i) * 47.0 + time * 60.0).truncatingRemainder(dividingBy: size.width)
            let cy = bannerRect.minY + 8.0 + (Double(i) * 17.0).truncatingRemainder(dividingBy: bannerH - 16.0)
            let color: Color = (i % 3 == 0) ? Color(hex: 0xFFFFD54F) : ((i % 3 == 1) ? Color(hex: 0xFF00E5FF) : Color(hex: 0xFFFF4081))
            let pulse = 0.6 + 0.4 * sin(time * 8.0 + Double(i))
            context.fill(Path(ellipseIn: CGRect(x: cx - 2.2, y: cy - 2.2, width: 4.4, height: 4.4)), with: .color(color.opacity(alpha * pulse)))
        }

        // Triumphant Text
        let text = Text(I18n.tr("level_clear_banner"))
            .font(.system(size: 18.0, weight: .black, design: .rounded))
            .foregroundColor(Color(hex: 0xFFFFD54F).opacity(alpha))
        context.draw(text, at: CGPoint(x: size.width / 2.0, y: bannerY), anchor: .center)
    }
}
