import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - GameSfx Enumeration
enum GameSfx: String, CaseIterable {
    // In-Game Physics & Combat
    case hitPaddle
    case hitWall
    case hitBrick
    case breakBrick
    case steel
    case powerupBuff
    case powerupDebuff
    case laser
    case explosion
    case ulti
    case gameOver
    case victory
    case cornerBoost   // M5: Outer 22% paddle hit boost
    case bossHit       // Boss impact and warning cues

    // UI & Navigation
    case click
    case uiChime       // General modal / positive feedback
    case cardFlip      // M3: Crate opening card flip
    case cosmeticEquip // M3: Cosmetic equip chime

    // Eco-Tank Aquarium (M2)
    case bubble        // Ambient bubble
    case bubblePop     // Interactive bubble tap
    case fishEat       // Fish eats food pellet

    // Rewards & Progression (M3/M4)
    case chestOpen     // Crate opening fanfare
    case crateReward   // Rare jackpot drop
    case dailyStreak   // 7-day streak calendar claim
    case questClaim    // Daily quest completion claim

    var audioFileName: String {
        switch self {
        case .hitPaddle: return "crystal_tap"
        case .hitWall: return "chip1"
        case .hitBrick: return "chip2"
        case .breakBrick: return "glass_shatter"
        case .steel: return "crystal_block"
        case .powerupBuff: return "glass_glow"
        case .powerupDebuff: return "y2k_digital1"
        case .laser: return "glass_neon1"
        case .explosion: return "digital_explo1"
        case .ulti: return "digital_explo2"
        case .gameOver: return "cam_kirilma"
        case .victory: return "glass_glow"
        case .cornerBoost: return "custom_bounce"
        case .bossHit: return "custom_explosion"

        case .click: return "ui1"
        case .uiChime: return "ui3"
        case .cardFlip: return "ui_fx1"
        case .cosmeticEquip: return "ui_c1"

        case .bubble: return "bubble2"
        case .bubblePop: return "pop3"
        case .fishEat: return "pop2"

        case .chestOpen: return "ui_b3"
        case .crateReward: return "ui_b4"
        case .dailyStreak: return "ui_fx4"
        case .questClaim: return "ui_b1"
        }
    }

    /// Adaptive throttling duration per SFX category to avoid acoustic clipping
    var throttleInterval: Double {
        switch self {
        case .hitPaddle, .hitWall, .hitBrick, .breakBrick, .laser, .cornerBoost, .bossHit:
            return 0.04 // 40ms rate limit for rapid in-game physics
        case .bubblePop, .fishEat:
            return 0.05 // 50ms rate limit for aquarium interactions
        case .click, .uiChime, .cardFlip, .cosmeticEquip:
            return 0.06 // 60ms debounce for UI interactions
        case .chestOpen, .crateReward, .dailyStreak, .questClaim, .victory, .gameOver:
            return 0.25 // 250ms debounce for celebratory modal fanfares
        default:
            return 0.04
        }
    }
}

// MARK: - Audio Manager
final class AudioManager {
    static let shared = AudioManager()

    private var players: [String: [AVAudioPlayer]] = [:]
    private var lastPlayedTimes: [GameSfx: Double] = [:]
    private var bgmPlayer: AVAudioPlayer?

    private var lightHaptic: UIImpactFeedbackGenerator?
    private var mediumHaptic: UIImpactFeedbackGenerator?
    private var heavyHaptic: UIImpactFeedbackGenerator?
    private var rigidHaptic: UIImpactFeedbackGenerator?

