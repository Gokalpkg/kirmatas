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
    var blackHoles: [BlackHole] = []
    var portals: [Portal] = []

    var activeBee: EasterEggBee? = nil
    var activeSplat: WindshieldSplat? = nil
    var beeSpawnCooldown: Double = 25.0
    var bossWarningTimer: Double = 0.0
    var levelTransitionTimer: Double = 0.0
    var hasCelebratedNewRecord: Bool = false
    var sessionStartingBestScore: Int = 0
    var bossEnrageAnnounced: Bool = false

    var descendTimer: Double = 0.0
    var droneShootTimer: Double = 0.0
    var lightningTimer: Double = 0.0
    var comboTimer: Double = 0.0
    var gameTime: Double = 0.0
    var endgameStallTimer: Double = 0.0
    private var blackHoleTimer: Double = 0.0

    var chaosStock = 3
    var chaosPendingExtraBalls = 0
    var chaosToLaunch = 0
    var chaosReturned = 0
    var chaosShotTimer = 0.0
    var chaosTurnTime = 0.0
    var chaosShotVx = 0.0
    var chaosShotVy = 0.0
    var chaosHomeX = 180.0
    var chaosLaunchX = 180.0
    var chaosAimX = 180.0
    var chaosAimY = 240.0
    var chaosSpeedMultiplier = 1.0
    var chaosAiming = false
    var chaosHomeLocked = false
    var chaosRecallActive = false
    var hasUsedRevive = false
    var hasClaimedVictoryBonus = false
    var endGameRolledDice = 0
    var endGameMultiplier = 0
    var endGameBonusGoldAdded = 0

    var chaosFloorY: Double { screenHeight - 86 }

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
        blackHoles.removeAll()
        portals.removeAll()
        activeBee = nil
        activeSplat = nil
        bossWarningTimer = 0.0
        levelTransitionTimer = 0.0
        sessionStartingBestScore = save.highScores[mode.rawValue] ?? 0
        hasCelebratedNewRecord = false
        bossEnrageAnnounced = false
        beeSpawnCooldown = Double.random(in: 25.0...45.0)
        blackHoleTimer = 0
        endgameStallTimer = 0
        hasUsedRevive = false
        hasClaimedVictoryBonus = false
        endGameRolledDice = 0
        endGameMultiplier = 0
        endGameBonusGoldAdded = 0

        if mode == .chaos {
            chaosStock = 3
            chaosPendingExtraBalls = 0
            chaosHomeX = screenWidth / 2
            chaosAimX = chaosHomeX
            chaosAimY = screenHeight * 0.45
            chaosAiming = false
            chaosToLaunch = 0
            chaosReturned = 0
            chaosHomeLocked = false
            chaosSpeedMultiplier = 1
            chaosRecallActive = false
            save.clearChaosSession()
        }

        resetPaddleAndBall()
        loadLevelBricks()
        if mode == .classic {
            save.noteClassicLevel(1)
        }
        objectWillChange.send()
    }

    func resetPaddleAndBall() {
        applyFishPaddleWidth()
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
        if currentMode == .chaos {
            layoutChaosPile()
            return
        }
        balls.append(
            Ball(
                x: paddle.x + paddle.width / 2.0,
                y: paddle.y - 12.0,
                isStuck: true,
                stuckOffsetX: paddle.width / 2.0
            )
        )
    }

    private func applyFishPaddleWidth() {
        var bonus = 0.0
        if save.unlockedFish.contains("guppy") { bonus += 4.0 }
        if save.unlockedFish.contains("tetra") { bonus += 3.0 }
        paddle.width = paddle.baseWidth + bonus
    }

    func loadLevelBricks() {
        portals.removeAll()
        blackHoles.removeAll()
        activeBee = nil
        beeSpawnCooldown = Double.random(in: 25.0...45.0)
        blackHoleTimer = 0
        endgameStallTimer = 0
        switch currentMode {
        case .classic:
            bricks = LevelDesign.buildClassicLevel(level: stats.level, screenWidth: screenWidth, screenHeight: screenHeight)
            if stats.level % 5 == 0 {
                bossWarningTimer = 2.4
                bossEnrageAnnounced = false
                particles.triggerShake(magnitude: 5.0, duration: 0.35)
                audio.playSfx(.bossHit)
            }
            spawnPortalsIfNeeded()
        case .zen:
            bricks = LevelDesign.buildZenLevel(screenWidth: screenWidth, screenHeight: screenHeight)
        case .descend:
            bricks = LevelDesign.buildDescendInitial(screenWidth: screenWidth, screenHeight: screenHeight)
            descendTimer = 13.0
        case .daily:
            bricks = LevelDesign.buildDailyLevel(date: Date(), screenWidth: screenWidth, screenHeight: screenHeight)
        case .shapes:
            bricks = LevelDesign.buildShapesLevel(level: stats.level, screenWidth: screenWidth, screenHeight: screenHeight)
        case .chaos:
            bricks = LevelDesign.buildChaosLevel(wave: stats.level, screenWidth: screenWidth, screenHeight: screenHeight)
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
                let sign = Bool.random() ? 1.0 : -1.0
                let tilt = sign * (0.045 + Double.random(in: 0...0.035))
                ball.vx = speed * sin(tilt)
                ball.vy = -speed * cos(tilt)
                anyLaunched = true
            }
        }
        if anyLaunched {
            audio.playSfx(.hitPaddle)
            objectWillChange.send()
        }
    }

    func aimChaos(x: Double, y: Double) {
        guard currentMode == .chaos, status == .ready else { return }
        chaosAiming = true
        chaosAimX = min(max(x, 10), screenWidth - 10)
        chaosAimY = min(y, chaosFloorY - 18)
    }

    func fireChaos() {
        guard currentMode == .chaos, status == .ready, chaosStock > 0 else { return }
        var dx = chaosAimX - chaosHomeX
        var dy = chaosAimY - chaosFloorY
        if !chaosAiming || dy >= -10 {
            dx = 0
            dy = -1
        }
        let angle = min(max(atan2(dy, dx), -.pi + 0.16), -0.16)
        let speed = getBaseBallSpeed()
        chaosLaunchX = chaosHomeX
        chaosShotVx = cos(angle) * speed
        chaosShotVy = sin(angle) * speed
        chaosToLaunch = chaosStock
        chaosReturned = 0
        chaosHomeLocked = false
        chaosShotTimer = 0
        chaosTurnTime = 0
        chaosAiming = false
        chaosSpeedMultiplier = 1
        chaosRecallActive = false
        balls.removeAll()
        status = .playing
        audio.playSfx(.hitPaddle)
        objectWillChange.send()
    }

    func toggleChaosTurboOrRecall() {
        guard currentMode == .chaos, status == .playing, !chaosRecallActive else { return }
        if chaosSpeedMultiplier <= 1.05 {
            chaosSpeedMultiplier = 2.2
            particles.spawnFloatingText(
                x: screenWidth / 2, y: chaosFloorY - 55,
                text: I18n.tr("chaos_2x_speed"),
                color: Color(hex: 0xFFFFD700),
                isLarge: true
            )
            audio.playSfx(.ulti)
        } else {
            chaosRecallActive = true
            particles.spawnFloatingText(
                x: screenWidth / 2, y: chaosFloorY - 55,
                text: I18n.tr("chaos_recall"),
                color: Color(hex: 0xFF00E5FF),
                isLarge: true
            )
            audio.playSfx(.powerupBuff)
        }
    }

    private func layoutChaosPile() {
        balls.removeAll()
        let y = chaosFloorY - 8
        for i in 0..<chaosStock {
            balls.append(
                Ball(
                    x: chaosHomeX + Double((i % 3) - 1) * 3.2,
                    y: y - Double(i / 3) * 3.4,
                    radius: 5.2,
                    isStuck: true
                )
            )
        }
    }

    private func launchChaosVolley(dt: Double) {
        guard chaosToLaunch > 0 else { return }
        chaosShotTimer -= dt
        let interval = min(max(0.050 - Double(chaosStock) * 0.0005, 0.026), 0.050)
        while chaosShotTimer <= 0 && chaosToLaunch > 0 {
            balls.append(
                Ball(
                    x: chaosLaunchX,
                    y: chaosFloorY - 10,
                    vx: chaosShotVx,
                    vy: chaosShotVy,
                    radius: 5.2,
                    isStuck: false
                )
            )
            chaosToLaunch -= 1
            chaosShotTimer += interval
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
        if currentMode == .chaos {
            effectiveDt *= chaosSpeedMultiplier
            chaosTurnTime += effectiveDt
            launchChaosVolley(dt: effectiveDt)
        }

        particles.update(dt: effectiveDt)
        paddle.update(dt: effectiveDt)

        if bossWarningTimer > 0 {
            bossWarningTimer -= effectiveDt
            if bossWarningTimer < 0 { bossWarningTimer = 0 }
        }
        if levelTransitionTimer > 0 {
            levelTransitionTimer -= effectiveDt
            if levelTransitionTimer < 0 { levelTransitionTimer = 0 }
        }
        if let splat = activeSplat {
            splat.update(dt: effectiveDt)
            if splat.isDead { activeSplat = nil }
        }
        updateEasterEgg(dt: effectiveDt)

        updatePowerUpTimers(dt: effectiveDt)
        updateCombo(dt: effectiveDt)
        updateProjectiles(dt: effectiveDt)
        updateCapsules(dt: effectiveDt)
        updateBricks(dt: effectiveDt)
        updateAnomalies(dt: effectiveDt)
        endgameStallTimer += effectiveDt
        updateBalls(dt: effectiveDt)
        checkGameProgress()

        frameTick &+= 1
    }

    // MARK: - Easter Egg & Live Celebrations
    func spawnEasterEggBee(customY: Double? = nil, facingRight: Bool? = nil) {
        let right = facingRight ?? Bool.random()
        let startX = right ? -35.0 : screenWidth + 35.0
        let speed = Double.random(in: 48.0...64.0)
        let vx = right ? speed : -speed
        var laneY = customY ?? (screenHeight * 0.48 + Double.random(in: -60.0...60.0))
        laneY = min(max(laneY, 180.0), paddle.y - 70.0)

        activeBee = EasterEggBee(
            x: startX,
            baseY: laneY,
            vx: vx,
            isFacingRight: right
        )
    }

    private func updateEasterEgg(dt: Double) {
        if currentMode == .chaos { return }
        if activeBee == nil {
            beeSpawnCooldown -= dt
            if beeSpawnCooldown <= 0 {
                spawnEasterEggBee()
                beeSpawnCooldown = Double.random(in: 35.0...65.0)
            }
        } else if let bee = activeBee {
            bee.update(dt: dt)
            if bee.isOffScreen(screenWidth: screenWidth) {
                activeBee = nil
            }
        }
    }

    func triggerBeeSplat(at splatPoint: CGPoint) {
        activeBee?.isAlive = false
        activeBee = nil
        activeSplat = WindshieldSplat(x: splatPoint.x, y: splatPoint.y, duration: 2.2)
        stats.score += 100
        particles.spawnBurst(x: splatPoint.x, y: splatPoint.y, color: Color(hex: 0xFFD31018), count: 24, speed: 110.0)
        particles.spawnFloatingText(
            x: splatPoint.x,
            y: splatPoint.y - 18.0,
            text: I18n.tr("bee_splat"),
            color: Color(hex: 0xFFFF1744),
            isLarge: true
        )
        particles.triggerShake(magnitude: 2.5, duration: 0.15)
        audio.playSfx(.breakBrick)
        checkLiveNewRecordCelebration()
    }

    @discardableResult
    func handleCanvasTap(at point: CGPoint) -> Bool {
        if let bee = activeBee, bee.isAlive, bee.containsPoint(point) {
            triggerBeeSplat(at: CGPoint(x: bee.x, y: bee.y))
            return true
        }
        return false
    }

    func checkLiveNewRecordCelebration() {
        if !hasCelebratedNewRecord && sessionStartingBestScore > 0 && stats.score > sessionStartingBestScore {
            hasCelebratedNewRecord = true
            particles.spawnShockwave(x: screenWidth / 2.0, y: screenHeight * 0.32, color: Color(hex: 0xFFFFD700), maxRadius: 110.0)
            particles.spawnBurst(x: screenWidth / 2.0, y: screenHeight * 0.32, color: Color(hex: 0xFFFFD54F), count: 35, speed: 210.0)
            particles.spawnFloatingText(
                x: screenWidth / 2.0,
                y: screenHeight * 0.32,
                text: I18n.tr("new_record_broken"),
                color: Color(hex: 0xFFFFD700),
                isLarge: true
            )
            audio.playSfx(.victory)
        }
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
                if currentMode == .chaos { continue }
                if status == .playing {
                    ball.stuckTimer += dt
                    if ball.stuckTimer >= 1.6 || !paddle.isSticky {
                        launchBall()
                    }
                }
                continue
            }

            if abs(ball.vy) < 28.0 {
                ball.vy = ball.vy >= 0 ? 35.0 : -35.0
            }
            if ball.vx != 0 && abs(ball.vx) < 8.0 {
                ball.vx = ball.vx >= 0 ? 8.0 : -8.0
            }

            applyBlackHoleGravity(ball: ball, dt: dt)
            applyPortalTeleport(ball: ball)
            ball.update(dt: dt)

            // Easter Egg Bee collision
            if let bee = activeBee, bee.isAlive {
                let bdx = ball.x - bee.x
                let bdy = ball.y - bee.y
                let distSq = bdx * bdx + bdy * bdy
                let hitDist = ball.radius + bee.hitRadius
                if distSq <= hitDist * hitDist {
                    triggerBeeSplat(at: CGPoint(x: bee.x, y: bee.y))
                }
            }

            if currentMode == .chaos {
                if chaosRecallActive {
                    ball.vx *= 0.88
                    ball.vy = max(ball.vy, 760)
                } else {
                    if abs(ball.vy) < 80 { ball.vy = ball.vy >= 0 ? 100 : -100 }
                    if chaosTurnTime >= 26 { ball.vy = abs(ball.vy) + 260 }
                }
            }

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

            // Bottom fall / chaos return
            if currentMode == .chaos {
                if ball.y > chaosFloorY {
                    if !chaosHomeLocked {
                        chaosHomeX = min(max(ball.x, 20), screenWidth - 20)
                        chaosHomeLocked = true
                    }
                    balls.remove(at: i)
                    chaosReturned += 1
                    particles.spawnBurst(x: ball.x, y: chaosFloorY, color: Color(hex: 0xFF00E5FF), count: 2, speed: 40)
                    continue
                }
            } else if ball.y - ball.radius > screenHeight {
                balls.remove(at: i)
                continue
            }

            // Paddle collision
            if currentMode != .chaos && !paddle.isGhost && checkBallPaddleCollision(ball) {
                continue
            }

            // Brick collision
            checkBallBrickCollision(ball)
        }

        if currentMode == .chaos {
            let volleyDone = status == .playing && chaosToLaunch == 0 && chaosReturned > 0
            if volleyDone && (balls.isEmpty || chaosTurnTime > 28) {
                balls.removeAll()
                chaosAdvanceTurn()
            }
            return
        }

        if balls.isEmpty {
            loseLife()
        }
    }

    private func checkBallPaddleCollision(_ ball: Ball) -> Bool {
        let pr = paddle.rect
        // Prevent tunnelling by expanding the hitbox based on the ball's speed per frame
        let vyPadding = max(ball.vy * 0.025, 0.0) 
        let vxPadding = max(abs(ball.vx) * 0.025, 5.0)
        
        guard ball.vy > 0,
              ball.y + ball.radius >= pr.minY - vyPadding,
              ball.y - ball.radius <= pr.maxY,
              ball.x + ball.radius >= pr.minX - vxPadding,
              ball.x - ball.radius <= pr.maxX + vxPadding else {
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
        let bounceAngle = hitOffset * (.pi / 2.8)
        let baseSpeed = min(ball.speed + 4.0, 580.0)

        let isCornerHit = abs(hitOffset) >= 0.78
        let speedMultiplier = isCornerHit ? 1.35 : 1.0
        let finalSpeed = min(max(baseSpeed * speedMultiplier, 100.0), 680.0)

        let paddleV = max(min(paddle.velocityX * 0.20, 200.0), -200.0)
        var vx = sin(bounceAngle) * finalSpeed + paddleV
        var vy = -max(abs(cos(bounceAngle) * finalSpeed), 150.0)

        let remaining = bricks.filter { $0.isAlive && !$0.isSteel }
        if !remaining.isEmpty && remaining.count <= 2 && endgameStallTimer >= 10.0 {
            let target = remaining[0]
            let dx = (target.x + target.width / 2.0) - ball.x
            let dy = (target.y + target.height / 2.0) - pr.minY
            let desired = atan2(dx, -dy)
            let clamped = min(max(desired, -.pi / 2.8), .pi / 2.8)
            let blended = bounceAngle * 0.88 + clamped * 0.12
            vx = sin(blended) * finalSpeed + paddleV
            vy = -max(abs(cos(blended) * finalSpeed), 150.0)
        }

        ball.vx = vx
        ball.vy = vy

        ball.y = pr.minY - ball.radius - 1.0
        ball.triggerSquash(-.pi / 2.0)
        ball.fireballCombo = 0

        if ball.isFireball || ball.isPierce {
            ball.fireballPaddleBounces += 1
            if ball.fireballPaddleBounces >= 3 {
                extinguishPiercing(at: ball.x, y: pr.minY)
            }
        }

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
                if b.isBallPickup {
                    b.isAlive = false
                    chaosPendingExtraBalls += 1
                    let cx = b.x + b.width / 2
                    let cy = b.y + b.height / 2
                    particles.spawnBurst(x: cx, y: cy, color: Color(hex: 0xFF00E5FF), count: 18, speed: 110)
                    particles.spawnShockwave(x: cx, y: cy, color: Color(hex: 0xFF00E5FF), maxRadius: 36)
                    particles.spawnFloatingText(x: cx, y: b.y - 12, text: I18n.tr("plus_one_ball"), color: Color(hex: 0xFF00E5FF), isLarge: true)
                    audio.playSfx(.powerupBuff)
                    continue
                }

                hitBrick(b, ball: ball)

                if ball.isFireball || ball.isPierce {
                    ball.fireballPierceCount -= 1
                    if ball.fireballPierceCount <= 0 {
                        extinguishPiercing(at: ball.x, y: ball.y)
                    }
                }

                if !ball.isFireball && !ball.isPierce {
                    let bcx = b.x + b.width / 2.0
                    let bcy = b.y + b.height / 2.0
                    let dx = bx - bcx
                    let dy = by - bcy
                    let overlapX = (b.width / 2.0 + r) - abs(dx)
                    let overlapY = (b.height / 2.0 + r) - abs(dy)

                    if overlapX < overlapY {
                        let nx = dx > 0 ? 1.0 : -1.0
                        ball.vx = nx * abs(ball.vx)
                        ball.x = dx > 0 ? b.x + b.width + r : b.x - r
                        ball.triggerSquash(dx > 0 ? 0 : .pi)
                        nudgeOutOfPinch(ball: ball, nx: nx, ny: 0)
                    } else {
                        let ny = dy > 0 ? 1.0 : -1.0
                        ball.vy = ny * abs(ball.vy)
                        ball.y = dy > 0 ? b.y + b.height + r : b.y - r
                        ball.triggerSquash(dy > 0 ? .pi / 2.0 : -.pi / 2.0)
                        nudgeOutOfPinch(ball: ball, nx: 0, ny: ny)
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
                ball.fireballCombo += 1
                destroyBrick(b)
            } else {
                b.jelly = 1.0
                particles.spawnBurst(x: b.x + b.width / 2.0, y: b.y + b.height / 2.0, color: .gray, count: 6)
                audio.playSfx(.steel)
            }
            return
        }

        b.hp -= 1
        if let ball = ball, ball.isFireball {
            ball.fireballCombo += 1
        }

        if b.isBoss {
            audio.playSfx(.bossHit)
            let hpRatio = Double(b.hp) / Double(max(b.maxHp, 1))
            if hpRatio <= 0.5 && !bossEnrageAnnounced {
                bossEnrageAnnounced = true
                particles.spawnFloatingText(
                    x: screenWidth / 2.0,
                    y: screenHeight * 0.35,
                    text: I18n.tr("boss_enraged"),
                    color: Color(hex: 0xFFFF1744),
                    isLarge: true
                )
                particles.triggerShake(magnitude: 4.5, duration: 0.25)
            }
        }

        b.jelly = 0.8
        endgameStallTimer = 0

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

        if b.isBoss {
            particles.spawnFloatingText(
                x: cx,
                y: cy - 20.0,
                text: I18n.tr("boss_defeated"),
                color: Color(hex: 0xFFFFD700),
                isLarge: true
            )
            particles.spawnBurst(x: cx, y: cy, color: Color(hex: 0xFFFFD700), count: 32, speed: 190.0)
            audio.playSfx(.victory)
        }

        registerCombo(basePoints: b.points)
        checkLiveNewRecordCelebration()

        stats.ultiCharge = min(max(stats.ultiCharge + 4.0, 0.0), 100.0)

        rollCapsuleDrop(x: cx, y: cy)

        if Double.random(in: 0...1) < 0.20 {
            let coins = Int.random(in: 1...3)
            stats.goldCollected += coins
            save.addGold(coins)
            particles.spawnFloatingText(x: cx, y: b.y, text: "+\(coins) G", color: Color(hex: 0xFFFFD54F))
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

        if stats.combo == 3 {
            particles.spawnFloatingText(
                x: paddle.x + paddle.width / 2.0,
                y: paddle.y - 28.0,
                text: "TRIPLE HIT x3!",
                color: Color(hex: 0xFF00E5FF),
                isLarge: true
            )
            particles.triggerShake(magnitude: 2.0, duration: 0.12)
        } else if stats.combo == 5 {
            particles.spawnFloatingText(
                x: paddle.x + paddle.width / 2.0,
                y: paddle.y - 32.0,
                text: "MEGA COMBO x5!",
                color: Color(hex: 0xFFFF9100),
                isLarge: true
            )
            particles.triggerShake(magnitude: 3.5, duration: 0.18)
        } else if stats.combo >= 8 && stats.combo % 4 == 0 {
            particles.spawnFloatingText(
                x: paddle.x + paddle.width / 2.0,
                y: paddle.y - 36.0,
                text: "ULTRA COMBO x\(stats.combo)!",
                color: Color(hex: 0xFFD500F9),
                isLarge: true
            )
            particles.triggerShake(magnitude: 5.0, duration: 0.22)
        } else if stats.combo > 1 && stats.combo % 3 == 0 {
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
            let buffs = allTypes.filter {
                $0.kind == .buff && $0 != .mirror && $0 != .multi && $0 != .pierce && $0 != .drone
            }
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
        case .fireball, .pierce:
            for b in balls {
                b.isFireball = true
                b.isPierce = true
                b.fireballPierceCount = 12
                b.fireballPaddleBounces = 0
            }
        case .bomb:
            for b in balls { b.isBomb = true }
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
            applyFishPaddleWidth()
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
        case .fireball, .pierce:
            if !activePowerUps.contains(where: { $0.type == .fireball || $0.type == .pierce }) {
                for b in balls {
                    b.isFireball = false
                    b.isPierce = false
                }
            }
        case .bomb:
            for b in balls { b.isBomb = false }
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
        if currentMode == .zen || currentMode == .chaos { return }


        let remainingBreakable = bricks.filter { $0.isAlive && !$0.isSteel }.count
        if remainingBreakable == 0 {
            if currentMode == .daily {
                onVictory()
            } else {
                levelTransitionTimer = 1.0
                stats.level += 1
                save.noteClassicLevel(stats.level)
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

    private func chaosAdvanceTurn() {
        chaosSpeedMultiplier = 1
        chaosRecallActive = false
        let remainingSolid = bricks.contains { $0.isAlive && !$0.isBallPickup }
        if !remainingSolid {
            let baseGold = 25 + min(stats.level * 5, 50)
            stats.goldCollected += baseGold
            save.addGold(baseGold)
            stats.level += 1
            stats.score += 300 * stats.level
            chaosStock = 3
            chaosPendingExtraBalls = 0
            chaosReturned = 0
            chaosToLaunch = 0
            chaosHomeLocked = false
            save.saveChaosSession(level: stats.level, score: stats.score, stock: chaosStock)
            loadLevelBricks()
            status = .ready
            layoutChaosPile()
            particles.spawnFloatingText(
                x: screenWidth / 2, y: screenHeight * 0.4,
                text: "\(I18n.tr("level").uppercased()) \(stats.level)!",
                color: Color(hex: 0xFFFFD700), isLarge: true
            )
            audio.playSfx(.victory)
            return
        }

        chaosStock += chaosPendingExtraBalls
        chaosPendingExtraBalls = 0
        let step = LevelDesign.chaosStep
        for brick in bricks where brick.isAlive {
            brick.y += step
            brick.targetY = brick.y
            if !brick.isBallPickup && brick.y + brick.height >= chaosFloorY - 36 {
                onGameOver()
                return
            }
        }
        bricks.removeAll { !$0.isAlive }
        bricks.removeAll { $0.isBallPickup && $0.y + $0.height >= chaosFloorY - 20 }
        bricks.append(contentsOf: LevelDesign.buildChaosRow(wave: stats.level, row: 0, screenWidth: screenWidth))
        save.saveChaosSession(level: stats.level, score: stats.score, stock: chaosStock)
        chaosReturned = 0
        chaosToLaunch = 0
        chaosHomeLocked = false
        status = .ready
        layoutChaosPile()
        audio.playSfx(.hitPaddle)
    }

    func reviveWithOneLife() {
        guard !hasUsedRevive else { return }
        hasUsedRevive = true
        stats.lives = 1
        resetPaddleAndBall()
        status = .ready
        audio.playSfx(.powerupBuff)
        particles.spawnFloatingText(
            x: screenWidth / 2, y: screenHeight * 0.45,
            text: I18n.tr("second_chance"),
            color: Color(hex: 0xFFFF1744), isLarge: true
        )
    }

    func rollEndGameGoldDice() {
        guard !hasClaimedVictoryBonus else { return }
        hasClaimedVictoryBonus = true
        let baseGold = max(stats.goldCollected, 100)
        let rolled = Int.random(in: 1...6)
        endGameRolledDice = rolled
        endGameMultiplier = rolled >= 4 ? 3 : 2
        let bonus = baseGold * (endGameMultiplier - 1)
        endGameBonusGoldAdded = bonus
        save.addGold(bonus)
        stats.goldCollected += bonus
        audio.playSfx(endGameMultiplier == 3 ? .ulti : .powerupBuff)
        particles.spawnFloatingText(
            x: screenWidth / 2, y: screenHeight * 0.45,
            text: "ZAR \(rolled) >> \(endGameMultiplier)X (+\(bonus) G)",
            color: Color(hex: 0xFFFFD54F), isLarge: true
        )
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

    private func spawnPortalsIfNeeded() {
        guard PortalCatalog.levels.contains(stats.level) else { return }
        var rng = SeededRNG(seed: UInt64(max(stats.level, 1) * 1337))
        var lowest: Double = 120
        for b in bricks where (b.y + b.height) > lowest {
            lowest = b.y + b.height
        }
        let minY = min(max(lowest + 45.0, 160.0), max(160.0, paddle.y - 140.0))
        let maxY = min(max(paddle.y - 80.0, minY + 20.0), max(minY + 20.0, paddle.y - 40.0))
        let rangeY = max(20.0, maxY - minY)
        let p1 = Portal(
            x: screenWidth * (0.20 + rng.nextDouble() * 0.14),
            y: minY + rng.nextDouble() * rangeY * 0.45,
            radius: 20,
            color: Color(hex: 0xFF00E5FF),
            isBlue: true
        )
        let p2 = Portal(
            x: screenWidth * (0.66 + rng.nextDouble() * 0.14),
            y: minY + rangeY * 0.55 + rng.nextDouble() * rangeY * 0.45,
            radius: 20,
            color: Color(hex: 0xFFFF9100),
            isBlue: false
        )
        p1.linkedPortal = p2
        p2.linkedPortal = p1
        portals = [p1, p2]
    }

    private func updateAnomalies(dt: Double) {
        for portal in portals {
            portal.update(dt: dt)
        }
        var index = blackHoles.count - 1
        while index >= 0 {
            let hole = blackHoles[index]
            hole.update(dt: dt)
            if hole.timeLeft <= 0 {
                particles.spawnBurst(x: hole.x, y: hole.y, color: Color(hex: 0xFFB388FF), count: 20, speed: 120)
                blackHoles.remove(at: index)
            }
            index -= 1
        }

        guard status == .playing, blackHoles.isEmpty, currentMode != .zen, currentMode != .chaos else { return }
        blackHoleTimer += dt
        guard blackHoleTimer >= 8.0, Double.random(in: 0...1) < 0.12 else { return }

        var lowestAlive: Double = 0
        for brick in bricks where brick.isAlive && !brick.isSteel {
            lowestAlive = max(lowestAlive, brick.y + brick.height)
        }
        let minY = lowestAlive + 45.0
        let maxY = paddle.y - 170.0
        blackHoleTimer = 0
        let radius = 13.0 + Double.random(in: 0...1) * 4.0
        let roll = Double.random(in: 0...1)
        let isVortexTrap = roll < 0.02
        let isSupercharged = !isVortexTrap && roll < 0.30
        let spawnY: Double
        if maxY > minY + 20.0 {
            spawnY = minY + Double.random(in: 0...1) * (maxY - minY)
        } else {
            let lo = min(160.0, paddle.y - 170.0)
            let hi = max(160.0, paddle.y - 170.0)
            spawnY = min(max(paddle.y - 200.0, lo), hi)
        }
        let spawnX = min(max(screenWidth * 0.22 + Double.random(in: 0...1) * (screenWidth * 0.56), radius + 20.0), screenWidth - radius - 20.0)
        let hole = BlackHole(
            x: spawnX,
            y: spawnY,
            radius: radius,
            mass: radius * 8000.0,
            timeLeft: isVortexTrap ? 7.5 : (isSupercharged ? 6.5 : (5.5 + Double.random(in: 0...1) * 2.0)),
            isVortexTrap: isVortexTrap,
            isSupercharged: isSupercharged
        )
        blackHoles.append(hole)
        audio.playSfx(.laser)
        if isVortexTrap {
            particles.spawnFloatingText(
                x: screenWidth * 0.5,
                y: spawnY,
                text: I18n.tr("vortex_black_hole"),
                color: Color(hex: 0xFFFF1744),
                isLarge: true
            )
            particles.spawnShockwave(x: spawnX, y: spawnY, color: Color(hex: 0xFFFF1744), maxRadius: 80)
        } else if isSupercharged {
            particles.spawnShockwave(x: spawnX, y: spawnY, color: Color(hex: 0xFFFF9100), maxRadius: 70)
        } else {
            particles.spawnShockwave(x: spawnX, y: spawnY, color: Color(hex: 0xFF7C4DFF), maxRadius: 60)
        }
    }

    private func applyBlackHoleGravity(ball: Ball, dt: Double) {
        let key = ObjectIdentifier(ball)
        for hole in blackHoles {
            let dx = hole.x - ball.x
            let dy = hole.y - ball.y
            let dist = sqrt(dx * dx + dy * dy)
            let maxDist = hole.maxInfluenceDist
            if dist > 1.0 && dist < maxDist {
                let currentAngle = atan2(ball.y - hole.y, ball.x - hole.x)
                if let prev = hole.ballAngles[key] {
                    var delta = currentAngle - prev
                    while delta > .pi { delta -= 2 * .pi }
                    while delta < -.pi { delta += 2 * .pi }
                    let accumulated = (hole.ballAccumulatedAngles[key] ?? 0) + abs(delta)
                    hole.ballAccumulatedAngles[key] = accumulated
                    let laps = Int(accumulated / (2 * .pi))
                    let recorded = hole.ballOrbitLaps[key] ?? 0
                    if laps > recorded {
                        hole.ballOrbitLaps[key] = laps
                        if hole.isSupercharged || hole.isVortexTrap {
                            ball.setSpeed(min(max(ball.speed * 1.30, getBaseBallSpeed()), 760))
                            particles.spawnBurst(x: ball.x, y: ball.y, color: Color(hex: 0xFFFF9100), count: 8, speed: 130)
                            audio.playSfx(.laser)
                        } else {
                            ball.setSpeed(min(max(ball.speed * 1.15, getBaseBallSpeed()), 660))
                            particles.spawnBurst(x: ball.x, y: ball.y, color: Color(hex: 0xFFE040FB), count: 5, speed: 80)
                        }
                    }
                }
                hole.ballAngles[key] = currentAngle

                let proximity = 1.0 - min(max(dist / maxDist, 0), 1)
                let falloff = pow(proximity, 0.65)
                let sizeMult = min(max(hole.radius / 20.0, 1.0), 2.0)
                let basePull = (hole.isVortexTrap ? 5400.0 : (hole.isSupercharged ? 4400.0 : 3400.0)) * sizeMult
                let pull = basePull * falloff
                let nx = dx / dist
                let ny = dy / dist
                ball.vx += nx * pull * dt
                ball.vy += ny * pull * dt

                let tangentX = -ny
                let tangentY = nx
                let dragDirection = (ball.vx * tangentX + ball.vy * tangentY) >= 0 ? 1.0 : -1.0
                let spinDrag = (hole.isVortexTrap ? 1400.0 : (hole.isSupercharged ? 1100.0 : 850.0)) * falloff
                ball.vx += tangentX * spinDrag * dragDirection * dt
                ball.vy += tangentY * spinDrag * dragDirection * dt

                if proximity > 0.45 || dist < hole.radius * 3.5 {
                    ball.vx += tangentX * 280.0 * dragDirection * dt
                    ball.vy += tangentY * 280.0 * dragDirection * dt
                    if Double.random(in: 0...1) < 0.25 {
                        let spark = hole.isSupercharged ? Color(hex: 0xFF00E5FF) : Color(hex: 0xFFE040FB)
                        particles.spawnBurst(x: ball.x, y: ball.y, color: spark, count: 1, speed: 70)
                    }
                }

                if dist <= hole.radius * 0.48 + ball.radius {
                    let exitSpeed = min(max(max(ball.speed * 1.15, getBaseBallSpeed() * 1.25), getBaseBallSpeed()), 820)
                    ball.vx = tangentX * exitSpeed * dragDirection
                    ball.vy = tangentY * exitSpeed * dragDirection
                    particles.spawnBurst(x: ball.x, y: ball.y, color: Color(hex: 0xFFFFD54F), count: 12, speed: 160)
                    particles.spawnShockwave(x: hole.x, y: hole.y, color: Color(hex: 0xFFE040FB), maxRadius: 45)
                    audio.playSfx(.cornerBoost)
                }

                if ball.speed < getBaseBallSpeed() {
                    ball.setSpeed(getBaseBallSpeed())
                }
                let maxAllowed = (hole.isSupercharged || hole.isVortexTrap) ? 800.0 : 700.0
                if ball.speed > maxAllowed {
                    ball.setSpeed(maxAllowed)
                }
            } else {
                if (hole.isSupercharged || hole.isVortexTrap),
                   (hole.ballAccumulatedAngles[key] ?? 0) >= .pi * 0.65 {
                    ball.setSpeed(min(max(ball.speed * 1.18, getBaseBallSpeed()), 760))
                    particles.spawnBurst(x: ball.x, y: ball.y, color: Color(hex: 0xFFFFD54F), count: 8, speed: 140)
                    audio.playSfx(.hitPaddle)
                }
                hole.ballAngles.removeValue(forKey: key)
                hole.ballAccumulatedAngles.removeValue(forKey: key)
                hole.ballOrbitLaps.removeValue(forKey: key)
            }
        }
    }

    private func applyPortalTeleport(ball: Ball) {
        guard ball.anomalyCooldown <= 0 else { return }
        for portal in portals {
            let dx = portal.x - ball.x
            let dy = portal.y - ball.y
            guard dx * dx + dy * dy <= portal.radius * portal.radius, let target = portal.linkedPortal else { continue }
            let currentSpeed = ball.speed > 0 ? ball.speed : getBaseBallSpeed()
            var dirX = ball.vx / currentSpeed
            var dirY = ball.vy / currentSpeed
            if abs(dirX) < 0.1 && abs(dirY) < 0.1 {
                dirX = 0
                dirY = -1
            }
            let eject = target.radius + ball.radius + 6.0
            ball.x = min(max(target.x + dirX * eject, ball.radius + 8.0), screenWidth - ball.radius - 8.0)
            ball.y = min(max(target.y + dirY * eject, 42.0), screenHeight - 60.0)
            ball.setSpeed(min(max(currentSpeed, getBaseBallSpeed()), 850))
            ball.anomalyCooldown = 0.55
            particles.spawnBurst(x: portal.x, y: portal.y, color: portal.color, count: 22, speed: 120)
            particles.spawnShockwave(x: portal.x, y: portal.y, color: portal.color, maxRadius: 38)
            particles.spawnBurst(x: target.x, y: target.y, color: target.color, count: 26, speed: 140)
            particles.spawnShockwave(x: target.x, y: target.y, color: target.color, maxRadius: 44)
            audio.playSfx(.ulti)
            break
        }
    }

    private func extinguishPiercing(at x: Double, y: Double) {
        for b in balls {
            b.isFireball = false
            b.isPierce = false
            b.fireballPierceCount = 0
            b.fireballPaddleBounces = 0
        }
        let hadPierce = activePowerUps.contains { $0.type == .fireball || $0.type == .pierce }
        activePowerUps.removeAll { $0.type == .fireball || $0.type == .pierce }
        if hadPierce {
            particles.spawnBurst(x: x, y: y, color: Color(hex: 0xFFFF9100), count: 12, speed: 90)
        }
    }

    private func nudgeOutOfPinch(ball: Ball, nx: Double, ny: Double) {
        ball.rapidBounceCount += 1
        ball.rapidBounceTimer = 0.15
        if ball.rapidBounceCount >= 5 {
            ball.x += nx * 2.5
            ball.y += (ny != 0 ? ny : 1.0) * 2.5
            ball.rapidBounceCount = 0
        }
    }
}
