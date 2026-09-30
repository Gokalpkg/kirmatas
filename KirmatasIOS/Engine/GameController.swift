import Foundation
import SwiftUI
import Combine

final class GameController: ObservableObject {
    let save = SaveManager.shared
    let audio = AudioManager.shared
    let particles = ParticleSystem()

    @Published var currentMode: GameMode = .classic
    @Published var status: GameStatus = .ready
    @Published var stats = MatchStats()
    @Published var activePowerUps: [ActivePowerUp] = []
    @Published var frameTick: UInt64 = 0

    var screenWidth: Double = 390.0
    var screenHeight: Double = 844.0

    var paddle: Paddle
    var balls: [Ball] = []
    var bricks: [Brick] = []
    var capsules: [FallingCapsule] = []
    var projectiles: [Projectile] = []

    var descendTimer: Double = 0.0
    var droneShootTimer: Double = 0.0
    var lightningTimer: Double = 0.0
    var comboTimer: Double = 0.0
    var gameTime: Double = 0.0

    private var statusBeforePause: GameStatus = .playing

    init() {
        self.paddle = Paddle(x: 150, y: 700)
    }

    func setDimensions(width: Double, height: Double) {
        guard width > 50, height > 50 else { return }
        if abs(screenWidth - width) < 1.0 && abs(screenHeight - height) < 1.0 { return }
        screenWidth = width
        screenHeight = height
        paddle.y = screenHeight - 115.0
        if status == .ready {
            resetPaddleAndBall()
            loadLevelBricks()
        }
    }

    func startNewGame(mode: GameMode) {
        currentMode = mode
        status = .ready

        let startLives = (mode == .zen) ? 999 : 3
        stats.reset(initialLives: startLives, startLevel: 1)
        particles.clear()
        capsules.removeAll()
        projectiles.removeAll()
        activePowerUps.removeAll()

        resetPaddleAndBall()
        loadLevelBricks()
        objectWillChange.send()
    }

    func resetPaddleAndBall() {
        paddle.width = paddle.baseWidth
        paddle.x = (screenWidth - paddle.width) / 2.0
        paddle.y = screenHeight - 115.0
        paddle.isSticky = false
        paddle.hasLaser = false
        paddle.hasRockets = false
        paddle.hasDrone = false
        paddle.hasNet = false
        paddle.isGhost = false
        paddle.isReversed = false
        paddle.isClumsy = false

        balls.removeAll()
        balls.append(
            Ball(
                x: paddle.x + paddle.width / 2.0,
                y: paddle.y - 12.0,
                isStuck: true,
                stuckOffsetX: paddle.width / 2.0
            )
        )
    }

    func loadLevelBricks() {
        switch currentMode {
        case .classic:
            bricks = LevelDesign.buildClassicLevel(level: stats.level, screenWidth: screenWidth, screenHeight: screenHeight)
        case .zen:
            bricks = LevelDesign.buildZenLevel(screenWidth: screenWidth, screenHeight: screenHeight)
        case .descend:
            bricks = LevelDesign.buildDescendInitial(screenWidth: screenWidth, screenHeight: screenHeight)
            descendTimer = 13.0
        case .daily:
            bricks = LevelDesign.buildDailyLevel(date: Date(), screenWidth: screenWidth, screenHeight: screenHeight)
        case .shapes:
            bricks = LevelDesign.buildShapesLevel(level: stats.level, screenWidth: screenWidth, screenHeight: screenHeight)
        }
    }

    var hasStuckBall: Bool {
        balls.contains(where: { $0.isStuck })
    }

    func launchBall() {
        if status == .ready {
            status = .playing
        }

        var anyLaunched = false
        for ball in balls {
            if ball.isStuck {
                ball.isStuck = false
                ball.stuckTimer = 0.0
                let speed = getBaseBallSpeed()
                let angle = -.pi / 2.0 + Double.random(in: -0.2...0.2)
                ball.vx = cos(angle) * speed
                ball.vy = sin(angle) * speed
                anyLaunched = true
            }
        }
        if anyLaunched {
            audio.playSfx(.hitPaddle)
            objectWillChange.send()
        }
    }