    private init() {
        configureAudioSession()
        #if canImport(UIKit)
        lightHaptic = UIImpactFeedbackGenerator(style: .light)
        mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
        heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
        rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)
        #endif
    }

    private func configureAudioSession() {
        #if canImport(UIKit)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Ignore audio session error on simulator
        }
        #endif
    }

    // MARK: - SFX Playback
    func playSfx(_ sfx: GameSfx) {
        let now = CACurrentMediaTime()
        let interval = sfx.throttleInterval
        if let last = lastPlayedTimes[sfx], now - last < interval {
            return // Throttled
        }
        lastPlayedTimes[sfx] = now

        triggerHapticForSfx(sfx)

        guard SaveManager.shared.sfxEnabled else { return }
        let fileName = sfx.audioFileName

        // Check existing pool
        if var pool = players[fileName] {
            if let available = pool.first(where: { !$0.isPlaying }) {
                available.currentTime = 0
                available.play()
                return
            } else if pool.count < 6 {
                if let player = createPlayer(for: fileName) {
                    player.play()
                    pool.append(player)
                    players[fileName] = pool
                }
                return
            } else {
                // Reuse oldest player in pool
                let oldest = pool.max(by: { $0.currentTime < $1.currentTime }) ?? pool[0]
                oldest.currentTime = 0
                oldest.play()
                return
            }
        } else {
            if let player = createPlayer(for: fileName) {
                player.play()
                players[fileName] = [player]
            }
        }
    }

    private func createPlayer(for fileName: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3")
                     ?? Bundle.main.url(forResource: fileName, withExtension: "wav") else {
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.55
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }

    // MARK: - Background Music (BGM)
    func playBgm(volume: Float = 0.4, loop: Bool = true) {
        guard SaveManager.shared.sfxEnabled else { return }
        if bgmPlayer == nil {
            guard let url = Bundle.main.url(forResource: "bgm", withExtension: "wav")
                         ?? Bundle.main.url(forResource: "bgm", withExtension: "mp3") else { return }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = loop ? -1 : 0
                player.volume = volume
                player.prepareToPlay()
                bgmPlayer = player
            } catch {
                return
            }
        }
        if bgmPlayer?.isPlaying == false {
            bgmPlayer?.play()
        }
    }

    func stopBgm() {
        bgmPlayer?.stop()
        bgmPlayer?.currentTime = 0
    }

    func pauseBgm() {
        bgmPlayer?.pause()
    }

    func resumeBgm() {
        guard SaveManager.shared.sfxEnabled else { return }
        bgmPlayer?.play()
    }

    // MARK: - Haptic Feedback
    private func triggerHapticForSfx(_ sfx: GameSfx) {
        let intensity = SaveManager.shared.hapticIntensity
        guard intensity != .off else { return }

        #if canImport(UIKit)
        switch sfx {
        case .hitPaddle, .hitWall, .hitBrick:
            if intensity == .light { lightHaptic?.impactOccurred() }
            else if intensity == .medium { mediumHaptic?.impactOccurred() }
            else { heavyHaptic?.impactOccurred() }

        case .breakBrick, .steel, .powerupBuff, .powerupDebuff, .laser, .cornerBoost, .bossHit:
            if intensity == .light { lightHaptic?.impactOccurred() }
            else if intensity == .medium { mediumHaptic?.impactOccurred() }
            else { rigidHaptic?.impactOccurred() }

        case .explosion, .ulti, .gameOver, .victory, .chestOpen, .crateReward, .dailyStreak:
            if intensity == .strong {
                let type: UINotificationFeedbackGenerator.FeedbackType =
                    (sfx == .victory || sfx == .dailyStreak || sfx == .chestOpen || sfx == .crateReward) ? .success : .warning
                UINotificationFeedbackGenerator().notificationOccurred(type)
            } else {
                heavyHaptic?.impactOccurred()
            }

        case .click, .uiChime, .cardFlip, .cosmeticEquip, .questClaim:
            UISelectionFeedbackGenerator().selectionChanged()

        case .bubble, .bubblePop, .fishEat:
            lightHaptic?.impactOccurred()
        }
        #endif
    }

    func triggerTestHaptic(_ intensity: HapticIntensity) {
        guard intensity != .off else { return }
        #if canImport(UIKit)
        switch intensity {
        case .off:
            break
        case .light:
            lightHaptic?.impactOccurred()
        case .medium:
            mediumHaptic?.impactOccurred()
        case .strong:
            heavyHaptic?.impactOccurred()
        }
        #endif
    }
}
