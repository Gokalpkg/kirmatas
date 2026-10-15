import Foundation
import Combine

final class SaveManager: ObservableObject {
    static let shared = SaveManager()

    private let defaults = UserDefaults.standard
    private let lock = NSRecursiveLock()

    // MARK: - Core Economy & High Scores
    private var _gold: Int = 300
    var gold: Int {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _gold
        }
        set {
            lock.lock()
            _gold = newValue
            self.defaults.set(self._gold, forKey: "gold")
            lock.unlock()
            if Thread.isMainThread {
                self.objectWillChange.send()
            } else {
                DispatchQueue.main.async { self.objectWillChange.send() }
            }
        }
    }
    @Published var highScores: [String: Int] = [
        "classic": 0,
        "zen": 0,
        "descend": 0,
        "daily": 0,
        "tuft": 0
    ]
    @Published var lastDailyClaimDate: String?
    @Published var dailyStreak: Int = 1
    @Published var speed: SpeedSetting = .medium
    @Published var sfxEnabled: Bool = true
    @Published var hapticIntensity: HapticIntensity = .strong
    @Published var language: String = "tr"

    // MARK: - Legacy Paddle Indices
    @Published var unlockedPaddles: [Int] = [0]
    @Published var equippedPaddleIndex: Int = 0

    // MARK: - Cosmetic Equipment
    @Published var equippedBallSkin: String = "classic"
    @Published var equippedPaddleSkin: String = "pclassic"
    @Published var equippedTrail: String = "t1"
    @Published var equippedBrickTheme: String = "brick_classic"
    @Published var equippedBackground: String = "bg_default"

    // MARK: - Cosmetic Unlocks & Inventory
    @Published var unlockedBalls: Set<String> = ["classic"]
    @Published var unlockedPaddleIds: Set<String> = ["pclassic"]
    @Published var unlockedTrails: Set<String> = ["t1"]
    @Published var unlockedBricks: Set<String> = ["brick_classic"]
    @Published var unlockedBackgrounds: Set<String> = ["bg_default"]
    @Published var unlockedFish: [String] = ["guppy", "tetra"]

    // MARK: - Upgrades & Boosts
    @Published var upgrades: [String: Int] = ["battery": 0, "magnet": 0, "luck": 0]
    @Published var boostStocks: [String: Int] = ["life": 0, "wide": 0, "multi": 0]
    @Published var categoryShards: [String: Int] = ["balls": 0, "paddles": 0, "trails": 0, "bricks": 0]
    @Published var lastAdWatchTime: Int = 0
    @Published var classicSavedLevel: Int = 1
    @Published var fortuneWheelSpinsToday: Int = 0
    @Published var lastFortuneWheelDate: String = ""
    @Published var chaosSavedLevel: Int = 1
    @Published var chaosSavedScore: Int = 0
    @Published var chaosSavedStock: Int = 3
    var hasChaosSession: Bool = false

    // MARK: - Eco-Tank Aquarium
    @Published var aquariumState: AquariumState = AquariumState()

    // MARK: - Quests & Streak
    @Published var dailyQuests: [DailyQuest] = QuestCatalog.defaultDailyQuests
    @Published var lastQuestResetDate: String?

    // MARK: - Legacy Paddle Mappings
    public static let paddleIndexToId: [Int: String] = [
        0: "pclassic", 1: "ppink", 2: "pice", 3: "pbat", 4: "pcyber", 5: "pgold"
    ]
    public static let paddleIdToIndex: [String: Int] = [
        "pclassic": 0, "ppink": 1, "pice": 2, "pbat": 3, "pcyber": 4, "pgold": 5
    ]

    var hapticsEnabled: Bool {
        hapticIntensity != .off
    }

    private func mutateOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private init() {
        load()
    }

    // MARK: - Persistence Loading
    func load() {
        lock.lock()
        defer { lock.unlock() }

        if defaults.object(forKey: "gold") != nil {
            _gold = defaults.integer(forKey: "gold")
        } else {
            _gold = 300
        }

        if let savedScores = defaults.dictionary(forKey: "highScores") as? [String: Int] {
            for (k, v) in savedScores {
                highScores[k] = v
            }
        }

        lastDailyClaimDate = defaults.string(forKey: "lastDailyClaimDate")
        if defaults.object(forKey: "dailyStreak") != nil {
            dailyStreak = defaults.integer(forKey: "dailyStreak")
        }

        if defaults.object(forKey: "speedSetting") != nil {
            let idx = defaults.integer(forKey: "speedSetting")
            speed = SpeedSetting(rawValue: idx) ?? .medium
        }

        if defaults.object(forKey: "sfxEnabled") != nil {
            sfxEnabled = defaults.bool(forKey: "sfxEnabled")
        } else {
            sfxEnabled = true
        }

        if defaults.object(forKey: "hapticIntensity") != nil {
            let hIdx = defaults.integer(forKey: "hapticIntensity")
            hapticIntensity = HapticIntensity(rawValue: hIdx) ?? .strong
        }

        language = defaults.string(forKey: "language") ?? I18n.deviceDefault

        // Cosmetics equipped
        equippedBallSkin = defaults.string(forKey: "equippedBallSkin") ?? "classic"
        equippedPaddleSkin = defaults.string(forKey: "equippedPaddleSkin") ?? "pclassic"
        equippedTrail = defaults.string(forKey: "equippedTrail") ?? "t1"
        equippedBrickTheme = defaults.string(forKey: "equippedBrickTheme") ?? "brick_classic"
        equippedBackground = defaults.string(forKey: "equippedBackground") ?? "bg_default"

        // Unlocked items
        if let balls = defaults.stringArray(forKey: "unlockedBalls") {
            unlockedBalls = Set(balls)
        } else {
            unlockedBalls = ["classic"]
        }

        if let trails = defaults.stringArray(forKey: "unlockedTrails") {
            unlockedTrails = Set(trails)
        } else {
            unlockedTrails = ["t1"]
        }

        if let bricks = defaults.stringArray(forKey: "unlockedBricks") {
            unlockedBricks = Set(bricks)
        } else {
            unlockedBricks = ["brick_classic"]
        }

        if let bgs = defaults.stringArray(forKey: "unlockedBackgrounds") {
            unlockedBackgrounds = Set(bgs)
        } else {
            unlockedBackgrounds = ["bg_default"]
        }

        if let fishes = defaults.stringArray(forKey: "unlockedFish") {
            unlockedFish = fishes
        } else {
            unlockedFish = ["guppy", "tetra"]
        }

        // Paddle synchronization
        if let pStrings = defaults.stringArray(forKey: "unlockedPaddleIds") {
            unlockedPaddleIds = Set(pStrings)
        } else {
            unlockedPaddleIds = ["pclassic"]
        }

        if let unl = defaults.array(forKey: "unlockedPaddles") as? [Int] {
            unlockedPaddles = unl
            for idx in unl {
                if let pid = Self.paddleIndexToId[idx] {
                    unlockedPaddleIds.insert(pid)
                }
            }
        } else {
            unlockedPaddles = [0]
        }

        for pid in unlockedPaddleIds {
            if let idx = Self.paddleIdToIndex[pid], !unlockedPaddles.contains(idx) {
                unlockedPaddles.append(idx)
            }
        }

        if defaults.object(forKey: "equippedPaddleIndex") != nil {
            equippedPaddleIndex = defaults.integer(forKey: "equippedPaddleIndex")
            if let pid = Self.paddleIndexToId[equippedPaddleIndex] {
                equippedPaddleSkin = pid
            }
        } else if let idx = Self.paddleIdToIndex[equippedPaddleSkin] {
            equippedPaddleIndex = idx
        }

        // Upgrades
        if let upg = defaults.dictionary(forKey: "upgrades") as? [String: Int] {
            upgrades = upg
        } else {
            upgrades = ["battery": 0, "magnet": 0, "luck": 0]
        }

        // Boosts
        if let bst = defaults.dictionary(forKey: "boostStocks") as? [String: Int] {
            boostStocks = bst
        } else {
            boostStocks = ["life": 0, "wide": 0, "multi": 0]
        }
        if let shards = defaults.dictionary(forKey: "categoryShards") as? [String: Int] {
            categoryShards = shards
        }
        lastAdWatchTime = defaults.integer(forKey: "lastAdWatchTime")
        classicSavedLevel = max(1, defaults.integer(forKey: "classicSavedLevel"))
        fortuneWheelSpinsToday = defaults.integer(forKey: "fortuneWheelSpinsToday")
        lastFortuneWheelDate = defaults.string(forKey: "lastFortuneWheelDate") ?? ""
        chaosSavedLevel = max(1, defaults.integer(forKey: "chaosSavedLevel") == 0 ? 1 : defaults.integer(forKey: "chaosSavedLevel"))
        chaosSavedScore = defaults.integer(forKey: "chaosSavedScore")
        chaosSavedStock = defaults.integer(forKey: "chaosSavedStock") == 0 ? 3 : defaults.integer(forKey: "chaosSavedStock")
        hasChaosSession = defaults.bool(forKey: "hasChaosSession")

        // Aquarium state
        if let aqData = defaults.data(forKey: "aquariumState_data"),
           let loadedAq = try? JSONDecoder().decode(AquariumState.self, from: aqData) {
            aquariumState = loadedAq
            // Keep unlockedFish in sync
            unlockedFish = loadedAq.unlockedFishIds
        } else {
            aquariumState = AquariumState(unlockedFishIds: unlockedFish)
        }

        // Quests
        lastQuestResetDate = defaults.string(forKey: "lastQuestResetDate")
        if let qData = defaults.data(forKey: "dailyQuests_data"),
           let loadedQuests = try? JSONDecoder().decode([DailyQuest].self, from: qData) {
            dailyQuests = loadedQuests
        } else {
            dailyQuests = QuestCatalog.defaultDailyQuests
        }
        checkQuestReset()
    }

    private func notifyChange() {
        if Thread.isMainThread {
            self.objectWillChange.send()
        } else {
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }

    // MARK: - Gold Management
    func addGold(_ amount: Int) {
        if amount < 0 {
            _ = spendGold(-amount)
            return
        }
        guard amount > 0 else { return }
        lock.lock()
        let (newGold, overflow) = self._gold.addingReportingOverflow(amount)
        self._gold = overflow ? Int.max : newGold
        self.defaults.set(self._gold, forKey: "gold")
        lock.unlock()
        notifyChange()
    }

    func canAfford(_ amount: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _gold >= amount
    }

    func spendGold(_ amount: Int) -> Bool {
        lock.lock()
        guard amount >= 0 && _gold >= amount else {
            lock.unlock()
            return false
        }
        self._gold -= amount
        self.defaults.set(self._gold, forKey: "gold")
        lock.unlock()
        notifyChange()
        return true
    }

    // MARK: - High Scores & Settings
    func updateHighScore(mode: GameMode, score: Int) {
        let current = highScores[mode.rawValue] ?? 0
        if score > current {
            mutateOnMain {
                self.highScores[mode.rawValue] = score
                self.defaults.set(self.highScores, forKey: "highScores")
            }
        }
    }

    func getHighScore(_ mode: GameMode) -> Int {
        highScores[mode.rawValue] ?? 0
    }

    func setSpeed(_ s: SpeedSetting) {
        mutateOnMain {
            self.speed = s
            self.defaults.set(s.rawValue, forKey: "speedSetting")
        }
    }

    func setSfx(_ val: Bool) {
        mutateOnMain {
            self.sfxEnabled = val
            self.defaults.set(val, forKey: "sfxEnabled")
        }
    }

    func setHapticIntensity(_ val: HapticIntensity) {
        mutateOnMain {
            self.hapticIntensity = val
            self.defaults.set(val.rawValue, forKey: "hapticIntensity")
        }
    }

    func setLanguage(_ lang: String) {
        mutateOnMain {
            self.language = lang
            self.defaults.set(lang, forKey: "language")
        }
    }

    // MARK: - Legacy & New Paddle Equipping
    func unlockPaddle(index: Int) {
        mutateOnMain {
            if !self.unlockedPaddles.contains(index) {
                self.unlockedPaddles.append(index)
                self.defaults.set(self.unlockedPaddles, forKey: "unlockedPaddles")
            }
            if let pid = Self.paddleIndexToId[index] {
                self.unlockedPaddleIds.insert(pid)
                self.defaults.set(Array(self.unlockedPaddleIds), forKey: "unlockedPaddleIds")
            }
        }
    }

    func equipPaddle(index: Int) {
        mutateOnMain {
            if self.unlockedPaddles.contains(index) {
                self.equippedPaddleIndex = index
                self.defaults.set(index, forKey: "equippedPaddleIndex")
                if let pid = Self.paddleIndexToId[index] {
                    self.equippedPaddleSkin = pid
                    self.defaults.set(pid, forKey: "equippedPaddleSkin")
                }
            }
        }
    }

    func equipPaddle(id: String) {
        mutateOnMain {
            if self.unlockedPaddleIds.contains(id) {
                self.equippedPaddleSkin = id
                self.defaults.set(id, forKey: "equippedPaddleSkin")
                if let idx = Self.paddleIdToIndex[id] {
                    self.equippedPaddleIndex = idx
                    self.defaults.set(idx, forKey: "equippedPaddleIndex")
                }
            }
        }
    }

    // MARK: - Generic Cosmetics Handling
    func isUnlocked(cosmeticId: String) -> Bool {
        if unlockedBalls.contains(cosmeticId) { return true }
        if unlockedPaddleIds.contains(cosmeticId) { return true }
        if unlockedTrails.contains(cosmeticId) { return true }
        if unlockedBricks.contains(cosmeticId) { return true }
        if unlockedBackgrounds.contains(cosmeticId) { return true }
        if unlockedFish.contains(cosmeticId) { return true }
        // Aliases
        if cosmeticId == "classic" || cosmeticId == "pclassic" || cosmeticId == "t1" ||
           cosmeticId == "brick_classic" || cosmeticId == "bg_default" {
            return true
        }
        return false
    }

    func unlock(cosmeticId: String) {
        mutateOnMain {
            if BallSkinItem.allSkins.contains(where: { $0.id == cosmeticId }) {
                self.unlockedBalls.insert(cosmeticId)
                self.defaults.set(Array(self.unlockedBalls), forKey: "unlockedBalls")
            } else if PaddleSkinItem.allSkins.contains(where: { $0.id == cosmeticId }) {
                self.unlockedPaddleIds.insert(cosmeticId)
                self.defaults.set(Array(self.unlockedPaddleIds), forKey: "unlockedPaddleIds")
                if let idx = Self.paddleIdToIndex[cosmeticId], !self.unlockedPaddles.contains(idx) {
                    self.unlockedPaddles.append(idx)
                    self.defaults.set(self.unlockedPaddles, forKey: "unlockedPaddles")
                }
            } else if TrailSkinItem.allTrails.contains(where: { $0.id == cosmeticId }) {
                self.unlockedTrails.insert(cosmeticId)
                self.defaults.set(Array(self.unlockedTrails), forKey: "unlockedTrails")
            } else if BrickSkinItem.allBricks.contains(where: { $0.id == cosmeticId }) || cosmeticId.starts(with: "b_") {
                self.unlockedBricks.insert(cosmeticId)
                self.defaults.set(Array(self.unlockedBricks), forKey: "unlockedBricks")
            } else if BackgroundThemeItem.allThemes.contains(where: { $0.id == cosmeticId }) {
                self.unlockedBackgrounds.insert(cosmeticId)
                self.defaults.set(Array(self.unlockedBackgrounds), forKey: "unlockedBackgrounds")
            } else if FishSpecies.allSpecies.contains(where: { $0.id == cosmeticId }) {
                if !self.unlockedFish.contains(cosmeticId) {
                    self.unlockedFish.append(cosmeticId)
                    self.defaults.set(self.unlockedFish, forKey: "unlockedFish")
                    self.aquariumState.unlockedFishIds = self.unlockedFish
                    self.saveAquariumState()
                }
            } else {
                // Default fallback to balls
                self.unlockedBalls.insert(cosmeticId)
                self.defaults.set(Array(self.unlockedBalls), forKey: "unlockedBalls")
            }
        }
    }

    func equipBallSkin(_ id: String) {
        if isUnlocked(cosmeticId: id) {
            mutateOnMain {
                self.equippedBallSkin = id
                self.defaults.set(id, forKey: "equippedBallSkin")
            }
        }
    }

    func equipTrail(_ id: String) {
        if isUnlocked(cosmeticId: id) {
            mutateOnMain {
                self.equippedTrail = id
                self.defaults.set(id, forKey: "equippedTrail")
            }
        }
    }

    func equipBrickTheme(_ id: String) {
        if isUnlocked(cosmeticId: id) {
            mutateOnMain {
                self.equippedBrickTheme = id
                self.defaults.set(id, forKey: "equippedBrickTheme")
            }
        }
    }

    func equipBackground(_ id: String) {
        if isUnlocked(cosmeticId: id) {
            mutateOnMain {
                self.equippedBackground = id
                self.defaults.set(id, forKey: "equippedBackground")
            }
        }
    }

    func equip(cosmeticId: String) {
        if BallSkinItem.allSkins.contains(where: { $0.id == cosmeticId }) || cosmeticId == "classic" {
            equipBallSkin(cosmeticId)
        } else if PaddleSkinItem.allSkins.contains(where: { $0.id == cosmeticId }) || cosmeticId == "pclassic" {
            equipPaddle(id: cosmeticId)
        } else if TrailSkinItem.allTrails.contains(where: { $0.id == cosmeticId }) || cosmeticId == "t1" {
            equipTrail(cosmeticId)
        } else if BrickSkinItem.allBricks.contains(where: { $0.id == cosmeticId }) || cosmeticId.starts(with: "b_") {
            equipBrickTheme(cosmeticId)
        } else if BackgroundThemeItem.allThemes.contains(where: { $0.id == cosmeticId }) || cosmeticId.starts(with: "bg_") {
            equipBackground(cosmeticId)
        }
    }

    // MARK: - Upgrades & Boosts Transactions
    func buyUpgrade(_ upgradeId: String) -> Bool {
        guard let def = UpgradeDefItem.allUpgrades.first(where: { $0.id == upgradeId }) else { return false }
        let currentLvl = upgrades[upgradeId] ?? 0
        guard let cost = def.costForNextLevel(currentLevel: currentLvl) else { return false }
        guard spendGold(cost) else { return false }
        mutateOnMain {
            self.upgrades[upgradeId] = currentLvl + 1
            self.defaults.set(self.upgrades, forKey: "upgrades")
        }
        return true
    }

    func buyBoost(_ boostId: String) -> Bool {
        guard let def = BoostItemDef.allBoosts.first(where: { $0.id == boostId }) else { return false }
        let currentStock = boostStocks[boostId] ?? 0
        guard currentStock < def.maxStock else { return false }
        guard spendGold(def.cost) else { return false }
        mutateOnMain {
            self.boostStocks[boostId] = currentStock + 1
            self.defaults.set(self.boostStocks, forKey: "boostStocks")
        }
        return true
    }

    func useBoost(_ boostId: String) -> Bool {
        let currentStock = boostStocks[boostId] ?? 0
        guard currentStock > 0 else { return false }
        mutateOnMain {
            self.boostStocks[boostId] = currentStock - 1
            self.defaults.set(self.boostStocks, forKey: "boostStocks")
        }
        return true
    }

    // MARK: - Daily Streak Management
    var canClaimDailyStreak: Bool {
        let today = Self.todayString()
        return lastDailyClaimDate != today
    }

    func canClaimDaily() -> Bool {
        canClaimDailyStreak
    }

    @discardableResult
    func claimDailyStreak() -> Int {
        guard canClaimDailyStreak else { return 0 }
        let today = Self.todayString()

        let isConsecutive: Bool
        if let last = lastDailyClaimDate, let yesterday = Self.yesterdayString(), last == yesterday {
            isConsecutive = true
        } else {
            isConsecutive = false
        }

        var newStreak = dailyStreak
        if isConsecutive {
            if newStreak >= 7 {
                newStreak = 1
            } else {
                newStreak += 1
            }
        } else {
            newStreak = 1
        }

        let rewardDef = QuestCatalog.rewardForDay(newStreak)
        let goldReward = (newStreak == 7) ? 250 : rewardDef.goldReward

        mutateOnMain {
            if let bonus = rewardDef.bonusType {
                switch bonus {
                case .lifeBoost:
                    self.boostStocks["life"] = min(20, (self.boostStocks["life"] ?? 0) + 1)
                    self.defaults.set(self.boostStocks, forKey: "boostStocks")
                case .wideBoost:
                    self.boostStocks["wide"] = min(20, (self.boostStocks["wide"] ?? 0) + 1)
                    self.defaults.set(self.boostStocks, forKey: "boostStocks")
                case .jackpot, .welcome:
                    break
                }
            }

            self.lastDailyClaimDate = today
            self.defaults.set(today, forKey: "lastDailyClaimDate")
            self.dailyStreak = newStreak
            self.defaults.set(newStreak, forKey: "dailyStreak")
            self.addGold(goldReward)
        }

        return goldReward
    }

    @discardableResult
    func claimDailyReward() -> Int {
        claimDailyStreak()
    }

    // MARK: - Daily Quests
    func checkQuestReset() {
        let today = Self.todayString()
        if lastQuestResetDate != today {
            dailyQuests = QuestCatalog.defaultDailyQuests
            lastQuestResetDate = today
            saveQuests()
            defaults.set(today, forKey: "lastQuestResetDate")
        }
    }

    func recordQuestProgress(type: QuestType, amount: Int) {
        guard amount > 0 else { return }
        mutateOnMain {
            self.checkQuestReset()
            var modified = false
            for i in 0..<self.dailyQuests.count {
                if self.dailyQuests[i].type == type {
                    if type == .combo {
                        if amount > self.dailyQuests[i].current {
                            self.dailyQuests[i].current = min(self.dailyQuests[i].target, amount)
                            modified = true
                        }
                    } else {
                        self.dailyQuests[i].addProgress(amount)
                        modified = true
                    }
                }
            }
            if modified {
                self.saveQuests()
            }
        }
    }

    @discardableResult
    func claimQuest(id: String) -> Int {
        var reward = 0
        mutateOnMain {
            for i in 0..<self.dailyQuests.count {
                if (self.dailyQuests[i].id == id || self.dailyQuests[i].type.rawValue == id),
                   self.dailyQuests[i].canClaim {
                    self.dailyQuests[i].isClaimed = true
                    reward = self.dailyQuests[i].goldReward
                    self.addGold(reward)
                    self.saveQuests()
                    break
                }
            }
        }
        return reward
    }

    private func saveQuests() {
        if let data = try? JSONEncoder().encode(dailyQuests) {
            defaults.set(data, forKey: "dailyQuests_data")
        }
    }

    // MARK: - Eco-Tank Aquarium
    var isFishHungry: Bool {
        lock.lock()
        defer { lock.unlock() }
        return aquariumState.isFishHungry
    }

    var aquariumIdleGold: Int {
        lock.lock()
        defer { lock.unlock() }
        let gains = aquariumState.calculateOfflineGains()
        return gains.gold + gains.comebackBonus
    }

    var aquariumAlertActive: Bool {
        isFishHungry || aquariumIdleGold >= 20
    }

    @discardableResult
    func feedFish() -> (comebackBonus: Int, hungerCleared: Bool) {
        lock.lock()
        defer { lock.unlock() }
        var result = (comebackBonus: 0, hungerCleared: false)
        let alreadyClaimed = self.aquariumState.hasClaimedComebackBonus
        let wasHungry = self.aquariumState.feed()
        if wasHungry && !alreadyClaimed {
            result = (comebackBonus: 20, hungerCleared: true)
            self.addGold(20)
        } else if wasHungry {
            result = (comebackBonus: 0, hungerCleared: true)
        } else {
            result = (comebackBonus: 0, hungerCleared: false)
        }
        self.saveAquariumState()
        self.recordQuestProgress(type: .fish, amount: 1)
        notifyChange()
        return result
    }

    @discardableResult
    func collectAquariumGold() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let total = self.aquariumState.harvest()
        if total > 0 {
            self.addGold(total)
        }
        self.saveAquariumState()
        notifyChange()
        return total
    }

    private func saveAquariumState() {
        if let data = try? JSONEncoder().encode(aquariumState) {
            defaults.set(data, forKey: "aquariumState_data")
        }
    }

    // MARK: - Crate Opening Simulation
    @discardableResult
    func openCrate(tier: CrateItem, spendCost: Bool = true) -> CrateDropResult? {
        if spendCost {
            guard spendGold(tier.cost) else { return nil }
        }

        let luck = upgrades["luck"] ?? 0
        let rolledRarity = tier.rollRarity(luckLevel: luck)

        // Drop category distribution (25% each)
        let types: [CrateDropType] = [.ball, .paddle, .trail, .fish]
        let dropType = types.randomElement() ?? .ball

        let candidateId: String
        let itemName: String

        switch dropType {
        case .ball:
            let matching = BallSkinItem.allSkins.filter { $0.rarity == rolledRarity }
            let picked = (matching.isEmpty ? BallSkinItem.allSkins : matching).randomElement() ?? BallSkinItem.allSkins[0]
            candidateId = picked.id
            itemName = picked.name
        case .paddle:
            let matching = PaddleSkinItem.allSkins.filter { $0.rarity == rolledRarity }
            let picked = (matching.isEmpty ? PaddleSkinItem.allSkins : matching).randomElement() ?? PaddleSkinItem.allSkins[0]
            candidateId = picked.id
            itemName = picked.name
        case .trail:
            let matching = TrailSkinItem.allTrails.filter { $0.rarity == rolledRarity }
            let picked = (matching.isEmpty ? TrailSkinItem.allTrails : matching).randomElement() ?? TrailSkinItem.allTrails[0]
            candidateId = picked.id
            itemName = picked.name
        case .fish:
            let matching = FishSpecies.allSpecies.filter { $0.rarity == rolledRarity }
            let picked = (matching.isEmpty ? FishSpecies.allSpecies : matching).randomElement() ?? FishSpecies.allSpecies[0]
            candidateId = picked.id
            itemName = picked.name
        }

        let isDup = isUnlocked(cosmeticId: candidateId)
        let refund: Int

        if isDup {
            refund = rolledRarity.duplicateRefund
            addGold(refund)
        } else {
            refund = 0
            unlock(cosmeticId: candidateId)
        }

        return CrateDropResult(
            itemIdentifier: candidateId,
            name: itemName,
            rarity: rolledRarity,
            type: dropType,
            isDuplicate: isDup,
            refundGold: refund
        )
    }

    @discardableResult
    func openCrate(tierId: String) -> CrateDropResult? {
        let tier = Cosmetics.crate(byId: tierId)
        return openCrate(tier: tier)
    }

    func addShard(_ category: String, count: Int = 1) {
        categoryShards[category, default: 0] += count
        defaults.set(categoryShards, forKey: "categoryShards")
        notifyChange()
    }

    func grantBoost(_ boostId: String, count: Int = 1) {
        boostStocks[boostId] = min(20, (boostStocks[boostId] ?? 0) + count)
        defaults.set(boostStocks, forKey: "boostStocks")
        notifyChange()
    }

    var remainingWheelSpins: Int {
        let today = Self.todayString()
        if lastFortuneWheelDate != today { return 3 }
        return max(0, 3 - fortuneWheelSpinsToday)
    }

    var canSpinFortuneWheel: Bool { remainingWheelSpins > 0 }

    func recordWheelSpin() -> Bool {
        let today = Self.todayString()
        if lastFortuneWheelDate != today {
            lastFortuneWheelDate = today
            fortuneWheelSpinsToday = 0
        }
        guard fortuneWheelSpinsToday < 3 else { return false }
        fortuneWheelSpinsToday += 1
        defaults.set(lastFortuneWheelDate, forKey: "lastFortuneWheelDate")
        defaults.set(fortuneWheelSpinsToday, forKey: "fortuneWheelSpinsToday")
        notifyChange()
        return true
    }

    func setLastAdWatchTime(_ ms: Int) {
        lastAdWatchTime = ms
        defaults.set(ms, forKey: "lastAdWatchTime")
        notifyChange()
    }

    func noteClassicLevel(_ level: Int) {
        classicSavedLevel = max(1, level)
        defaults.set(classicSavedLevel, forKey: "classicSavedLevel")
    }

    func saveChaosSession(level: Int, score: Int, stock: Int) {
        chaosSavedLevel = level
        chaosSavedScore = score
        chaosSavedStock = stock
        hasChaosSession = true
        defaults.set(level, forKey: "chaosSavedLevel")
        defaults.set(score, forKey: "chaosSavedScore")
        defaults.set(stock, forKey: "chaosSavedStock")
        defaults.set(true, forKey: "hasChaosSession")
    }

    func clearChaosSession() {
        hasChaosSession = false
        chaosSavedLevel = 1
        chaosSavedScore = 0
        chaosSavedStock = 3
        defaults.set(false, forKey: "hasChaosSession")
    }

    // MARK: - Date Helpers
    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func yesterdayString() -> String? {
        guard let yDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: yDate)
    }
}