    func getBaseBallSpeed() -> Double {
        let base = 360.0 * save.speed.multiplier
        return base + min(Double(stats.level) * 10.0, 90.0)
    }

    func movePaddleTo(targetX: Double) {
        guard status == .playing || status == .ready else { return }

        var actualTarget = targetX
        if paddle.isReversed {
            actualTarget = screenWidth - targetX
        }

        let halfW = paddle.width / 2.0
        let newX = actualTarget - halfW

        if paddle.isClumsy {
            paddle.x += (newX - paddle.x) * 0.15
        } else {
            paddle.x = newX
        }

        paddle.x = min(max(paddle.x, 8.0), max(8.0, screenWidth - paddle.width - 8.0))

        for ball in balls where ball.isStuck {
            ball.x = paddle.x + ball.stuckOffsetX
            ball.y = paddle.y - ball.radius - 2.0
        }
    }

    func movePaddleBy(deltaX: Double) {
        guard status == .playing || status == .ready else { return }

        var delta = deltaX
        if paddle.isReversed {
            delta = -deltaX
        }

        if paddle.isClumsy {
            paddle.x += delta * 1.35
        } else {
            paddle.x += delta
        }

        paddle.x = min(max(paddle.x, 8.0), max(8.0, screenWidth - paddle.width - 8.0))

        for ball in balls where ball.isStuck {
            ball.x = paddle.x + ball.stuckOffsetX
            ball.y = paddle.y - ball.radius - 2.0
        }
    }

    func update(dt: Double) {
        gameTime += dt

        guard status == .playing else {
            particles.update(dt: dt)
            frameTick &+= 1
            return
        }

        var effectiveDt = dt
        if stats.bulletTimeLeft > 0 {
            stats.bulletTimeLeft -= dt
            effectiveDt = dt * 0.45
        }

        particles.update(dt: effectiveDt)
        paddle.update(dt: effectiveDt)

        updatePowerUpTimers(dt: effectiveDt)
        updateCombo(dt: effectiveDt)
        updateProjectiles(dt: effectiveDt)
        updateCapsules(dt: effectiveDt)
        updateBricks(dt: effectiveDt)
        updateBalls(dt: effectiveDt)
        checkGameProgress()

        frameTick &+= 1
    }

