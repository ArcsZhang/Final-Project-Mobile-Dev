//
//  GameScene.swift
//  Final Project Shared
//
//  Created by user284810 on 11/12/25.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    public var sceneWidth: CGFloat = 0
    public var sceneHeight: CGFloat = 0
    var deviceScale: CGFloat = 1.0
    
    // Player
    var player : SKSpriteNode!
    var movementDirection : CGFloat = 1.0
    
    // --- Player Stats ---
    var playerDamage: Int = 80
    var playerMoveSpeed: CGFloat = 150
    var baseFireRate: Double = 0.6
    var playerFireRate: Double = 0.6
    
    // --- Weapon Abilities ---
    var hasDoubleShot = false
    var hasScatterShot = false
    var hasRicochet = false
    var hasPlasmaField = false
    var hasLuckBoost = false
    var hasBigShot = false
    
    // --- Game Logic ---
    var lastShotTime : CGFloat = 0
    var isPausedForShot = false
    
    let maxHearts = 3
    var currentHearts = 3
    var heartNodes: [SKSpriteNode] = []
    
    private var lastUpdateTime : TimeInterval = 0
    var pressHold = false
    
    var score = 0
    var scoreLabel: SKLabelNode!
    
    var level = 0
    let evolutionInterval = 6 // Evolve every 6 levels
    
    var isSpawning = false
    var pendingEnemies = 0
    
    // --- HUD ---
    var waveCountdownLabel: SKLabelNode!
    var totalWaveLabel: SKLabelNode!
    
    // --- States ---
    var isStarted = false
    var isGameOver = false
    var isInvincible = false
    var isBerserk = false
    var isPausedByUser = false
    
    // --- Visuals ---
    var hasShield = false
    let shieldNodeName = "shieldVisual"
    let berserkNodeName = "berserkVisual"
    
    // --- Upgrade System ---
    var isPausedForUpgrade = false
    var currentUpgradeOptions: [UpgradeOption] = []
    
    struct UpgradeOption {
        var title: String
        var description: String
        var action: () -> Void
    }
    
    struct HighscoreStorage {
        static let localKey = "localHighscore"
        static let globalKey = "cachedGlobalHighscore"

        static var localHighscore: Int {
            get { UserDefaults.standard.integer(forKey: localKey) }
            set { UserDefaults.standard.set(newValue, forKey: localKey) }
        }

        static var cachedGlobalHighscore: Int {
            get { UserDefaults.standard.integer(forKey: globalKey) }
            set { UserDefaults.standard.set(newValue, forKey: globalKey) }
        }
    }
    
    var globalLabel: SKLabelNode! = nil

    var localHighScore: Int = 0
    var globalHighScore: Int? = nil
    let globalHighScoreURL = URL(string: "https://6935d33dfa8e704dafbefcc9.mockapi.io/api/highscore/highscore")!
    
    struct PhysicsCategory {
        static let none: UInt32   = 0
        static let player: UInt32 = 0x1 << 0
        static let bullet: UInt32 = 0x1 << 1
        static let enemy: UInt32  = 0x1 << 2
        static let enemyBullet : UInt32 = 0x1 << 3
        static let powerUp: UInt32 = 0x1 << 4
    }
    
    func normalize(_ p: CGPoint) -> CGPoint {
        let length = sqrt(p.x * p.x + p.y * p.y)
        if length == 0 { return CGPoint(x: 0, y: 1) }
        return CGPoint(x: p.x / length, y: p.y / length)
    }
    
    func loadLocalHighScore() {
        localHighScore = UserDefaults.standard.integer(forKey: "localHighScore")
    }

    func saveLocalHighScore(_ score: Int) {
        if score > localHighScore {
            localHighScore = score
            UserDefaults.standard.set(score, forKey: "localHighScore")
        }
    }
    
    struct GlobalScoreResponse: Codable {
        let score: Int
        let id: String
    }

    func fetchGlobalHighScore() {
        let request = URLRequest(url: globalHighScoreURL)

        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                print("❌ API error: \(error.localizedDescription)")
                self.loadOfflineGlobalScore()
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                self.loadOfflineGlobalScore()
                return
            }
            
            do {
                let result = try JSONDecoder().decode([GlobalScoreResponse].self, from: data)
                if let first = result.first {
                    self.globalHighScore = first.score
                    self.showGlobalScore()
                    print("🌐 Global score loaded: \(first.score)")
                    
                    // Save fallback cache
                    UserDefaults.standard.set(first.score, forKey: "cachedGlobalHighScore")
                } else {
                    self.loadOfflineGlobalScore()
                }
            } catch {
                print("❌ JSON decode error: \(error.localizedDescription)")
                self.loadOfflineGlobalScore()
            }
        }
        .resume()
    }

    func loadOfflineGlobalScore() {
        DispatchQueue.main.async {
            if UserDefaults.standard.object(forKey: "cachedGlobalHighScore") != nil {
                self.globalHighScore = UserDefaults.standard.integer(forKey: "cachedGlobalHighScore")
                self.showGlobalScore()
                print("📴 Offline global score loaded")
            } else {
                self.globalHighScore = nil // means offline & no cache
                self.showGlobalScore()
                print("📴 Offline, no cached global score")
            }
        }
    }
    
    func showGlobalScore() {
        let globalText: String
        if let g = globalHighScore {
            globalText = "Global Highscore: \(g)"
        } else {
            globalText = "Global Highscore: OFFLINE"
        }

        if globalLabel == nil {
            globalLabel = SKLabelNode(text: globalText)
            print(globalText)
        } else {
            globalLabel.text = globalText
            print(globalText)
        }
    }
    
    private func setupPlayer() {
        player = SKSpriteNode(imageNamed: "ship_3")
        player.size = CGSize(width: 48 * deviceScale, height: 48 * deviceScale)
        player.setScale(1.5)
        player.texture?.filteringMode = .nearest
        
        player.position = CGPoint(x: size.width * 0.5, y: 100 * deviceScale)
        player.zPosition = 10
        addChild(player)
        
        player.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 24 * deviceScale, height: 24 * deviceScale))
        player.physicsBody?.isDynamic = true
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemyBullet | PhysicsCategory.powerUp
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
    }

    func showTitleScreen() {
        isStarted = false
    
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.fillColor = .black
        overlay.alpha = 0.85
        overlay.zPosition = 2000
        overlay.name = "titleOverlay"
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(overlay)
    
        let title = SKLabelNode(fontNamed: "PressStart2P")
        title.text = "SPACE BOUNCE"
        title.fontSize = 44 * deviceScale
        title.position = CGPoint(x: 0, y: 100 * deviceScale)
        title.fontColor = .white
        overlay.addChild(title)
    
        let start = SKLabelNode(fontNamed: "PressStart2P")
        start.text = "START"
        start.fontSize = 28 * deviceScale
        start.fontColor = .green
        start.position = CGPoint(x: 0, y: 0)
        start.name = "startButton"
        overlay.addChild(start)
    
        let help = SKLabelNode(fontNamed: "Arial")
        help.text = "Tap to shoot. Survive waves."
        help.position = CGPoint(x: 0, y: -60 * deviceScale)
        help.fontSize = 14 * deviceScale
        help.fontColor = .lightGray
        overlay.addChild(help)
        
        // Local Highscore
        let localLabel = SKLabelNode(text: "Local Highscore: \(localHighScore)")
        localLabel.fontSize = 32 * deviceScale
        localLabel.position = CGPoint(x: 0, y: -90 * deviceScale)
        overlay.addChild(localLabel)
        
        // Global Highscore
        showGlobalScore()
        globalLabel.fontSize = 28 * deviceScale
        globalLabel.position = CGPoint(x: 0, y: -120 * deviceScale)
        overlay.addChild(globalLabel)
    }

    func startGameFromTitle() {
        if let overlay = childNode(withName: "titleOverlay") {
            overlay.removeFromParent()
        }
        isStarted = true
        showTutorialTooltips()
        // start first wave or show HUD etc.
        level = 0
        startNextWave()
    }

    func setGamePaused(paused: Bool, overlay: Bool) {
        isPausedByUser = paused
        if paused {
            // pause
            physicsWorld.speed = 0
            self.speed = 0
            // freeze animations on children (safer)
            for node in children {
                node.speed = 0
            }
            // show overlay
            if overlay {
                showPauseOverlay()
            }
        } else {
            // resume
            physicsWorld.speed = 1
            self.speed = 1
            for node in children {
                node.speed = 1
            }
            if overlay {
                hidePauseOverlay()
            }
        }
    }
    
    private func setupHUD() {
        waveCountdownLabel = SKLabelNode(fontNamed: "PressStart2P")
        waveCountdownLabel.fontSize = 20 * deviceScale
        waveCountdownLabel.fontColor = .cyan
        waveCountdownLabel.horizontalAlignmentMode = .left
        waveCountdownLabel.position = CGPoint(x: 30 * deviceScale, y: 30 * deviceScale)
        waveCountdownLabel.zPosition = 100
        waveCountdownLabel.text = "\(evolutionInterval)"
        addChild(waveCountdownLabel)
        
        totalWaveLabel = SKLabelNode(fontNamed: "PressStart2P")
        totalWaveLabel.fontSize = 20 * deviceScale
        totalWaveLabel.fontColor = .white
        totalWaveLabel.horizontalAlignmentMode = .right
        totalWaveLabel.position = CGPoint(x: size.width - 30 * deviceScale, y: 30 * deviceScale)
        totalWaveLabel.zPosition = 100
        totalWaveLabel.text = "1"
        addChild(totalWaveLabel)
        
        showTutorialTooltips()
    }
    
    private func showTutorialTooltips() {
        let leftTip = SKLabelNode(fontNamed: "Arial-BoldMT")
        leftTip.text = "Waves until Evolution"
        leftTip.fontSize = 14 * deviceScale
        leftTip.fontColor = .cyan
        leftTip.horizontalAlignmentMode = .left
        leftTip.position = CGPoint(x: 30 * deviceScale, y: 60 * deviceScale)
        leftTip.zPosition = 100
        addChild(leftTip)
        
        let rightTip = SKLabelNode(fontNamed: "Arial-BoldMT")
        rightTip.text = "Current Wave"
        rightTip.fontSize = 14 * deviceScale
        rightTip.fontColor = .white
        rightTip.horizontalAlignmentMode = .right
        rightTip.position = CGPoint(x: size.width - 30 * deviceScale, y: 60 * deviceScale)
        rightTip.zPosition = 100
        addChild(rightTip)
        
        let fadeSeq = SKAction.sequence([
            SKAction.wait(forDuration: 10.0),
            SKAction.fadeOut(withDuration: 1.0),
            SKAction.removeFromParent()
        ])
        leftTip.run(fadeSeq)
        rightTip.run(fadeSeq)
    }
    
    private func updateHUD() {
        totalWaveLabel.text = "\(level)"
        let remainder = level % evolutionInterval
        let toGo = (remainder == 0) ? 0 : (evolutionInterval - remainder)
        
        if toGo == 0 {
            waveCountdownLabel.text = "EVO!"
            waveCountdownLabel.fontColor = .yellow
        } else {
            waveCountdownLabel.text = "\(toGo)"
            waveCountdownLabel.fontColor = .cyan
        }
    }

    func setupPauseButton() {
        let p = SKLabelNode(fontNamed: "Arial-BoldMT")
        p.text = "II"
        p.fontSize = 20 * deviceScale
        p.fontColor = .white
        p.position = CGPoint(x: 30, y: size.height - 40 * deviceScale)
        p.name = "pauseButton"
        p.zPosition = 1000
        addChild(p)
    }
    
    func showPauseOverlay() {
        if childNode(withName: "pauseOverlay") != nil { return }
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.fillColor = .black
        overlay.alpha = 0.8
        overlay.zPosition = 3000
        overlay.name = "pauseOverlay"
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)
        addChild(overlay)
    
        let resume = SKLabelNode(fontNamed: "PressStart2P")
        resume.text = "RESUME"
        resume.fontSize = 30 * deviceScale
        resume.fontColor = .green
        resume.position = CGPoint(x: 0, y: 40 * deviceScale)
        resume.name = "resumeButton"
        overlay.addChild(resume)
    
        let restart = SKLabelNode(fontNamed: "PressStart2P")
        restart.text = "RESTART"
        restart.fontSize = 30 * deviceScale
        restart.fontColor = .yellow
        restart.position = CGPoint(x: 0, y: -40 * deviceScale)
        restart.name = "restartButton"
        overlay.addChild(restart)
        showTutorialTooltips()
    }
    
    func hidePauseOverlay() {
        childNode(withName: "pauseOverlay")?.removeFromParent()
    }

    
    // --- Wave & Enemy Logic ---
    
    private func spawnEnemy(wave: String) {
        let count = wave.count
        if count == 0 { return }
        
        pendingEnemies = count
        var actions: [SKAction] = []
        
        for char in wave {
            let waitDuration = Double.random(in: 0.5...1.0)
            let wait = SKAction.wait(forDuration: waitDuration)
            
            let spawn = SKAction.run { [weak self] in
                guard let self = self else { return }
                
                let randomX = CGFloat.random(in: 30...(self.size.width - 30 * deviceScale))
                let spawnY = self.size.height + 10 * deviceScale
                
                var imageName = "Nautolan Ship - Fighter - Base"
                var type: Enemy.EnemyBulletType = .normal
                
                var health = 200 + (self.level * 10)
                health += (self.level / 7) * 100
                
                if char == "t" {
                    imageName = "Nautolan Ship - Frigate - Base"
                    type = .scatter
                    health *= 2
                } else if char == "b" {
                    imageName = "Nautolan Ship - Scout - Base"
                    type = .bounce
                    health = Int(Double(health) * 1.5)
                }
                
                let texture = SKTexture(imageNamed: imageName)
                texture.filteringMode = .nearest
                let visualSize = CGSize(width: 64 * deviceScale, height: 64 * deviceScale)
                let enemy = Enemy(texture: texture, color: .clear, size: visualSize)
                
                enemy.health = health
                
                // ✅ Add this line: Initialize Health Bar!
                enemy.setupHealthBar()
                
                enemy.position = CGPoint(x: randomX, y: spawnY)
                enemy.bulletType = type
                enemy.name = "enemy"
                enemy.zPosition = 5
                
                enemy.shootPattern = .blind
                
                let moveRoll = Int.random(in: 0...100)
                if moveRoll < 40 {
                    enemy.movePattern = .dive
                    enemy.vSpeed = CGFloat.random(in: 20...35)
                    enemy.hSpeed = 0
                } else if moveRoll < 80 {
                    enemy.movePattern = .zigzag
                    enemy.vSpeed = CGFloat.random(in: 5...10)
                    enemy.hSpeed = CGFloat.random(in: 30...50)
                } else {
                    enemy.movePattern = .zigzag
                    enemy.vSpeed = CGFloat.random(in: 20...30)
                    enemy.hSpeed = CGFloat.random(in: 20...40)
                }
                
                let physicsSize = CGSize(width: 48 * deviceScale, height: 48 * deviceScale)
                enemy.physicsBody = SKPhysicsBody(rectangleOf: physicsSize)
                enemy.physicsBody?.isDynamic = true
                enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
                enemy.physicsBody?.contactTestBitMask = PhysicsCategory.bullet
                enemy.physicsBody?.collisionBitMask = PhysicsCategory.none
                enemy.physicsBody?.affectedByGravity = false
                
                self.addChild(enemy)
                self.pendingEnemies -= 1
            }
            actions.append(wait)
            actions.append(spawn)
        }
        run(SKAction.sequence(actions))
    }
    
    // --- Upgrade Logic ---
    
    func generateUpgradeOptions() -> [UpgradeOption] {
        var options: [UpgradeOption] = []
        
        // --- Evolution (Every 6 levels) ---
        if level % evolutionInterval == 0 {
            var weaponPool: [UpgradeOption] = []
            
            if !hasDoubleShot {
                weaponPool.append(UpgradeOption(title: "TWIN CANNONS", description: "Fire 2 parallel bullets!") { [weak self] in
                    self?.hasDoubleShot = true
                })
            }
            if !hasScatterShot {
                weaponPool.append(UpgradeOption(title: "SCATTER SHOT", description: "Add diagonal spread shots!") { [weak self] in
                    self?.hasScatterShot = true
                })
            }
            if !hasRicochet {
                weaponPool.append(UpgradeOption(title: "RICOCHET", description: "Bullets bounce off walls!") { [weak self] in
                    self?.hasRicochet = true
                })
            }
            if !hasPlasmaField {
                weaponPool.append(UpgradeOption(title: "PLASMA FIELD", description: "Bullets destroy enemy shots!") { [weak self] in
                    self?.hasPlasmaField = true
                })
            }
            if !hasBigShot {
                weaponPool.append(UpgradeOption(title: "BIG SHOT", description: "Bullet are bigger!") { [weak self] in
                    self?.hasBigShot = true
                })
            }
            if !hasLuckBoost {
                weaponPool.append(UpgradeOption(title: "SUPPLY DROP", description: "PowerUp Chance +10%") { [weak self] in
                    self?.hasLuckBoost = true
                    print("Luck Boost Acquired!")
                })
            }
            
            let dmgBoost = 50 + (level * 5)
            weaponPool.append(UpgradeOption(title: "OVERCHARGE", description: "Damage +\(dmgBoost)") { [weak self] in
                self?.playerDamage += dmgBoost
            })
            
            weaponPool.shuffle()
            let countToPick = min(3, weaponPool.count)
            options.append(contentsOf: weaponPool.prefix(countToPick))
            return options
        }
        
        // --- Normal Levels ---
        let dmgBoost = 10 + (level * 2)
        
        options.append(UpgradeOption(title: "Damage Up", description: "Attack +\(dmgBoost)") { [weak self] in
            self?.playerDamage += dmgBoost
        })
        
        if self.baseFireRate > 0.3 {
            options.append(UpgradeOption(title: "Rapid Fire", description: "Fire Interval -0.1s") { [weak self] in
                guard let self = self else { return }
                self.baseFireRate = max(0.3, self.baseFireRate - 0.1)
                if !self.isBerserk { self.playerFireRate = self.baseFireRate }
            })
        }
        
        if currentHearts < maxHearts {
            options.append(UpgradeOption(title: "Repair", description: "Recover 1 Heart") { [weak self] in
                self?.damagePlayer(by: -1)
            })
        } else {
            options.append(UpgradeOption(title: "Bounty", description: "Score +1000") { [weak self] in
                self?.score += 1000
                self?.scoreLabel.text = "Score: \(self?.score ?? 0)"
            })
        }
        
        options.shuffle()
        return options
    }
    
    func showUpgradeMenu() {
        if isGameOver { return }
        
        isPausedForUpgrade = true
        setGamePaused(paused: true, overlay: false)
        
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = .black
        overlay.alpha = 0.85
        overlay.zPosition = 2000
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.name = "upgradeOverlay"
        addChild(overlay)
        
        let title = SKLabelNode(fontNamed: "PressStart2P")
        title.text = (level % evolutionInterval == 0) ? "EVOLUTION" : "UPGRADE"
        title.fontSize = 32 * deviceScale
        title.position = CGPoint(x: 0, y: 150 * deviceScale)
        title.fontColor = .yellow
        overlay.addChild(title)
        
        let options = generateUpgradeOptions()
        currentUpgradeOptions = options
        
        let startY: CGFloat = 50 * deviceScale
        let gap: CGFloat = 140 * deviceScale
        
        for (i, option) in options.enumerated() {
            let card = SKShapeNode(rectOf: CGSize(width: size.width - 80 * deviceScale, height: 120 * deviceScale), cornerRadius: 15 * deviceScale)
            card.fillColor = UIColor.white.withAlphaComponent(0.1)
            card.strokeColor = .white
            card.lineWidth = 2 * deviceScale
            card.position = CGPoint(x: 0, y: startY - CGFloat(i) * gap)
            card.name = "upgrade_option_\(i)"
            
            let optTitle = SKLabelNode(fontNamed: "Arial-BoldMT")
            optTitle.text = option.title
            optTitle.fontSize = 24 * deviceScale
            optTitle.position = CGPoint(x: 0, y: 15 * deviceScale)
            card.addChild(optTitle)
            
            let optDesc = SKLabelNode(fontNamed: "Arial")
            optDesc.text = option.description
            optDesc.fontSize = 16 * deviceScale
            optDesc.position = CGPoint(x: 0, y: -20 * deviceScale)
            card.addChild(optDesc)
            
            overlay.addChild(card)
        }
    }
    
    func selectUpgrade(index: Int) {
        if index >= currentUpgradeOptions.count { return }
        
        let option = currentUpgradeOptions[index]
        option.action()
        
        run(SKAction.playSoundFileNamed("powerup.mp3", waitForCompletion: false))
        
        if let overlay = childNode(withName: "upgradeOverlay") {
            overlay.removeFromParent()
        }
        
        // Use GCD to unfreeze since self.speed is 0
        isPausedForUpgrade = false
        setGamePaused(paused: false, overlay: false)
        triggerWaveSpawn()
    }
    
    // --- Visuals Logic ---
    
    func addShieldVisual() {
        if player.childNode(withName: shieldNodeName) != nil { return }
        
        let shield = SKSpriteNode(imageNamed: "shield_1")
        shield.name = shieldNodeName
        shield.zPosition = 1
        shield.setScale(1.5)
        shield.texture?.filteringMode = .nearest
        
        var textures: [SKTexture] = []
        for i in 1...6 {
            textures.append(SKTexture(imageNamed: "shield_\(i)"))
        }
        let animate = SKAction.animate(with: textures, timePerFrame: 0.1)
        shield.run(SKAction.repeatForever(animate))
        
        player.addChild(shield)
    }
    
    func removeShieldVisual() {
        if let s = player.childNode(withName: shieldNodeName) {
            s.removeFromParent()
        }
    }
    
    func activateBerserkMode() {
        if isBerserk {
            removeAction(forKey: "berserkTimer")
        }
        
        isBerserk = true
        playerFireRate = baseFireRate / 2.0
        print("BERSERK MODE!")
        
        // Add visual node instead of changing player texture
        if player.childNode(withName: berserkNodeName) == nil {
            let aura = SKSpriteNode(imageNamed: "ship_berserk_1")
            aura.name = berserkNodeName
            aura.zPosition = 0.5
            aura.setScale(1.2)
            aura.texture?.filteringMode = .nearest
            
            var textures: [SKTexture] = []
            for i in 1...10 {
                textures.append(SKTexture(imageNamed: "ship_berserk_\(i)"))
            }
            let animate = SKAction.animate(with: textures, timePerFrame: 0.05)
            aura.run(SKAction.repeatForever(animate))
            
            player.addChild(aura)
        }
        
        let wait = SKAction.wait(forDuration: 6.0)
        let endBlock = SKAction.run { [weak self] in
            self?.deactivateBerserkMode()
        }
        run(SKAction.sequence([wait, endBlock]), withKey: "berserkTimer")
    }
    
    func deactivateBerserkMode() {
        guard isBerserk else { return }
        isBerserk = false
        playerFireRate = baseFireRate
        
        if let aura = player.childNode(withName: berserkNodeName) {
            aura.removeFromParent()
        }
    }
    
    func updatePlayerSkin() {
        switch currentHearts {
        case 3: player.texture = SKTexture(imageNamed: "ship_3")
        case 2: player.texture = SKTexture(imageNamed: "ship_2")
        case 1: player.texture = SKTexture(imageNamed: "ship_1")
        default: if currentHearts >= 3 { player.texture = SKTexture(imageNamed: "ship_3") }
        }
    }
    
    // --- Game Lifecycle ---
    
    override func didMove(to view: SKView) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            deviceScale = 1.6
        }
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        let bgm = SKAudioNode(fileNamed: "song.mp3")
        bgm.autoplayLooped = true
        bgm.name = "backgroundMusic"
        addChild(bgm)
        
        setupPlayer()
        setupHearts()
        scoreLabel = setupScoreLabel()
        setupHUD()
        setupPauseButton()
        setupDebugButton()
        setupTestButton()
        loadLocalHighScore()
        fetchGlobalHighScore()
        showTitleScreen()
    }
    
    func setupDebugButton() {
        let debugBtn = SKLabelNode(fontNamed: "Arial-BoldMT")
        debugBtn.text = "[ TEST EVO ]"
        debugBtn.fontSize = 20 * deviceScale
        debugBtn.fontColor = .red
        debugBtn.position = CGPoint(x: size.width - 80 * deviceScale, y: size.height - 100 * deviceScale)
        debugBtn.zPosition = 1000
        debugBtn.name = "debugButton"
        addChild(debugBtn)
    }
    
    func setupTestButton() {
        let btn = SKLabelNode(fontNamed: "Arial-BoldMT")
        btn.text = "[ TEST DROP ]"
        btn.fontSize = 20 * deviceScale
        btn.fontColor = .cyan
        // Position top-right (below where debug button usually is)
        btn.position = CGPoint(x: size.width - 80 * deviceScale, y: size.height - 140 * deviceScale)
        btn.zPosition = 1000
        btn.name = "testDropButton"
        addChild(btn)
    }
    
    func triggerTestEvolution() {
        let nextEvoLevel = (level / evolutionInterval + 1) * evolutionInterval
        level = nextEvoLevel
        updateHUD()
        showUpgradeMenu()
    }
    
    func spawnRandomPowerUp(at position: CGPoint) {
        var availableTypes: [PowerUp.PowerType] = [.shield, .berserk]
        
        if currentHearts < maxHearts {
            availableTypes.append(.heal)
        }
        
        let selectedType = availableTypes.randomElement()!
        let p = PowerUp(type: selectedType, position: position)
        addChild(p)
    }
    
    func startNextWave() {
        level += 1
        updateHUD()
        
        if level % 2 == 0 {
            showUpgradeMenu()
        } else {
            triggerWaveSpawn()
        }
    }
    
    func triggerWaveSpawn() {
        var enemyCount = 1
        if level <= 2 { enemyCount = 1 }
        else if level <= 5 { enemyCount = 2 }
        else if level <= 9 { enemyCount = 3 }
        else if level <= 13 { enemyCount = 4 }
        else { enemyCount = min(6, 4 + (level - 13)) }
        
        var waveString = ""
        if level % 5 == 0 {
            waveString = "tbt"
        } else {
            for _ in 0..<enemyCount {
                let r = Int.random(in: 0...2)
                switch r {
                case 0: waveString += "1"
                case 1: waveString += "t"
                case 2: waveString += "b"
                default: waveString += "1"
                }
            }
        }
        spawnEnemy(wave: waveString)
        print("Starting Level \(level) with \(enemyCount) enemies")
    }
    
    // --- Input & Updates ---
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Debug
        for node in nodes {
            if node.name == "debugButton" {
                triggerTestEvolution()
                return
            }
            if node.name == "testDropButton" {
                // Spawn at a random X at the top of the screen
                let randomX = CGFloat.random(in: 30...(size.width - 30 * deviceScale))
                spawnRandomPowerUp(at: CGPoint(x: randomX, y: size.height))
                return
            }
            if node.name == "startButton" {
                startGameFromTitle()
                return
            }
            if node.name == "pauseButton" {
                // toggle
                setGamePaused(paused: true, overlay: true)
                return
            }
        }
        
        if isPausedForUpgrade {
            for node in nodes {
                let name = node.name ?? node.parent?.name ?? ""
                if name.starts(with: "upgrade_option_") {
                    if let char = name.last, let index = Int(String(char)) {
                        selectUpgrade(index: index)
                    }
                    return
                }
            }
            return
        }
        
        if isPausedByUser {
            for node in nodes {
                if node.name == "resumeButton" {
                    setGamePaused(paused: false, overlay: true)
                    return
                }
                if node.name == "restartButton" {
                    // if pause overlay's restart
                    restartGame()
                    return
                }
            }
            return
        }

        if isGameOver {
            for node in nodes {
                if node.name == "restartButton" { restartGame() }
            }
            return
        }
        
        pressHold = true
        shoot()
    }
    
    override func update(_ currentTime: TimeInterval) {
        let dt : TimeInterval
        if lastUpdateTime == 0 { dt = 0 }
        else { dt = currentTime - lastUpdateTime }
        lastUpdateTime = currentTime
        if isGameOver || isPausedForUpgrade || !isStarted || isPausedByUser { return }

        for node in children {
            if let enemy = node as? Enemy {
                enemy.updateAI(deltaTime: dt, scene: self)
            }
            if let bullet = node as? Bullet {
                bullet.updateBullet(deltaTime: dt, scene: self)
            }
        }
        
        checkWaveStatus()
        
        if isPausedForShot {
            if currentTime - lastShotTime >= playerFireRate {
                isPausedForShot = false
                if pressHold {
                    shoot()
                    return
                }
            } else {
                return
            }
        }
        
        let dx = playerMoveSpeed * CGFloat(dt) * movementDirection
        player.position.x += dx
        
        let halfW = player.size.width * 0.5
        if player.position.x <= halfW {
            player.position.x = halfW
            movementDirection = 1.0
        } else if player.position.x >= size.width - halfW {
            player.position.x = size.width - halfW
            movementDirection = -1.0
        }
    }
    
    func shoot() {
        guard !isPausedForShot else { return }
        isPausedForShot = true
        lastShotTime = CACurrentMediaTime()
        run(SKAction.playSoundFileNamed("shoot.wav", waitForCompletion: false))
        
        var bulletTextures: [SKTexture] = []
        for i in 1...4 {
            bulletTextures.append(SKTexture(imageNamed: "bullet_\(i)"))
        }
        let bulletAnimation = SKAction.animate(with: bulletTextures, timePerFrame: 0.1)
        
        func createBullet(offsetX: CGFloat, angle: CGFloat) {
            var bulletSize = CGSize(width: 20 * deviceScale, height: 40 * deviceScale)
            if hasBigShot {
                bulletSize = CGSize(width: 40 * deviceScale, height: 80 * deviceScale)
            }
            let bullet = Bullet(texture: bulletTextures[0], size: bulletSize)
            bullet.owner = .player
            bullet.damage = self.playerDamage
            bullet.position = CGPoint(x: player.position.x + offsetX, y: player.position.y + 40)
            bullet.zPosition = 8
            
            bullet.run(SKAction.repeatForever(bulletAnimation))
            
            let dirX = -sin(angle)
            let dirY = cos(angle)
            bullet.direction = normalize(CGPoint(x: dirX, y: dirY))
            bullet.zRotation = angle
            
            bullet.bulletSpeed = 500
            bullet.acceleration = 0
            
            if hasRicochet {
                bullet.bounceCount = 1
            } else {
                bullet.bounceCount = 0
            }
            bullet.bounceCelling = false
            bullet.bounceFloor = false
            
            bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
            bullet.physicsBody?.categoryBitMask = PhysicsCategory.bullet
            bullet.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.enemyBullet
            bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
            bullet.physicsBody?.affectedByGravity = false
            bullet.physicsBody?.isDynamic = true
            
            addChild(bullet)
        }
        
        if hasDoubleShot {
            createBullet(offsetX: -10, angle: 0)
            createBullet(offsetX: 10, angle: 0)
        } else {
            createBullet(offsetX: 0, angle: 0)
        }
        
        if hasScatterShot {
            createBullet(offsetX: -20, angle: 0.3)
            createBullet(offsetX: 20, angle: -0.3)
        }
    }
    
    // --- Collisions & Events ---
    
    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node, let nodeB = contact.bodyB.node else { return }
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        
        // 1. Bullet vs Enemy
        if maskA == PhysicsCategory.bullet && maskB == PhysicsCategory.enemy {
            handleHit(bullet: nodeA, enemy: nodeB)
        } else if maskB == PhysicsCategory.bullet && maskA == PhysicsCategory.enemy {
            handleHit(bullet: nodeB, enemy: nodeA)
        }
        
        // 2. Plasma Field
        else if hasPlasmaField {
            if (maskA == PhysicsCategory.bullet && maskB == PhysicsCategory.enemyBullet) {
                nodeA.removeFromParent()
                nodeB.removeFromParent()
            } else if (maskB == PhysicsCategory.bullet && maskA == PhysicsCategory.enemyBullet) {
                nodeA.removeFromParent()
                nodeB.removeFromParent()
            }
        }
        
        // 3. Player vs PowerUp
        if maskA == PhysicsCategory.player && maskB == PhysicsCategory.powerUp {
            collectPowerUp(playerNode: nodeA, powerUpNode: nodeB)
        } else if maskB == PhysicsCategory.player && maskA == PhysicsCategory.powerUp {
            collectPowerUp(playerNode: nodeB, powerUpNode: nodeA)
        }
        
        // 4. Enemy Bullet vs Player
        else if maskA == PhysicsCategory.player && maskB == PhysicsCategory.enemyBullet {
            damagePlayer(by: 1)
            nodeB.removeFromParent()
        } else if maskB == PhysicsCategory.player && maskA == PhysicsCategory.enemyBullet {
            damagePlayer(by: 1)
            nodeA.removeFromParent()
        }
        
        // 5. Enemy vs Player
        if maskA == PhysicsCategory.player && maskB == PhysicsCategory.enemy {
            damagePlayer(by: 1)
            nodeB.removeFromParent()
        } else if maskA == PhysicsCategory.enemy && maskB == PhysicsCategory.player {
            damagePlayer(by: 1)
            nodeA.removeFromParent()
        }
    }
    
    func collectPowerUp(playerNode: SKNode, powerUpNode: SKNode) {
        guard let item = powerUpNode as? PowerUp else { return }
        item.removeFromParent()
        
        run(SKAction.playSoundFileNamed("powerup.mp3", waitForCompletion: false))
        
        switch item.type {
        case .shield:
            if !hasShield {
                hasShield = true
                addShieldVisual()
            } else {
                score += 500
                scoreLabel.text = "Score: \(score)"
            }
        case .heal:
            if currentHearts < maxHearts { damagePlayer(by: -1) }
            else {
                score += 500
                scoreLabel.text = "Score: \(score)"
            }
        case .berserk:
            activateBerserkMode()
        }
    }
    
    func damagePlayer(by amount: Int = 1) {
        if isGameOver { return }
        
        if amount < 0 {
            currentHearts -= amount
            if currentHearts > maxHearts { currentHearts = maxHearts }
            updateHearts()
            updatePlayerSkin()
            return
        }
        
        if hasShield {
            hasShield = false
            removeShieldVisual()
            return
        }
        
        if isInvincible { return }
        
        currentHearts -= amount
        if currentHearts < 0 { currentHearts = 0 }
        
        updateHearts()
        updatePlayerSkin()
        
        isInvincible = true
        let blink = SKAction.sequence([SKAction.fadeAlpha(to: 0.5, duration: 0.1), SKAction.fadeAlpha(to: 1.0, duration: 0.1)])
        let action = SKAction.sequence([SKAction.repeat(blink, count: 10), SKAction.run { [weak self] in self?.isInvincible = false; self?.player.alpha = 1.0 }])
        player.run(action)
        
        if currentHearts == 0 { triggerGameOver() }
    }
    
    func checkWaveStatus() {
        if isSpawning { return }
        let enemies = children.filter { $0 is Enemy }
        if enemies.isEmpty && pendingEnemies == 0 {
            isSpawning = true
            let wait = SKAction.wait(forDuration: 1.0)
            let spawn = SKAction.run { [weak self] in
                self?.startNextWave()
                self?.isSpawning = false
            }
            run(SKAction.sequence([wait, spawn]))
        }
    }
    
    private func handleHit(bullet: SKNode, enemy: SKNode) {
        if let enemy = enemy as? Enemy, let bullet = bullet as? Bullet {
            enemy.applyDamage(bullet.damage)
            if enemy.health <= 0 { enemyDestroyed(enemy) }
        }
        bullet.removeFromParent()
    }
    
    func enemyDestroyed(_ enemy: Enemy) {
        score += 100
        scoreLabel.text = "Score: \(score)"
        
        let dropChance = hasLuckBoost ? 30 : 20
        
        if Int.random(in: 0...100) < dropChance {
            spawnRandomPowerUp(at: enemy.position)
        }
        enemy.removeFromParent()
    }
    
    private func setupHearts() {
        let spacing: CGFloat = 60 * deviceScale
        let totalWidth = CGFloat(maxHearts - 1) * spacing
        let startX = size.width / 2 - totalWidth / 2
        for i in 0..<maxHearts {
            let heart = SKSpriteNode(imageNamed: "heart_full")
            heart.setScale(0.05 * deviceScale)
            heart.position = CGPoint(x: startX + CGFloat(i) * spacing, y: 30 * deviceScale)
            heart.zPosition = 100
            addChild(heart)
            heartNodes.append(heart)
        }
    }
    
    private func updateHearts() {
        for (index, heart) in heartNodes.enumerated() {
            if index < currentHearts {
                heart.texture = SKTexture(imageNamed: "heart_full")
            } else {
                heart.texture = SKTexture(imageNamed: "heart_empty")
            }
        }
    }
    
    func setupScoreLabel () -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "PressStart2P")
        label.fontSize = 24 * deviceScale
        label.zPosition = 100
        label.position = CGPoint(x: size.width / 2, y: size.height - 100 * deviceScale)
        label.text = "Score: \(score)"
        addChild(label)
        return label
    }
    
    func triggerGameOver() {
        isGameOver = true
        player.removeFromParent()
        saveLocalHighScore(score)
        if let bgm = childNode(withName: "backgroundMusic") { bgm.removeFromParent() }
        
        let go = SKLabelNode(fontNamed: "PressStart2P")
        go.text = "GAME OVER"
        go.fontSize = 40 * deviceScale
        go.fontColor = .red
        go.position = CGPoint(x: size.width/2, y: size.height/2 + 100 * deviceScale)
        go.zPosition = 1000
        addChild(go)
        
        let fs = SKLabelNode(fontNamed: "PressStart2P")
        fs.text = "Final: \(score)"
        fs.fontSize = 24 * deviceScale
        fs.position = CGPoint(x: size.width/2, y: size.height/2 + 60 * deviceScale)
        fs.zPosition = 1000
        addChild(fs)
        
        let rb = SKLabelNode(fontNamed: "PressStart2P")
        rb.text = "RESTART"
        rb.fontSize = 30 * deviceScale
        rb.fontColor = .yellow
        rb.position = CGPoint(x: size.width/2, y: size.height/2)
        rb.zPosition = 1000
        rb.name = "restartButton"
        addChild(rb)
        
        // Local Highscore
        let localLabel = SKLabelNode(text: "Local Highscore: \(localHighScore)")
        localLabel.fontSize = 32 * deviceScale
        localLabel.position = CGPoint(x: size.width/2, y: size.height/2 - 90 * deviceScale)
        addChild(localLabel)
        
        // Global Highscore
        showGlobalScore()
        globalLabel.fontSize = 28 * deviceScale
        globalLabel.position = CGPoint(x: size.width/2, y: size.height/2 - 120 * deviceScale)
        addChild(globalLabel)
        
        scoreLabel.isHidden = true
    }
    
    func restartGame() {
        removeAllChildren()
        heartNodes.removeAll()
        
        isGameOver = false
        isInvincible = false
        isBerserk = false
        hasShield = false
        isPausedByUser = false
        
        score = 0
        level = 0
        currentHearts = 3
        
        playerDamage = 80
        playerMoveSpeed = 150
        baseFireRate = 0.6
        playerFireRate = 0.6
        
        hasDoubleShot = false
        hasScatterShot = false
        hasRicochet = false
        hasPlasmaField = false
        hasLuckBoost = false
        hasBigShot = false
        
        pendingEnemies = 0
        isSpawning = false
        
        setGamePaused(paused: false, overlay: true)
        
        setupPlayer()
        setupHearts()
        scoreLabel = setupScoreLabel()
        setupHUD()
        setupDebugButton()
        setupTestButton()
        setupPauseButton()
        
        let bgm = SKAudioNode(fileNamed: "song.mp3")
        bgm.autoplayLooped = true
        bgm.name = "backgroundMusic"
        addChild(bgm)
        
        spawnEnemy(wave: "11")
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { pressHold = false }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { pressHold = false }
}
