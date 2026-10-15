import SwiftUI

public struct AquariumView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var save = SaveManager.shared

    @State private var simFish: [SimulatedFish] = []
    @State private var bubbles: [AmbientBubble] = []
    @State private var foodPellets: [FoodPellet] = []
    @State private var eatParticles: [EatParticle] = []
    @State private var lastUpdate: Date = Date()
    @State private var showingFishDrawer = false
    @State private var showingFoodShop = false
    @State private var toastMessage: String?
    @State private var harvestCelebrationGold: Int?

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Ocean Depth Background
                LinearGradient(
                    colors: [
                        Color(hex: 0xFF021B35),
                        Color(hex: 0xFF003056),
                        Color(hex: 0xFF00446A),
                        Color(hex: 0xFF032644)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Sunbeams / Light Caustics Effect
                Canvas { ctx, size in
                    for i in 0..<4 {
                        var path = Path()
                        let xOffset = Double(i) * (size.width / 3.5)
                        path.move(to: CGPoint(x: xOffset, y: 0))
                        path.addLine(to: CGPoint(x: xOffset + 60, y: 0))
                        path.addLine(to: CGPoint(x: xOffset + 120, y: size.height))
                        path.addLine(to: CGPoint(x: xOffset + 30, y: size.height))
                        path.closeSubpath()
                        ctx.fill(path, with: .color(.white.opacity(0.04)))
                    }
                }
                .ignoresSafeArea()

                // Main 120 FPS Aquarium Simulation Canvas
                TimelineView(.animation) { timeline in
                    Canvas { ctx, size in
                        let now = timeline.date
                        let dt = min(0.05, max(0.001, now.timeIntervalSince(lastUpdate)))

                        // Draw Seabed Sand Floor
                        let sandHeight: Double = 90.0
                        let sandRect = CGRect(x: 0, y: size.height - sandHeight, width: size.width, height: sandHeight)
                        ctx.fill(
                            Path(roundedRect: sandRect, cornerRadius: 0),
                            with: .linearGradient(
                                Gradient(colors: [Color(hex: 0xFF1B2B38), Color(hex: 0xFF0E1A24)]),
                                startPoint: CGPoint(x: 0, y: size.height - sandHeight),
                                endPoint: CGPoint(x: 0, y: size.height)
                            )
                        )

                        // Draw Seaweed / Kelp along bottom
                        for k in 0..<7 {
                            let kX = 35.0 + Double(k) * (size.width / 6.5)
                            let sway = sin(now.timeIntervalSince1970 * 1.5 + Double(k)) * 14.0
                            var kelpPath = Path()
                            kelpPath.move(to: CGPoint(x: kX, y: size.height - sandHeight + 15))
                            kelpPath.addQuadCurve(
                                to: CGPoint(x: kX + sway, y: size.height - sandHeight - 90),
                                control: CGPoint(x: kX + sway * 0.5, y: size.height - sandHeight - 40)
                            )
                            ctx.stroke(
                                kelpPath,
                                with: .color(Color(hex: 0xFF00E676).opacity(0.35)),
                                lineWidth: 6.0
                            )
                        }

                        // Draw Ambient Bubbles
                        for b in bubbles {
                            let bRect = CGRect(x: b.x - b.radius, y: b.y - b.radius, width: b.radius * 2, height: b.radius * 2)
                            ctx.fill(Path(ellipseIn: bRect), with: .color(.white.opacity(0.25)))
                            ctx.stroke(Path(ellipseIn: bRect), with: .color(.white.opacity(0.5)), lineWidth: 0.8)
                        }

                        // Draw Food Pellets
                        for p in foodPellets {
                            let pRect = CGRect(x: p.x - p.radius, y: p.y - p.radius, width: p.radius * 2, height: p.radius * 2)
                            ctx.fill(Path(ellipseIn: pRect), with: .color(Color(hex: 0xFFFFB74D)))
                            ctx.stroke(Path(ellipseIn: pRect), with: .color(.white.opacity(0.8)), lineWidth: 1.0)
                        }

                        // Draw Simulated Fish
                        for fish in simFish {
                            drawFish(ctx: &ctx, fish: fish, time: now.timeIntervalSince1970)
                        }

                        // Draw Eat Sparkle Particles
                        for ep in eatParticles {
                            let epRect = CGRect(x: ep.x - 2.5, y: ep.y - 2.5, width: 5, height: 5)
                            ctx.fill(Path(ellipseIn: epRect), with: .color(ep.color.opacity(ep.alpha)))
                        }
                    }
                    .onChange(of: timeline.date) { newDate in
                        updateSimulation(dt: min(0.05, max(0.001, newDate.timeIntervalSince(lastUpdate))), size: geo.size)
                        lastUpdate = newDate
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    dropFood(at: location.x, y: location.y)
                }

                // UI Overlay & Controls
                VStack(spacing: 0) {
                    // Header Bar
                    headerBar

                    Spacer()

                    // Toast Banner
                    if let msg = toastMessage {
                        toastBanner(msg)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Harvest Gold Celebration Modal
                    if let gold = harvestCelebrationGold {
                        harvestBanner(gold)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Bottom Control Deck
                    bottomControlDeck
                }
            }
            .onAppear {
                initSimulation(size: geo.size)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingFishDrawer) {
            fishCollectionSheet
        }
        .sheet(isPresented: $showingFoodShop) {
            foodShopSheet
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                AudioManager.shared.playSfx(.click)
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("ECO-TANK")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("🐠")
                }

                // Hourly Gold Rate
                Text(String(format: I18n.pick("+%.1f 🪙/saat", "+%.1f 🪙/hour"), save.aquariumState.totalGPH()))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: 0xFF4FC3F7))
            }

            Spacer()

            // Fish Food Pill
            Button(action: {
                AudioManager.shared.playSfx(.click)
                showingFoodShop = true
            }) {
                HStack(spacing: 5) {
                    Text("🌾")
                    Text("\(save.aquariumState.floraCounts["kelp"] ?? 3)")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0xFF00E676))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }

            // Wallet Gold Display
            HStack(spacing: 5) {
                Text("🪙")
                Text("\(save.gold)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: 0xFFFFD54F))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.35))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xFFFFD54F).opacity(0.3), lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color.black.opacity(0.25))
    }

    // MARK: - Bottom Control Deck
    private var bottomControlDeck: some View {
        VStack(spacing: 10) {
            // Hunger Status Bar
            HStack {
                if save.aquariumState.isFishHungry {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(hex: 0xFFFF5252))
                        Text(I18n.pick("Balıklar aç! Yem vererek üretimi başlatın.", "Your fish are hungry! Feed them to start producing gold."))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(Color(hex: 0xFF00E676))
                        let remaining = save.aquariumState.remainingFullSeconds
                        let hours = Int(remaining) / 3600
                        let mins = (Int(remaining) % 3600) / 60
                        Text(String(format: I18n.pick("Tokluk süresi: %02d:%02d kaldı", "Full for: %02d:%02d left"), hours, mins))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: 0xFFE0F7FA))
                    }
                }

                Spacer()

                // Fish Collection Button
                Button(action: {
                    AudioManager.shared.playSfx(.click)
                    showingFishDrawer = true
                }) {
                    HStack(spacing: 4) {
                        Text(I18n.pick("Balıklarım", "My Fish"))
                            .font(.system(size: 12, weight: .bold))
                        Text("(\(save.unlockedFish.count)/18)")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 18)

            // Action Buttons Row
            HStack(spacing: 12) {
                // Feed Button
                Button(action: handleFeed) {
                    HStack(spacing: 8) {
                        Text("🌾")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(I18n.pick("YEM AT", "FEED"))
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(.white)
                            Text(save.aquariumState.isFishHungry ? I18n.pick("4 Saat Üretim", "4h Production") : I18n.pick("Balıkları Besle", "Feed the Fish"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xFF00B0FF), Color(hex: 0xFF0091EA)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: Color(hex: 0xFF00B0FF).opacity(0.4), radius: 8, y: 3)
                }

                // Harvest Gold Button
                let offlineGains = save.aquariumState.calculateOfflineGains()
                let harvestable = offlineGains.gold + offlineGains.comebackBonus
                Button(action: handleHarvest) {
                    HStack(spacing: 8) {
                        Text("🪙")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(harvestable > 0 ? "+\(harvestable) " + I18n.pick("TOPLA", "COLLECT") : I18n.pick("BİRİKEN", "STORED"))
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(harvestable > 0 ? Color(hex: 0xFFFFD54F) : .white.opacity(0.5))
                            Text(harvestable > 0 ? (offlineGains.comebackBonus > 0 ? I18n.pick("Bonus Dahil!", "Bonus Included!") : I18n.pick("Altınları Al", "Collect Gold")) : I18n.pick("0 🪙 Bekliyor", "0 🪙 Waiting"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(harvestable > 0 ? .white : .white.opacity(0.4))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        harvestable > 0 ?
                        LinearGradient(
                            colors: [Color(hex: 0xFFFFB300), Color(hex: 0xFFFF8F00)],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(18)
                    .shadow(color: harvestable > 0 ? Color(hex: 0xFFFFB300).opacity(0.4) : .clear, radius: 8, y: 3)
                }
                .disabled(harvestable <= 0)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 14)
        .background(
            Color(hex: 0xFF05101A)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.1)), alignment: .top)
        )
    }

    // MARK: - Fish Collection Sheet
    private var fishCollectionSheet: some View {
        NavigationView {
            ZStack {
                Color(hex: 0xFF0A141E).ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(FishSpecies.allSpecies) { species in
                            let isUnlocked = save.unlockedFish.contains(species.id)
                            FishCardItem(species: species, isUnlocked: isUnlocked)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(I18n.pick("Akvaryum Koleksiyonu", "Aquarium Collection") + " (\(save.unlockedFish.count)/18)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(I18n.pick("Kapat", "Close")) { showingFishDrawer = false }
                        .foregroundColor(Color(hex: 0xFF4FC3F7))
                }
            }
        }
    }

    // MARK: - Food Shop Sheet
    private var foodShopSheet: some View {
        NavigationView {
            ZStack {
                Color(hex: 0xFF0A141E).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text(I18n.pick("🌾 Yem Mağazası", "🌾 Food Shop"))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    Text(I18n.pick("Balıklarını doyurarak saatlik altın üretimini 4 saat boyunca aktif tutabilirsin.", "Feed your fish to keep hourly gold production running for 4 hours."))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    VStack(spacing: 12) {
                        foodPackRow(count: 3, price: 100)
                        foodPackRow(count: 8, price: 250)
                        foodPackRow(count: 20, price: 550)
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(I18n.pick("Kapat", "Close")) { showingFoodShop = false }
                        .foregroundColor(Color(hex: 0xFF4FC3F7))
                }
            }
        }
    }

    private func foodPackRow(count: Int, price: Int) -> some View {
        HStack {
            Text("🌾")
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 3) {
                Text(I18n.isEnglish ? "\(count) Food" : "\(count) Adet Yem")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Text(I18n.pick("Balıklarınızı besleyin", "Feed your fish"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            Button(action: {
                if save.spendGold(price) {
                    save.aquariumState.floraCounts["kelp"] = (save.aquariumState.floraCounts["kelp"] ?? 0) + count
                    AudioManager.shared.playSfx(.powerupBuff)
                    showToast(I18n.isEnglish ? "+\(count) food bought! 🌾" : "+\(count) Yem satın alındı! 🌾")
                } else {
                    showToast(I18n.pick("Yetersiz altın! 🪙", "Not enough gold! 🪙"))
                }
            }) {
                HStack(spacing: 4) {
                    Text("\(price)")
                        .font(.subheadline.bold())
                    Text("🪙")
                }
                .foregroundColor(Color(hex: 0xFFFFD54F))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.12))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }

    // MARK: - Toast & Celebration Banners
    private func toastBanner(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.85))
            .cornerRadius(20)
            .shadow(radius: 6)
            .padding(.top, 10)
    }

    private func harvestBanner(_ gold: Int) -> some View {
        VStack(spacing: 8) {
            Text(I18n.pick("🎉 TEBRİKLER! 🎉", "🎉 CONGRATS! 🎉"))
                .font(.system(size: 16, weight: .black))
                .foregroundColor(Color(hex: 0xFFFFD54F))
            Text("+\(gold) " + I18n.pick("ALTIN TOPLANDI", "GOLD COLLECTED"))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(20)
        .background(
            Color(hex: 0xFF0B1E2E).opacity(0.95)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: 0xFFFFD54F), lineWidth: 2))
        )
        .cornerRadius(20)
        .shadow(color: Color(hex: 0xFFFFD54F).opacity(0.4), radius: 20)
    }

    // MARK: - Actions
    private func handleFeed() {
        AudioManager.shared.playSfx(.click)
        let result = save.feedFish()
        dropFood(at: 200, y: 150)
        dropFood(at: 140, y: 170)
        dropFood(at: 260, y: 160)
        AudioManager.shared.playSfx(.powerupBuff)
        if result.comebackBonus > 0 {
            showToast(I18n.pick("🌾 Balıklar doydu! +20 Hoş geldin bonusu kazanıldı!", "🌾 Fish fed! +20 welcome bonus earned!"))
        } else {
            showToast(I18n.pick("🌾 Balıklar doydu! 4 saat altın üretecekler.", "🌾 Fish fed! They will make gold for 4 hours."))
        }
    }

    private func handleHarvest() {
        let gold = save.collectAquariumGold()
        if gold > 0 {
            AudioManager.shared.playSfx(.victory)
            harvestCelebrationGold = gold
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { harvestCelebrationGold = nil }
            }
        }
    }

    private func dropFood(at x: Double, y: Double) {
        foodPellets.append(FoodPellet(x: x, y: y, vy: Double.random(in: 28...38)))
        AudioManager.shared.playSfx(.bubblePop)
    }

    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: - Simulation Update & Fish Drawing
    private func initSimulation(size: CGSize) {
        simFish.removeAll()
        bubbles.removeAll()

        let unlocked = save.unlockedFish
        for (i, id) in unlocked.enumerated() {
            let species = FishSpecies.getById(id)
            let spawnX = 50.0 + (Double(i) * 65.0).truncatingRemainder(dividingBy: max(100.0, size.width - 100.0))
            let spawnY = 160.0 + (Double(i) * 55.0).truncatingRemainder(dividingBy: max(120.0, size.height - 280.0))
            let speed = Double.random(in: 24...36)
            let dir = Bool.random() ? 1.0 : -1.0
            simFish.append(
                SimulatedFish(
                    species: species,
                    x: spawnX,
                    y: spawnY,
                    vx: dir * speed,
                    vy: Double.random(in: -8...8)
                )
            )
        }

        // Ambient bubbles
        for _ in 0..<22 {
            bubbles.append(
                AmbientBubble(
                    x: Double.random(in: 10...size.width),
                    y: Double.random(in: 100...size.height),
                    radius: Double.random(in: 1.5...3.8),
                    speed: Double.random(in: 18...38)
                )
            )
        }
    }

    private func updateSimulation(dt: Double, size: CGSize) {
        let w = size.width
        let h = size.height

        // 1. Update bubbles
        for i in bubbles.indices {
            bubbles[i].update(dt: dt, screenWidth: w, resetY: h - 90)
        }

        // 2. Update pellets
        for i in foodPellets.indices {
            foodPellets[i].update(dt: dt, floorY: h - 90)
        }
        foodPellets.removeAll { $0.isExpired }

        // 3. Update fish & steering
        for i in simFish.indices {
            // Check nearest food pellet
            if !foodPellets.isEmpty && simFish[i].eatCooldown <= 0 {
                var closestIdx = -1
                var minDist = 999999.0
                for (pIdx, pellet) in foodPellets.enumerated() {
                    let d = hypot(pellet.x - simFish[i].x, pellet.y - simFish[i].y)
                    if d < minDist {
                        minDist = d
                        closestIdx = pIdx
                    }
                }

                if closestIdx >= 0 {
                    let target = foodPellets[closestIdx]
                    simFish[i].steerTowards(targetX: target.x, targetY: target.y, strength: 75.0, dt: dt)

                    // Eat pellet if close
                    if minDist < 18.0 * simFish[i].species.size {
                        foodPellets.remove(at: closestIdx)
                        simFish[i].eatCooldown = 1.2
                        AudioManager.shared.playSfx(.bubblePop)
                        // Spawn eat sparkles
                        for _ in 0..<5 {
                            eatParticles.append(
                                EatParticle(
                                    x: simFish[i].x,
                                    y: simFish[i].y,
                                    color: simFish[i].species.primaryColor
                                )
                            )
                        }
                    }
                }
            }

            // Pairwise separation steering
            for j in simFish.indices where i != j {
                let dx = simFish[i].x - simFish[j].x
                let dy = simFish[i].y - simFish[j].y
                let dist = hypot(dx, dy)
                if dist > 0 && dist < 45.0 {
                    simFish[i].vx += (dx / dist) * 12.0 * dt
                    simFish[i].vy += (dy / dist) * 12.0 * dt
                }
            }

            simFish[i].update(dt: dt, tankWidth: w, tankHeight: h)
        }

        // 4. Update eat particles
        for i in eatParticles.indices {
            eatParticles[i].update(dt: dt)
        }
        eatParticles.removeAll { $0.isExpired }
    }

    private func drawFish(ctx: inout GraphicsContext, fish: SimulatedFish, time: Double) {
        var fishCtx = ctx
        fishCtx.translateBy(x: fish.x, y: fish.y)
        fishCtx.rotate(by: Angle(radians: fish.pitchAngle))
        if !fish.facingRight {
            fishCtx.scaleBy(x: -1, y: 1)
        }

        let s = fish.species.size
        // Try drawing image asset
        if let uiImg = UIImage(named: "fish_\(fish.species.assetName)") {
            let imgW = 46.0 * s
            let imgH = 46.0 * s
            let rect = CGRect(x: -imgW / 2, y: -imgH / 2, width: imgW, height: imgH)
            fishCtx.draw(Image(uiImage: uiImg), in: rect)
        } else {
            // Fallback: procedural stylized fish body & tail
            let tailWiggle = sin(fish.tailPhase) * 6.0
            var body = Path()
            body.addEllipse(in: CGRect(x: -16 * s, y: -9 * s, width: 32 * s, height: 18 * s))
            fishCtx.fill(body, with: .color(fish.species.primaryColor))

            var tail = Path()
            tail.move(to: CGPoint(x: -14 * s, y: 0))
            tail.addLine(to: CGPoint(x: -28 * s, y: -8 * s + tailWiggle))
            tail.addLine(to: CGPoint(x: -28 * s, y: 8 * s + tailWiggle))
            tail.closeSubpath()
            fishCtx.fill(tail, with: .color(fish.species.secondaryColor))

            // Eye
            let eye = CGRect(x: 7 * s, y: -3 * s, width: 4 * s, height: 4 * s)
            fishCtx.fill(Path(ellipseIn: eye), with: .color(.white))
            let pupil = CGRect(x: 8.5 * s, y: -2 * s, width: 2 * s, height: 2 * s)
            fishCtx.fill(Path(ellipseIn: pupil), with: .color(.black))
        }

        // Golden sparkle indicator above well-fed producing fish
        if save.aquariumState.isFed {
            let floatY = -22.0 * s + sin(time * 3.5 + fish.tailPhase) * 2.5
            let pulse = 0.65 + 0.35 * sin(time * 4.0 + fish.tailPhase)
            var spark = Path()
            spark.addEllipse(in: CGRect(x: -2.2, y: floatY - 2.2, width: 4.4, height: 4.4))
            fishCtx.fill(spark, with: .color(Color(hex: 0xFFFFD54F).opacity(0.65 * pulse)))
            var core = Path()
            core.addEllipse(in: CGRect(x: -1.0, y: floatY - 1.0, width: 2.0, height: 2.0))
            fishCtx.fill(core, with: .color(.white.opacity(0.85 * pulse)))
        }
    }
}

// MARK: - Fish Collection Card Item
private struct FishCardItem: View {
    let species: FishSpecies
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(species.rarity.primaryColor.opacity(0.18))
                    .frame(width: 72, height: 72)

                if isUnlocked {
                    Image("fish_\(species.assetName)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Text(species.localizedName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isUnlocked ? .white : .white.opacity(0.4))
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(species.rarity.localizedLabel)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(species.rarity.primaryColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(species.rarity.primaryColor.opacity(0.15))
                    .cornerRadius(6)

                Text(String(format: "+%.1f/s", species.passiveGPH))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: 0xFFFFD54F))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnlocked ? species.rarity.primaryColor.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1.2)
        )
    }
}