    private func updatePowerUpTimers(dt: Double) {
        for i in stride(from: activePowerUps.count - 1, through: 0, by: -1) {
            activePowerUps[i].timeLeft -= dt
            if activePowerUps[i].timeLeft <= 0 {
                let expiredType = activePowerUps[i].type
                activePowerUps.remove(at: i)
                removePowerUp(expiredType)
            }
        }

        // Laser cannons auto firing
        if paddle.hasLaser && paddle.laserCooldown <= 0 {
            paddle.laserCooldown = 0.48
            projectiles.append(
                Projectile(
                    x: paddle.x + 6.0,
                    y: paddle.y - 6.0,
                    vy: -520.0,
                    radius: 3.5,
                    isLaser: true
                )
            )
            projectiles.append(
                Projectile(
                    x: paddle.x + paddle.width - 6.0,
                    y: paddle.y - 6.0,
                    vy: -520.0,
                    radius: 3.5,
                    isLaser: true
                )
            )
            audio.playSfx(.laser)
        }

        // Rocket launcher auto firing
        if paddle.hasRockets && paddle.rocketCooldown <= 0 {
            paddle.rocketCooldown = 1.15
            projectiles.append(
                Projectile(
                    x: paddle.x + paddle.width / 2.0,
                    y: paddle.y - 10.0,
                    vy: -380.0,
                    radius: 5.0,
                    isRocket: true
                )
            )
            audio.playSfx(.laser)
        }

        // Drone auto firing
        if paddle.hasDrone {
            droneShootTimer += dt
            if droneShootTimer >= 0.85 {
                droneShootTimer = 0
                let dx = paddle.x + paddle.width / 2.0 + cos(paddle.droneAngle) * 40.0
                let dy = paddle.y - 20.0 + sin(paddle.droneAngle) * 15.0
                projectiles.append(
                    Projectile(
                        x: dx,
                        y: dy,
                        vy: -480.0,
                        radius: 3.5,
                        isLaser: true
                    )
                )
                audio.playSfx(.laser)
            }
        }

        // Lightning periodic zap
        if activePowerUps.contains(where: { $0.type == .lightning }) {
            lightningTimer += dt
            if lightningTimer >= 1.25 {
                lightningTimer = 0
                let alive = bricks.filter { $0.isAlive && !$0.isSteel }
                if let target = alive.randomElement() {
                    let tx = target.x + target.width / 2.0
                    let ty = target.y + target.height / 2.0
                    particles.spawnShockwave(x: tx, y: ty, color: Color(hex: 0xFF00E5FF), maxRadius: 48.0)
                    hitBrick(target, ball: nil)
                }
            }
        }

        // Ulti active timer
        if stats.ultiActiveLeft > 0 {
            stats.ultiActiveLeft -= dt
            if Double.random(in: 0...1) < 0.25 {
                projectiles.append(
                    Projectile(
                        x: paddle.x + Double.random(in: 0...paddle.width),
                        y: paddle.y - 8.0,
                        vy: -600.0,
                        radius: 5.0,
                        isLaser: true
                    )
                )
                audio.playSfx(.laser)
            }
        }
    }

    private func updateCombo(dt: Double) {
        if comboTimer > 0 {
            comboTimer -= dt
            if comboTimer <= 0 {
                stats.combo = 0
                stats.isFever = false
            }
        }
        if stats.feverTimeLeft > 0 {
            stats.feverTimeLeft -= dt
            if stats.feverTimeLeft <= 0 {
                stats.isFever = false
            }
        }
    }

    private func updateProjectiles(dt: Double) {
        for i in stride(from: projectiles.count - 1, through: 0, by: -1) {
            let p = projectiles[i]
            p.update(dt: dt)

            if p.y < 0 || p.y > screenHeight {
                projectiles.remove(at: i)
                continue
            }

            if p.isBossBullet {
                if paddle.rect.contains(CGPoint(x: p.x, y: p.y)) {
                    projectiles.remove(at: i)
                    particles.triggerShake(magnitude: 4.0, duration: 0.2)
                    particles.spawnBurst(x: p.x, y: p.y, color: Color(hex: 0xFFFF5252), count: 12)
                    audio.playSfx(.explosion)
                    continue
                }
            } else {
                var hit = false
                for b in bricks where b.isAlive {
                    if b.rect.contains(CGPoint(x: p.x, y: p.y)) {
                        hit = true
                        if p.isRocket {
                            explodeArea(cx: p.x, cy: p.y, radius: 65.0)
                        } else {
                            hitBrick(b, ball: nil)
                        }
                        break
                    }
                }
                if hit {
                    projectiles.remove(at: i)
                }
            }
        }
    }

    private func updateCapsules(dt: Double) {
        let hasVortex = activePowerUps.contains(where: { $0.type == .vortex })
        let paddleCenter = CGPoint(x: paddle.x + paddle.width / 2.0, y: paddle.y)

        for i in stride(from: capsules.count - 1, through: 0, by: -1) {
            let c = capsules[i]
            c.update(dt: dt)

            if hasVortex {
                let dx = paddleCenter.x - c.x
                let dy = paddleCenter.y - c.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist > 1.0 && dist < 260.0 {
                    let pull = 220.0
                    c.x += (dx / dist) * pull * dt
                    c.y += (dy / dist) * pull * dt
                }
            }

            let capRect = CGRect(x: c.x - c.width / 2.0, y: c.y - c.height / 2.0, width: c.width, height: c.height)
            if paddle.rect.intersects(capRect) {
                let type = c.type
                capsules.remove(at: i)
                applyPowerUp(type)
                continue
            }

            if c.y > screenHeight {
                capsules.remove(at: i)
            }
        }
    }

