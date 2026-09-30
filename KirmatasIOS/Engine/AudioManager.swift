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

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        #if canImport(UIKit)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Ignore audio session error on simulator
        }
        #endif
    }

    func playSfx(_ sfx: GameSfx) {
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
            if pool.count < 4 {
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
            let style: UIImpactFeedbackGenerator.FeedbackStyle =
                intensity == .light ? .light : (intensity == .medium ? .medium : .heavy)
            UIImpactFeedbackGenerator(style: style).impactOccurred()

        case .breakBrick, .steel, .powerupBuff, .powerupDebuff, .laser:
            let style: UIImpactFeedbackGenerator.FeedbackStyle =
                intensity == .light ? .light : (intensity == .medium ? .medium : .rigid)
            UIImpactFeedbackGenerator(style: style).impactOccurred()

        case .explosion, .ulti, .gameOver, .victory:
            if intensity == .strong {
                UINotificationFeedbackGenerator().notificationOccurred(sfx == .victory ? .success : .warning)
            } else {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .strong:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        #endif
    }
}
