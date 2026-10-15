import Foundation
import UIKit
import AppTrackingTransparency
import GoogleMobileAds

/// Client-side AdMob waterfall for the iOS Kirmatas app.
/// Each format tries the high floor, then the medium floor, then all prices.
final class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = AdManager()

    static let goldRewardAmount = 100
    static let cooldownSeconds = 90

    private static let rewardedUnits = [
        "ca-app-pub-1103570772752092/7910199979",
        "ca-app-pub-1103570772752092/1469089714",
        "ca-app-pub-1103570772752092/6010969959"
    ]
    private static let interstitialUnits = [
        "ca-app-pub-1103570772752092/5599906414",
        "ca-app-pub-1103570772752092/9606425027",
        "ca-app-pub-1103570772752092/3288428680"
    ]

    @Published var isShowing = false
    @Published var isLoading = false
    @Published var statusMessage: String?

    private var rewardedAd: RewardedAd?
    private var interstitialAd: InterstitialAd?
    private var gameplayCount = 0
    private var targetPlays = 3
    private var lastLongAdClose = Date.distantPast
    private var pending: Pending?

    private enum Pending {
        case gold((Int) -> Void)
        case skippable(() -> Void)
        case rewarded(success: () -> Void, early: () -> Void)
        case interstitial(() -> Void)
    }

    private var earnedReward = false

    var remainingCooldownSeconds: Int {
        let last = SaveManager.shared.lastAdWatchTime
        guard last > 0 else { return 0 }
        let elapsed = Int(Date().timeIntervalSince1970 * 1000) - last
        return max(0, Self.cooldownSeconds - elapsed / 1000)
    }

    private var didStart = false

    func start() {
        guard !didStart else { return }
        didStart = true
        #if DEBUG
        if ProcessInfo.processInfo.environment["KIRMATAS_SHOT"] != nil { return }
        #endif
        let boot = {
            MobileAds.shared.start()
            self.preloadRewarded()
            self.preloadInterstitial()
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async(execute: boot)
        }
    }

    func watchAdForGold(onSuccess: @escaping (Int) -> Void) {
        if remainingCooldownSeconds > 0 {
            statusMessage = "\(remainingCooldownSeconds) sn sonra tekrar izleyebilirsin."
            return
        }
        guard let ad = interstitialAd, !isShowing else {
            statusMessage = I18n.pick("Kısa reklam hazırlanıyor, birazdan tekrar dene.", "Ad is loading, try again in a moment.")
            preloadInterstitial()
            return
        }
        pending = .gold(onSuccess)
        presentInterstitial(ad)
    }

    func watchSkippableAd(onSuccess: @escaping () -> Void) {
        guard let ad = interstitialAd, !isShowing else {
            statusMessage = I18n.pick("Kısa reklam hazırlanıyor, birazdan tekrar dene.", "Ad is loading, try again in a moment.")
            preloadInterstitial()
            return
        }
        pending = .skippable(onSuccess)
        presentInterstitial(ad)
    }

    func watchRewardedAd(onSuccess: @escaping () -> Void, onEarly: @escaping () -> Void) {
        guard let ad = rewardedAd, !isShowing, let host = topViewController() else {
            statusMessage = I18n.pick("Ödüllü reklam hazırlanıyor, birazdan tekrar dene.", "Rewarded ad is loading, try again in a moment.")
            preloadRewarded()
            onEarly()
            return
        }
        earnedReward = false
        pending = .rewarded(success: onSuccess, early: onEarly)
        isShowing = true
        ad.fullScreenContentDelegate = self
        ad.present(from: host) { [weak self] in
            self?.earnedReward = true
        }
    }

    func checkAndShowInterstitial(level: Int, onComplete: @escaping () -> Void) {
        gameplayCount += 1
        if level < 5 {
            preloadInterstitial()
            onComplete()
            return
        }
        if Date().timeIntervalSince(lastLongAdClose) < 45 {
            preloadInterstitial()
            onComplete()
            return
        }
        guard gameplayCount >= targetPlays, let ad = interstitialAd, !isShowing else {
            if gameplayCount >= targetPlays {
                gameplayCount = 0
            }
            preloadInterstitial()
            onComplete()
            return
        }
        gameplayCount = 0
        targetPlays = Int.random(in: 3...4)
        pending = .interstitial(onComplete)
        presentInterstitial(ad)
    }

    private func presentInterstitial(_ ad: InterstitialAd) {
        guard let host = topViewController() else {
            finishPending(presented: false)
            return
        }
        isShowing = true
        ad.fullScreenContentDelegate = self
        ad.present(from: host)
    }

    private func preloadRewarded() {
        guard rewardedAd == nil else { return }
        loadRewarded(units: Self.rewardedUnits)
    }

    private func preloadInterstitial() {
        guard interstitialAd == nil else { return }
        loadInterstitial(units: Self.interstitialUnits)
    }

    private func loadRewarded(units: [String]) {
        guard let unit = units.first else {
            isLoading = false
            return
        }
        isLoading = true
        RewardedAd.load(with: unit, request: Request()) { [weak self] ad, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let ad {
                    self.rewardedAd = ad
                    self.isLoading = false
                } else {
                    self.loadRewarded(units: Array(units.dropFirst()))
                }
            }
        }
    }

    private func loadInterstitial(units: [String]) {
        guard let unit = units.first else { return }
        InterstitialAd.load(with: unit, request: Request()) { [weak self] ad, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let ad {
                    self.interstitialAd = ad
                } else {
                    self.loadInterstitial(units: Array(units.dropFirst()))
                }
            }
        }
    }

    private func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        let finished = pending
        pending = nil
        isShowing = false
        if ad is RewardedAd {
            rewardedAd = nil
            lastLongAdClose = Date()
            preloadRewarded()
            if case .rewarded(let success, let early) = finished {
                if earnedReward { success() } else { early() }
            }
        } else {
            interstitialAd = nil
            preloadInterstitial()
            switch finished {
            case .gold(let success):
                let amount = Self.goldRewardAmount
                SaveManager.shared.addGold(amount)
                SaveManager.shared.setLastAdWatchTime(Int(Date().timeIntervalSince1970 * 1000))
                AudioManager.shared.playSfx(.powerupBuff)
                statusMessage = "+\(amount) " + I18n.pick("altın", "gold")
                success(amount)
            case .skippable(let success):
                success()
            case .interstitial(let done):
                done()
            default:
                break
            }
        }
        earnedReward = false
    }

    private func finishPending(presented: Bool) {
        let finished = pending
        pending = nil
        isShowing = false
        if !presented {
            statusMessage = I18n.pick("Reklam açılamadı. Birazdan tekrar dene.", "Ad could not open. Try again in a moment.")
        }
        switch finished {
        case .rewarded(_, let early):
            early()
        case .interstitial(let done):
            done()
        default:
            break
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let finished = pending
        pending = nil
        isShowing = false
        statusMessage = I18n.pick("Reklam açılamadı. Bağlantını kontrol et.", "Ad could not open. Check your connection.")
        if ad is RewardedAd {
            rewardedAd = nil
            preloadRewarded()
            if case .rewarded(_, let early) = finished { early() }
        } else {
            interstitialAd = nil
            preloadInterstitial()
            if case .interstitial(let done) = finished { done() }
        }
    }
}