    private func updateBricks(dt: Double) {
        for b in bricks {
            b.update(dt: dt)

            if b.isAlive && b.isBoss && b.shootTimer <= 0 {
                b.shootTimer = 2.2 + Double.random(in: 0...1.2)
                projectiles.append(
                    Projectile(
                        x: b.x + b.width * 0.25,
                        y: b.y + b.height + 6.0,
                        vy: 200.0,
                        radius: 5.5,
                        isBossBullet: true
                    )
                )
                projectiles.append(
                    Projectile(
                        x: b.x + b.width * 0.75,
                        y: b.y + b.height + 6.0,
                        vy: 200.0,
                        radius: 5.5,
                        isBossBullet: true
                    )
                )
                audio.playSfx(.laser)
            }
        }

        if currentMode != .shapes {
            bricks.removeAll(where: { !$0.isAlive && $0.jelly <= 0 })
        }

        if currentMode == .descend {
            descendTimer -= dt
            if descendTimer <= 0 {
                descendTimer = 11.0
                let rowStep = 28.0
                for b in bricks {
                    b.targetY += rowStep
                    if b.isAlive && b.targetY + b.height >= paddle.y {
                        onGameOver()
                        return
                    }
                }
                let newRow = LevelDesign.buildDescendRow(rowIndex: 0, screenWidth: screenWidth, screenHeight: screenHeight)
                for b in newRow {
                    b.y = LevelDesign.baseTopMargin - rowStep
                    b.targetY = LevelDesign.baseTopMargin
                }
                bricks.append(contentsOf: newRow)
                particles.triggerShake(magnitude: 3.0, duration: 0.16)
                audio.playSfx(.hitWall)
            }
        }

        if currentMode == .zen {
            let aliveCount = bricks.filter { $0.isAlive }.count
            if aliveCount < 8 {
                let newBricks = LevelDesign.buildZenLevel(screenWidth: screenWidth, screenHeight: screenHeight)
                bricks.append(contentsOf: newBricks)
            }
        }
    }

    private func updateBalls(dt: Double) {
        for i in stride(from: balls.count - 1, through: 0, by: -1) {
            let ball = balls[i]
            if ball.isStuck {
                if status == .playing {
                    ball.stuckTimer += dt
                    if ball.stuckTimer >= 1.6 || !paddle.isSticky {
                        launchBall()
                    }
                }
                continue
            }

            ball.update(dt: dt)

            if ball.cornerBoostTimer > 0 {
                if Double.random(in: 0...1) < 0.35 {
                    particles.spawnBurst(x: ball.x, y: ball.y, color: Color(hex: 0xFFFFD54F), count: 2, speed: 60.0)
                }
            } else if ball.speed > getBaseBallSpeed() * 1.15 && !activePowerUps.contains(where: { $0.type == .fastball }) {
                let target = min(max(ball.speed - dt * 140.0, getBaseBallSpeed()), 850.0)
                ball.setSpeed(target)
            }

            // Left/Right Wall collisions
            if ball.x - ball.radius <= 0 {
                ball.x = ball.radius
                ball.vx = abs(ball.vx)
                ball.triggerSquash(0)
                audio.playSfx(.hitWall)
            } else if ball.x + ball.radius >= screenWidth {
                ball.x = screenWidth - ball.radius
                ball.vx = -abs(ball.vx)
                ball.triggerSquash(.pi)
                audio.playSfx(.hitWall)
            }

            // Top Wall collision (below HUD bar)
            if ball.y - ball.radius <= 56.0 {
                ball.y = 56.0 + ball.radius
                ball.vy = abs(ball.vy)
                ball.triggerSquash(.pi / 2.0)
                audio.playSfx(.hitWall)
            }

            // Safety Net collision
            if paddle.hasNet && ball.y + ball.radius >= screenHeight - 28.0 {
                ball.vy = -abs(ball.vy)
                paddle.netHitsRemaining -= 1
                if paddle.netHitsRemaining <= 0 {
                    paddle.hasNet = false
                }
                particles.spawnShockwave(x: ball.x, y: ball.y, color: Color(hex: 0xFF8BC34A), maxRadius: 35.0)
                audio.playSfx(.hitWall)
            }

            // Bottom fall
            if ball.y - ball.radius > screenHeight {
                balls.remove(at: i)
                continue
            }

            // Paddle collision
            if !paddle.isGhost && checkBallPaddleCollision(ball) {
                continue
            }

            // Brick collision
            checkBallBrickCollision(ball)
        }

        if balls.isEmpty {
            loseLife()
        }
    }

