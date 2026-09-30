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
                    drawBricks(context: &ctx, time: controller.gameTime)
                    drawNet(context: &ctx, size: size)
                    drawPaddle(context: &ctx)
                    drawCapsules(context: &ctx)
                    drawProjectiles(context: &ctx)
                    drawBalls(context: &ctx)
                    drawDrone(context: &ctx)
                    drawParticles(context: &ctx)
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
                        if let prevX = lastDragX {
                            let delta = Double(value.location.x - prevX)
                            controller.movePaddleBy(deltaX: delta)
                        } else {
                            // Tap down: if ready or ball is stuck, launch it
                            if controller.status == .ready || controller.hasStuckBall {
                                controller.launchBall()
                            }
                        }
                        lastDragX = value.location.x
                    }
                    .onEnded { _ in
                        lastDragX = nil
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        controller.triggerUlti()
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
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(hex: 0xFF161B30),
                    Color(hex: 0xFF090B14),
                    Color(hex: 0xFF040508)
                ]),
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.35),
                startRadius: 10,
                endRadius: max(size.width, size.height) * 0.85
            )
        )

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

    // MARK: - Bricks & Mecha Boss
    private func drawBricks(context: inout GraphicsContext, time: Double) {
        for b in controller.bricks where b.isAlive {
            var bCtx = context
            let cx = b.x + b.width / 2.0
            let cy = b.y + b.height / 2.0
            bCtx.translateBy(x: cx, y: cy)

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

        let cannonAlpha = 0.75 + sin(time * 8.0) * 0.25
        context.fill(Path(ellipseIn: CGRect(x: -halfW * 0.5 - 3, y: halfH + 6, width: 6, height: 6)), with: .color(Color(hex: 0xFFFF1744).opacity(cannonAlpha)))
        context.fill(Path(ellipseIn: CGRect(x: halfW * 0.5 - 3, y: halfH + 6, width: 6, height: 6)), with: .color(Color(hex: 0xFFFF1744).opacity(cannonAlpha)))

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

        // Define beautiful skin themes
        let skins: [(c1: Color, c2: Color, glow: Color, inner: Color)] = [
            (Color(hex: 0xFF40C4FF), Color(hex: 0xFF7C4DFF), Color(hex: 0xFF40C4FF), Color(hex: 0xFFB3E5FC)), // 0: Cyberpunk Blue/Purple
            (Color(hex: 0xFFFF5252), Color(hex: 0xFFC51162), Color(hex: 0xFFFF5252), Color(hex: 0xFFFF8A80)), // 1: Crimson Red
            (Color(hex: 0xFF00E676), Color(hex: 0xFF1DE9B6), Color(hex: 0xFF00E676), Color(hex: 0xFFB9F6CA)), // 2: Emerald Green
            (Color(hex: 0xFFFFD740), Color(hex: 0xFFFF6D00), Color(hex: 0xFFFFD740), Color(hex: 0xFFFFE57F)), // 3: Golden Orange
            (Color(hex: 0xFF263238), Color(hex: 0xFFECEFF1), Color(hex: 0xFF90A4AE), Color(hex: 0xFFCFD8DC))  // 4: Obsidian Silver
        ]
        let skin = skins[p.skinIndex % skins.count]

        let glowRect = rect.insetBy(dx: -2.0, dy: -2.0)
        let glowPath = Path(roundedRect: glowRect, cornerRadius: glowRect.height / 2.0)
        context.stroke(glowPath, with: .color(skin.glow.opacity(0.4 * alphaMul)), lineWidth: 3.5)

        context.fill(
            rrect,
            with: .linearGradient(
                Gradient(colors: [skin.c1.opacity(alphaMul), skin.c2.opacity(alphaMul)]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            )
        )

        // Inner neon band
        let innerRect = rect.insetBy(dx: 3.0, dy: 3.0)
        context.stroke(Path(roundedRect: innerRect, cornerRadius: innerRect.height / 2.0), with: .color(skin.inner.opacity(0.6 * alphaMul)), lineWidth: 1.5)

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
        for ball in controller.balls {
            // Trail
            let count = ball.trail.count
            if count > 0 {
                for i in 0..<count {
                    let pt = ball.trail[i]
                    let progress = 1.0 - (Double(i) / Double(count))
                    let trailRadius = ball.radius * progress * 0.75
                    let trailColor = (ball.isFireball ? Color(hex: 0xFFFF6D00) : Color(hex: 0xFF40C4FF)).opacity(progress * 0.45)
                    context.fill(
                        Path(ellipseIn: CGRect(x: pt.position.x - trailRadius, y: pt.position.y - trailRadius, width: trailRadius * 2, height: trailRadius * 2)),
                        with: .color(trailColor)
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

            let glowR = ball.radius + 3.0
            let glowColor = ball.isFireball ? Color(hex: 0xFFFF6D00) : Color.white
            bCtx.fill(Path(ellipseIn: CGRect(x: -glowR, y: -glowR, width: glowR * 2, height: glowR * 2)), with: .color(glowColor.opacity(0.28)))

            let coreColor: Color = ball.isFireball
                ? Color(hex: 0xFFFFD54F)
                : (ball.isBomb ? Color(hex: 0xFFFF5252) : Color.white)
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
    private func drawCapsules(context: inout GraphicsContext) {
        for cap in controller.capsules {
            let bob = sin(cap.animTimer * 6.0) * 2.5
            let cx = cap.x
            let cy = cap.y + bob
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
}
