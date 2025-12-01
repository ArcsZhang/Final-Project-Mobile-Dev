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
    // Player
    var player : SKSpriteNode!
    var playerSpeed : CGFloat = 100.0
    var movementDirection : CGFloat = 1.0 // 1 right, -1 left
    
    var pauseDuration : CGFloat = 0.5
    var lastShotTime : CGFloat = 0
    var isPausedForShot = false
    
    let maxHearts = 3
    var currentHearts = 3
    var heartNodes: [SKSpriteNode] = []
    
    private var lastUpdateTime : TimeInterval = 0
    
    var pressHold = false
    
    var score = 0
    var scoreLabel: SKLabelNode!
    
    var level = 0 // current level
    var playerWeaponLevel = 1 // 玩家武器等级：1=单发，2=双发，3=强力
    
    var isSpawning = false
    var pendingEnemies = 0
    
    var isGameOver = false
    
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
    
    private func setupPlayer() {
        player = SKSpriteNode(imageNamed: "ship_3")
        player.size = CGSize(width: 48, height: 48)
        player.setScale(1.5)
        player.texture?.filteringMode = .nearest
        
        player.position = CGPoint(x: size.width * 0.5, y: 100)
        player.zPosition = 10
        addChild(player)
        // static physics body so it can be referenced but not moved by physics engine
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = true // Must be true for contacts
        player.physicsBody?.affectedByGravity = false
        
        // Identity
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        
        // Listen for contact with: Enemy Bullets AND PowerUps
        
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemyBullet | PhysicsCategory.powerUp
        
        // No physical bounce
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
    }
    
    private func spawnEnemy(wave: String) {
        let count = wave.count
        if count == 0 { return }
        
        // Lock the wave check until all enemies spawned
        pendingEnemies = count
        
        var actions: [SKAction] = []
        
        for char in wave {
            // 1. Wait Action (Random 1 to 2 seconds)
            let waitDuration = Double.random(in: 1.0...2.0)
            let wait = SKAction.wait(forDuration: waitDuration)
            
            // 2. Spawn Action
            let spawn = SKAction.run { [weak self] in
                guard let self = self else { return }
                
                // Random X position at the top
                let randomX = CGFloat.random(in: 30...(self.size.width - 30))
                let spawnY = self.size.height + 50 // Start slightly off screen
                
                // default normal (red)
                var color: UIColor = .red
                var type: Enemy.EnemyBulletType = .normal
                var health = 2
                
                //Type t Scatter (purple)
                if char == "t" {
                    color = .purple
                    type = .scatter
                    health = 5
                }
                
                //Type b Bounce (orange)
                else if char == "b" {
                    color = .orange
                    type = .bounce
                    health = 3
                }
                
                let enemy = Enemy(color: color, size: CGSize(width: 32, height: 32))
                enemy.health = health
                enemy.position = CGPoint(x: randomX, y: spawnY)
                enemy.bulletType = type
                enemy.name = "enemy"
                enemy.zPosition = 5
                
                // Important: Enable AI shooting
                enemy.shootPattern = .blind
                
                // Movement: Slow float down
                enemy.movePattern = .dive
                enemy.hSpeed = 0
                enemy.vSpeed = 30
                
                // Physics
                enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
                enemy.physicsBody?.isDynamic = true
                enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
                enemy.physicsBody?.contactTestBitMask = PhysicsCategory.bullet
                enemy.physicsBody?.collisionBitMask = PhysicsCategory.none
                enemy.physicsBody?.affectedByGravity = false
                
                self.addChild(enemy)
                
                // One enemy spawned, decrease pending count
                self.pendingEnemies -= 1
            }
            
            actions.append(wait)
            actions.append(spawn)
        }
        
        run(SKAction.sequence(actions))
    }
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        let bgm = SKAudioNode(fileNamed: "song.mp3")
                bgm.autoplayLooped = true // looping forever
                bgm.name = "backgroundMusic" //easier to stop it when gameover
                addChild(bgm)
                print("sound: song.mp3")
        
        setupPlayer()
        spawnEnemy(wave: "t")
        sceneWidth = size.width
        sceneHeight = size.height
        setupHearts()
        scoreLabel = setupScoreLabel()
    }
    
    private func setupHearts() {
        
        let bottomPadding: CGFloat = 30    // distance from bottom of screen
        let spacing: CGFloat = 60          // space between hearts
        
        // total width occupied by all hearts (distance between first and last)
        let totalWidth = CGFloat(maxHearts - 1) * spacing
        
        // x of the FIRST heart so that the whole row is centered
        let startX = size.width / 2 - totalWidth / 2
        let y = bottomPadding
        
        for i in 0..<maxHearts {
            let heart = SKSpriteNode(imageNamed: "heart_full")
            heart.setScale(0.05)
            let x = startX + CGFloat(i) * spacing
            heart.position = CGPoint(x: x, y: y)
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
    
    func damagePlayer(by amount: Int = 1) {
        guard currentHearts > 0 else { return }
        currentHearts -= amount
        if currentHearts < 0 {
            currentHearts = 0
        }
        
        updateHearts()
        
        switch currentHearts {
        case 3:
            player.texture = SKTexture(imageNamed: "ship_3") // 3 hp
        case 2:
            player.texture = SKTexture(imageNamed: "ship_2") // 2 hp
        case 1:
            player.texture = SKTexture(imageNamed: "ship_1") // 1 hp
        default:
            // other case hold ship_1 for now
            break
        }
        
        // add an effect for getting damaged
        let fadeOut = SKAction.fadeAlpha(to: 0.5, duration: 0.1)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        player.run(SKAction.sequence([fadeOut, fadeIn, fadeOut, fadeIn]))
        
        if currentHearts == 0 {
            //sound
            run(SKAction.playSoundFileNamed("death.mp3", waitForCompletion: false))
            print("sound: death.mp3")
            
            // Game Over Logic
            triggerGameOver()
        }
    }
    
    func triggerGameOver() {
        // game over
        isGameOver = true
        
        // remove ship
        player.removeFromParent()
        
        // stop bgm when gameover
        if let bgm = childNode(withName: "backgroundMusic") {
            bgm.removeFromParent()
        }
        
        // show GAME OVER
        let goLabel = SKLabelNode(fontNamed: "PressStart2P")
        goLabel.text = "GAME OVER"
        goLabel.fontSize = 40
        goLabel.fontColor = .red
        goLabel.position = CGPoint(x: size.width/2, y: size.height/2 + 20)
        goLabel.zPosition = 1000
        addChild(goLabel)
        
        // show final score
        let finalScoreLabel = SKLabelNode(fontNamed: "PressStart2P")
        finalScoreLabel.text = "Final Score: \(score)"
        finalScoreLabel.fontSize = 24
        finalScoreLabel.fontColor = .white
        finalScoreLabel.position = CGPoint(x: size.width/2, y: size.height/2 - 40)
        finalScoreLabel.zPosition = 1000
        addChild(finalScoreLabel)
        // restart button
        let restartBtn = SKLabelNode(fontNamed: "PressStart2P")
        restartBtn.text = "RESTART"
        restartBtn.fontSize = 30
        restartBtn.fontColor = .yellow
        restartBtn.position = CGPoint(x: size.width/2, y: size.height/2 - 100)
        restartBtn.zPosition = 1000
        restartBtn.name = "restartButton"
        addChild(restartBtn)
        
        // hide the score showing in game
        scoreLabel.isHidden = true
    }
    
    func showGameOverLabel() {
        let label = SKLabelNode(fontNamed: "PressStart2P") // 或者是 "Helvetica-Bold"
        label.text = "GAME OVER"
        label.fontSize = 40
        label.fontColor = .white
        label.position = CGPoint(x: size.width/2, y: size.height/2)
        label.zPosition = 100
        addChild(label)
    }
    
    override func update(_ currentTime: TimeInterval) {
        if isGameOver { return }
        
        let dt : TimeInterval
        if lastUpdateTime == 0 {
            dt = 0
        } else {
            dt = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
        
        for node in children {
            if let enemy = node as? Enemy {
                enemy.updateAI(deltaTime: dt, scene: self)
            }
            if let bullet = node as? Bullet {
                bullet.updateBullet(deltaTime: dt, scene: self)
            }
        }
        
        checkWaveStatus()
        
        // Shoot pause
        if isPausedForShot {
            if currentTime - lastShotTime >= pauseDuration {
                isPausedForShot = false
                if pressHold {
                    shoot()
                    return
                }
            } else {
                return
            }
        }
        
        // Player Movement
        let dx = playerSpeed * CGFloat(dt) * movementDirection
        player.position.x += dx
        
        // bounce at edges
        let halfW = player.size.width * 0.5
        if player.position.x <= halfW {
            player.position.x = halfW
            movementDirection = 1.0
        } else if player.position.x >= size.width - halfW {
            player.position.x = size.width - halfW
            movementDirection = -1.0
        }
        
        
    }
    
    
    func checkWaveStatus() {
        if isSpawning { return } // If already preparing next wave, wait
        
        let enemies = children.filter { $0 is Enemy }
        if enemies.isEmpty && pendingEnemies == 0 {
            isSpawning = true
            
            // Wait 1.5 seconds before starting next wave
            let wait = SKAction.wait(forDuration: 1.5)
            let spawn = SKAction.run { [weak self] in
                self?.startNextWave()
                self?.isSpawning = false
            }
            run(SKAction.sequence([wait, spawn]))
        }
    }
    
    func startNextWave() {
        level += 1
        
        let enemyCount = min(level + 1, 6) // 最多4个，防止太挤
        var waveString = ""
        
        if level % 5 == 0 {
            waveString = "tbt"
        } else {
            // 普通波次：三种怪物概率完全相等 (1/3)
            for _ in 0..<enemyCount {
                // 生成一个 0 到 2 的随机整数
                let roll = Int.random(in: 0...2)
                
                switch roll {
                case 0:
                    waveString += "1" // 普通怪 (红色)
                case 1:
                    waveString += "t" // 散弹怪 (紫色)
                case 2:
                    waveString += "b" // 弹射怪 (橙色)
                default:
                    waveString += "1"
                }
            }
        }
        
        spawnEnemy(wave: waveString)
        print("Starting Level \(level)")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)
        
        if isGameOver {
            for node in tappedNodes {
                if node.name == "restartButton" {
                    restartGame()
                }
            }
            return
        }
        
        pressHold = true
        shoot()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        pressHold = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        pressHold = false
    }
    
    func shoot() {
        
        guard !isPausedForShot else { return }
        isPausedForShot = true
        lastShotTime = CACurrentMediaTime()
        func fireBullet(offsetX: CGFloat, angle: CGFloat) {
            
            let bullet = Bullet(color: .yellow, size: CGSize(width: 25, height: 15))
            bullet.owner = .player
            bullet.damage = 2
            bullet.zPosition = 8
            bullet.position = CGPoint(
                x: player.position.x + offsetX,
                y: player.position.y + player.size.height
            )
            
            let dirX = -sin(angle)
            let dirY = cos(angle)
            
            bullet.direction = normalize(CGPoint(x: dirX, y: dirY))
            
            bullet.zRotation = atan2(bullet.direction.y, bullet.direction.x)
            
            bullet.bulletSpeed = 300
            bullet.acceleration = 0
            
            // Only bounce at high levels
            if playerWeaponLevel >= 4 {
                bullet.bounceCount = 2
            } else {
                bullet.bounceCount = 0
            }
            bullet.bounceCelling = false
            bullet.bounceFloor = false
            
            bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
            bullet.physicsBody?.categoryBitMask = PhysicsCategory.bullet
            bullet.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
            bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
            bullet.physicsBody?.affectedByGravity = false
            bullet.physicsBody?.isDynamic = true
            
            // Add to scene
            addChild(bullet)
        }
        
        switch playerWeaponLevel {
        case 1:
            // Level 1: Single shot straight up
            // 单发，垂直向上
            fireBullet(offsetX: 0, angle: 0)
            
        case 2:
            // Level 2: Double shot, slightly offset left and right
            // 双发，向左和向右轻微偏移
            fireBullet(offsetX: -10, angle: 0)
            fireBullet(offsetX: 10, angle: 0)
            
        case 3:
            // Level 3: Shotgun/Spread (Center + Left Angle + Right Angle)
            // 散弹（中间直射 + 左斜射 + 右斜射）
            fireBullet(offsetX: 0, angle: 0)       // Center / 中
            fireBullet(offsetX: -15, angle: 0.3)   // Left / 左 (~17 degrees)
            fireBullet(offsetX: 15, angle: -0.3)   // Right / 右 (~17 degrees)
            
        default:
            // Max Level / Fallback: 5-way spread
            // 最高等级：5向散弹
            fireBullet(offsetX: 0, angle: 0)
            fireBullet(offsetX: -15, angle: 0.2)
            fireBullet(offsetX: 15, angle: -0.2)
            fireBullet(offsetX: -30, angle: 0.4)
            fireBullet(offsetX: 30, angle: -0.4)
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        // Safe check to fix fatal error
        guard let nodeA = contact.bodyA.node,
              let nodeB = contact.bodyB.node else {
            return
        }
        
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        
        // 1. Player Bullet hits Enemy
        
        if maskA == PhysicsCategory.bullet && maskB == PhysicsCategory.enemy {
            handleHit(bullet: nodeA, enemy: nodeB)
        }
        else if maskB == PhysicsCategory.bullet && maskA == PhysicsCategory.enemy {
            handleHit(bullet: nodeB, enemy: nodeA)
        }
        
        // 2. Player hits PowerUp (Fix for blue box passing through)
        
        else if maskA == PhysicsCategory.player && maskB == PhysicsCategory.powerUp {
            collectPowerUp(playerNode: nodeA, powerUpNode: nodeB)
        }
        else if maskB == PhysicsCategory.player && maskA == PhysicsCategory.powerUp {
            collectPowerUp(playerNode: nodeB, powerUpNode: nodeA)
        }
        
        // 3. Enemy Bullet hits Player (Fix for no damage)
        
        else if maskA == PhysicsCategory.player && maskB == PhysicsCategory.enemyBullet {
            damagePlayer(by: 1)
            nodeB.removeFromParent() // Remove bullet / 移除子弹
        }
        else if maskB == PhysicsCategory.player && maskA == PhysicsCategory.enemyBullet {
            damagePlayer(by: 1)
            nodeA.removeFromParent() // Remove bullet / 移除子弹
        }
    }
    
    func collectPowerUp(playerNode: SKNode, powerUpNode: SKNode) {
        powerUpNode.removeFromParent()
        
        run(SKAction.playSoundFileNamed("powerup.mp3", waitForCompletion: false))
        print("sound：powerup.mp3")
        
        // upgrade weapon
        if playerWeaponLevel < 3 {
            playerWeaponLevel += 1
            print("Weapon Upgraded to level \(playerWeaponLevel)!")
            // can add effects or sound here
        }
        
        // if +HP item
        // damagePlayer(by: -1)
    }
    
    private func handleHit(bullet: SKNode, enemy: SKNode) {
        if let enemy = enemy as? Enemy, let bullet = bullet as?
            Bullet {
            enemy.applyDamage(bullet.damage)
            
            if enemy.health <= 0 {
                enemyDestroyed(enemy)
            }
        }
        bullet.removeFromParent()
    }
    
    func enemyDestroyed(_ enemy: Enemy) {
        score += 100
        scoreLabel.text = "Score: \(score)"
        
        // twenty percent drop a weapon powerup
        if Int.random(in: 0...100) < 20 {
            let powerUp = PowerUp(type: .weaponUpgrade, position: enemy.position)
            addChild(powerUp)
        }
        
        enemy.removeFromParent()
    }
    
    func setupScoreLabel () -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "PressStart2P")
        label.fontSize = 24
        label.zPosition = 100;
        
        label.position = CGPoint(
            x: size.width / 2,
            y: size.height - 60
        )
        label.text = "Score: \(score)"
        addChild(label)
        return label
    }
    
    func restartGame() {
        removeAllChildren()
        
        isGameOver = false
        score = 0
        level = 0
        currentHearts = 3
        playerWeaponLevel = 1
        pendingEnemies = 0
        isSpawning = false
        
        setupPlayer()
        setupHearts()
        scoreLabel = setupScoreLabel()

        spawnEnemy(wave: "11")
    }
}