    private func checkBallPaddleCollision(_ ball: Ball) -> Bool {
        let pr = paddle.rect
        guard ball.vy > 0,
              ball.y + ball.radius >= pr.minY,
              ball.y - ball.radius <= pr.maxY,
              ball.x + ball.radius >= pr.minX,
              ball.x - ball.radius <= pr.maxX else {
            return false
        }

        if paddle.isSticky {
            ball.isStuck = true
            ball.stuckTimer = 0.0
            ball.stuckOffsetX = ball.x - paddle.x
            ball.vy = 0
            ball.vx = 0
            audio.playSfx(.hitPaddle)
            return true
        }

        let hitOffset = min(max((ball.x - (paddle.x + paddle.width / 2.0)) / (paddle.width / 2.0), -1.0), 1.0)
        let bounceAngle = hitOffset * (.pi / 2.7)
        let baseSpeed = min(ball.speed + 6.0, 680.0)

        let isCornerHit = abs(hitOffset) >= 0.78
        let speedMultiplier = isCornerHit ? 1.45 : 1.0
        let finalSpeed = min(max(baseSpeed * speedMultiplier, 100.0), 850.0)

        ball.vx = sin(bounceAngle) * finalSpeed
        ball.vy = -cos(bounceAngle) * finalSpeed
        ball.vx += paddle.velocityX * 0.25

        ball.y = pr.minY - ball.radius - 1.0
        ball.triggerSquash(-.pi / 2.0)

        if isCornerHit {
            ball.cornerBoostTimer = 3.2
            particles.spawnBurst(x: ball.x, y: pr.minY, color: Color(hex: 0xFFFFD54F), count: 20)
            particles.spawnFloatingText(x: ball.x, y: pr.minY - 18.0, text: I18n.tr("corner_shot"), color: Color(hex: 0xFFFFD54F), isLarge: true)
            audio.playSfx(.ulti)
        } else {
            particles.spawnShockwave(x: ball.x, y: pr.minY, color: Color(hex: 0xFF40C4FF), maxRadius: 32.0)
            audio.playSfx(.hitPaddle)
        }
        return true
    }

    private func checkBallBrickCollision(_ ball: Ball) {
        let r = ball.radius
        let rSq = r * r
        let bx = ball.x
        let by = ball.y

        for b in bricks where b.isAlive {
            if by + r < b.y || by - r > b.y + b.height || bx + r < b.x || bx - r > b.x + b.width {
                continue
            }

            let nearestX = min(max(bx, b.x), b.x + b.width)
            let nearestY = min(max(by, b.y), b.y + b.height)
            let distX = bx - nearestX
            let distY = by - nearestY
            let distSq = distX * distX + distY * distY

            if distSq <= rSq {
                hitBrick(b, ball: ball)

                if !ball.isFireball && !ball.isPierce {
                    let overlapX = r - abs(distX)
                    let overlapY = r - abs(distY)

                    if overlapX < overlapY {
                        ball.vx = distX > 0 ? abs(ball.vx) : -abs(ball.vx)
                        ball.x = distX > 0 ? b.x + b.width + r : b.x - r
                        ball.triggerSquash(distX > 0 ? 0 : .pi)
                    } else {
                        ball.vy = distY > 0 ? abs(ball.vy) : -abs(ball.vy)
                        ball.y = distY > 0 ? b.y + b.height + r : b.y - r
                        ball.triggerSquash(distY > 0 ? .pi / 2.0 : -.pi / 2.0)
                    }
                }

                if ball.isBomb {
                    explodeArea(cx: b.x + b.width / 2.0, cy: b.y + b.height / 2.0, radius: 55.0)
                    break
                }
            }
        }
    }

