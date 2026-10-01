import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

enum GameSfx: String {
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
    case bubble
    case click
    case gameOver
    case victory

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
        case .bubble: return "bubble2"
        case .click: return "ui1"
        case .gameOver: return "cam_kirilma"
        case .victory: return "glass_glow"
        }
    }
}

final class AudioManager {
    static let shared = AudioManager()

    private var players: [String: [AVAudioPlayer]] = [:]
    private var lastPlayedTimes: [GameSfx: Double] = [:]


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

    func playSfx(_ sfx: GameSfx) {
        // Prevent massive lag spikes when breaking 20+ bricks in one frame (e.g. Bomb/Ulti)
        let now = CACurrentMediaTime()
        if let last = lastPlayedTimes[sfx], now - last < 0.04 {
            return // Throttle to max 1 sound per 40ms of the same type
        }
        lastPlayedTimes[sfx] = now

        triggerHapticForSfx(sfx)

        guard SaveManager.shared.sfxEnabled else { return }
        let fileName = sfx.audioFileName

        if let pool = players[fileName], let available = pool.first(where: { !$0.isPlaying }) {
            available.currentTime = 0
            available.play()
            return
        }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.55
            player.prepareToPlay()
            player.play()
            var pool = players[fileName] ?? []
            if pool.count < 6 {
                pool.append(player)
                players[fileName] = pool
            }
        } catch {
            // Ignore audio playback errors
        }
    }

    private func triggerHapticForSfx(_ sfx: GameSfx) {
        let intensity = SaveManager.shared.hapticIntensity
        guard intensity != .off else { return }

        #if canImport(UIKit)
        switch sfx {
        case .hitPaddle, .hitWall, .hitBrick:
            if intensity == .light { lightHaptic?.impactOccurred() }
            else if intensity == .medium { mediumHaptic?.impactOccurred() }
            else { heavyHaptic?.impactOccurred() }

        case .breakBrick, .steel, .powerupBuff, .powerupDebuff, .laser:
            if intensity == .light { lightHaptic?.impactOccurred() }
            else if intensity == .medium { mediumHaptic?.impactOccurred() }
            else { rigidHaptic?.impactOccurred() }

        case .explosion, .ulti, .gameOver, .victory:
            if intensity == .strong {
                UINotificationFeedbackGenerator().notificationOccurred(sfx == .victory ? .success : .warning)
            } else {
                heavyHaptic?.impactOccurred()
            }

        case .click:
            UISelectionFeedbackGenerator().selectionChanged()

        case .bubble:
            break
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