    private func hitBrick(_ b: Brick, ball: Ball?) {

        if b.isSteel {
            if let ball = ball, ball.isFireball {
                destroyBrick(b)
            } else {
                b.jelly = 1.0
                particles.spawnBurst(x: b.x + b.width / 2.0, y: b.y + b.height / 2.0, color: .gray, count: 6)
                audio.playSfx(.steel)
            }
            return
        }

        b.hp -= 1
        b.jelly = 0.8

        if b.hp <= 0 {
            destroyBrick(b)
        } else {
            particles.spawnBurst(x: b.x + b.width / 2.0, y: b.y + b.height / 2.0, color: b.color, count: 6)
            audio.playSfx(.hitBrick)
            registerCombo(basePoints: b.points / 2)
        }
    }

    private func destroyBrick(_ b: Brick) {
        b.isAlive = false
        stats.bricksBroken += 1

        let cx = b.x + b.width / 2.0
        let cy = b.y + b.height / 2.0
        particles.spawnBurst(x: cx, y: cy, color: b.color, count: 16)
        particles.spawnShockwave(x: cx, y: cy, color: b.color, maxRadius: 40.0)
        audio.playSfx(.breakBrick)

        registerCombo(basePoints: b.points)

        stats.ultiCharge = min(max(stats.ultiCharge + 4.0, 0.0), 100.0)

        rollCapsuleDrop(x: cx, y: cy)

        if Double.random(in: 0...1) < 0.20 {
            let coins = Int.random(in: 1...3)
            stats.goldCollected += coins
            save.addGold(coins)
            particles.spawnFloatingText(x: cx, y: b.y, text: "+\(coins) 🪙", color: Color(hex: 0xFFFFD54F))
        }
    }

    private func explodeArea(cx: Double, cy: Double, radius: Double = 60.0) {
        particles.spawnBurst(x: cx, y: cy, color: Color(hex: 0xFFFF5722), count: 28, speed: 240.0)
        particles.spawnShockwave(x: cx, y: cy, color: Color(hex: 0xFFFF9800), maxRadius: radius)
        particles.triggerShake(magnitude: 5.0, duration: 0.22)
        audio.playSfx(.explosion)

        for b in bricks {
            guard b.isAlive && !b.isSteel else { continue }
            let bx = b.x + b.width / 2.0
            let by = b.y + b.height / 2.0
            let dist = sqrt((bx - cx) * (bx - cx) + (by - cy) * (by - cy))
            if dist <= radius {
                destroyBrick(b)
            }
        }
    }

    private func registerCombo(basePoints: Int) {
        stats.combo += 1
        if stats.combo > stats.maxCombo {
            stats.maxCombo = stats.combo
        }
        comboTimer = 2.4

        var multiplier = 1.0
        if stats.combo >= 8 {
            multiplier = 3.0
            if !stats.isFever {
                stats.isFever = true
                stats.feverTimeLeft = 6.0
                particles.spawnFloatingText(
                    x: screenWidth / 2.0,
                    y: screenHeight * 0.35,
                    text: I18n.tr("fever_mode"),
                    color: Color(hex: 0xFFFF9100),
                    isLarge: true
                )
            }
        } else if stats.combo >= 4 {
            multiplier = 2.0
        }

        if activePowerUps.contains(where: { $0.type == .doublescore }) {
            multiplier *= 2.0
        }

        let points = Int((Double(basePoints) * multiplier).rounded())
        stats.score += points

        if stats.combo > 1 && stats.combo % 3 == 0 {
            particles.spawnFloatingText(
                x: paddle.x + paddle.width / 2.0,
                y: paddle.y - 28.0,
                text: "\(I18n.tr("combo")) x\(stats.combo)!",
                color: Color(hex: 0xFFFFD54F)
            )
        }
    }

    private func rollCapsuleDrop(x: Double, y: Double) {
        let dropChance = 0.16
        guard Double.random(in: 0...1) <= dropChance else { return }

        let allTypes = PowerUpType.allCases
        let chosen: PowerUpType
        if Double.random(in: 0...1) < 0.80 {
            let buffs = allTypes.filter { $0.kind == .buff }
            chosen = buffs.randomElement() ?? .wide
        } else {
            let debuffs = allTypes.filter { $0.kind == .debuff }
            chosen = debuffs.randomElement() ?? .shrink
        }

        capsules.append(FallingCapsule(x: x, y: y, type: chosen))
    }

    func applyPowerUp(_ type: PowerUpType) {
        audio.playSfx(type.kind == .buff ? .powerupBuff : .powerupDebuff)
        particles.spawnFloatingText(
            x: paddle.x + paddle.width / 2.0,
            y: paddle.y - 30.0,
            text: type.label,
            color: type.color
        )

        if type.isInstant {
            switch type {
            case .multi:
                splitBalls()
            case .life:
                stats.lives += 1
            case .shield:
                paddle.hasNet = true
                paddle.netHitsRemaining = 2
            case .mirror:
                if let first = balls.first {
                    balls.append(
                        Ball(
                            x: min(max(screenWidth - first.x, 20.0), screenWidth - 20.0),
                            y: first.y,
                            vx: -first.vx,
                            vy: first.vy,
                            radius: first.radius,
                            isStuck: false,
                            isMirror: true
                        )
                    )
                }
            case .lock:
                let aliveBricks = bricks.filter { $0.isAlive && !$0.isSteel }
                if let target = aliveBricks.randomElement() {
                    destroyBrick(target)
                    particles.spawnFloatingText(
                        x: target.x + target.width / 2.0,
                        y: target.y,
                        text: I18n.tr("target_locked"),
                        color: Color(hex: 0xFFFFAB00)
                    )
                }
            default:
                break
            }
            return
        }

        activePowerUps.removeAll(where: { $0.type == type })
        activePowerUps.append(ActivePowerUp(type: type))

        switch type {
        case .wide:
            paddle.width = paddle.baseWidth * 1.45
        case .shrink:
            paddle.width = paddle.baseWidth * 0.65
        case .slow:
            for b in balls {
                b.setSpeed(getBaseBallSpeed() * 0.65)
            }
        case .fastball:
            for b in balls {
                b.setSpeed(getBaseBallSpeed() * 1.5)
            }
        case .sticky:
            paddle.isSticky = true
        case .laser:
            paddle.hasLaser = true
        case .rocket:
            paddle.hasRockets = true
        case .fireball:
            for b in balls { b.isFireball = true }
        case .bomb:
            for b in balls { b.isBomb = true }
        case .pierce:
            for b in balls { b.isPierce = true }
        case .net:
            paddle.hasNet = true
            paddle.netHitsRemaining = 4
        case .drone:
            paddle.hasDrone = true
        case .chrono:
            stats.bulletTimeLeft = 4.5
        case .reverse:
            paddle.isReversed = true
        case .clumsy:
            paddle.isClumsy = true
        case .invis:
            paddle.isGhost = true
        default:
            break
        }
    }

    private func removePowerUp(_ type: PowerUpType) {
        switch type {
        case .wide, .shrink:
            paddle.resetWidth()
        case .slow, .fastball:
            for b in balls {
                b.setSpeed(getBaseBallSpeed())
            }
        case .sticky:
            paddle.isSticky = false
            launchBall()
        case .laser:
            paddle.hasLaser = false
        case .rocket:
            paddle.hasRockets = false
        case .fireball:
            for b in balls { b.isFireball = false }
        case .bomb:
            for b in balls { b.isBomb = false }
        case .pierce:
            for b in balls { b.isPierce = false }
        case .net:
            paddle.hasNet = false
        case .drone:
            paddle.hasDrone = false
        case .reverse:
            paddle.isReversed = false
        case .clumsy:
            paddle.isClumsy = false
        case .invis:
            paddle.isGhost = false
        default:
            break
        }
    }

    private func splitBalls() {
        guard let first = balls.first else { return }
        let spd = first.speed > 0 ? first.speed : getBaseBallSpeed()

        balls.append(
            Ball(
                x: first.x,
                y: first.y,
                vx: -spd * 0.7,
                vy: -spd * 0.7,
                isStuck: false
            )
        )
        balls.append(
            Ball(
                x: first.x,
                y: first.y,
                vx: spd * 0.7,
                vy: -spd * 0.7,
                isStuck: false
            )
        )
    }

    func triggerUlti() {
        guard stats.ultiCharge >= 100.0 && stats.ultiActiveLeft <= 0 else { return }
        stats.ultiCharge = 0.0
        stats.ultiActiveLeft = 2.0

        particles.triggerShake(magnitude: 7.0, duration: 0.35)
        particles.spawnShockwave(
            x: paddle.x + paddle.width / 2.0,
            y: paddle.y,
            color: Color(hex: 0xFF00E5FF),
            maxRadius: screenWidth
        )
        particles.spawnFloatingText(
            x: screenWidth / 2.0,
            y: screenHeight * 0.42,
            text: I18n.tr("power_mode"),
            color: Color(hex: 0xFF00E5FF),
            isLarge: true
        )
        audio.playSfx(.ulti)

        for i in 0..<8 {
            projectiles.append(
                Projectile(
                    x: paddle.x + (paddle.width * Double(i) / 7.0),
                    y: paddle.y - 12.0,
                    vy: -650.0,
                    radius: 6.0,
                    isLaser: true
                )
            )
        }
    }

    private func loseLife() {
        stats.lives -= 1
        audio.playSfx(.gameOver)

        if stats.lives <= 0 && currentMode != .zen {
            onGameOver()
        } else {
            resetPaddleAndBall()
            status = .ready
        }
    }

    private func onGameOver() {
        status = .gameOver
        save.updateHighScore(mode: currentMode, score: stats.score)
        audio.playSfx(.gameOver)
    }

    private func checkGameProgress() {
        if currentMode == .zen { return }


        let remainingBreakable = bricks.filter { $0.isAlive && !$0.isSteel }.count
        if remainingBreakable == 0 {
            if currentMode == .daily {
                onVictory()
            } else {
                stats.level += 1
                stats.score += 250 * stats.level
                particles.spawnFloatingText(
                    x: screenWidth / 2.0,
                    y: screenHeight * 0.4,
                    text: "\(I18n.tr("level").uppercased()) \(stats.level)!",
                    color: Color(hex: 0xFFFFD54F),
                    isLarge: true
                )
                audio.playSfx(.victory)
                resetPaddleAndBall()
                loadLevelBricks()
                status = .ready
            }
        }
    }

    private func onVictory() {
        status = .victory
        save.updateHighScore(mode: currentMode, score: stats.score)
        save.addGold(50)
        audio.playSfx(.victory)
    }

    func pause() {
        if status == .playing || status == .ready {
            statusBeforePause = status
            status = .paused
        }
    }

    func resume() {
        if status == .paused {
            status = statusBeforePause
        }
    }
}
