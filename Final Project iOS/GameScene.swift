//
//  GameScene.swift
//  Final Project Shared
//
//  Created by user284810 on 11/12/25.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate		 {
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
    
    struct PhysicsCategory {
        static let none: UInt32   = 0
        static let player: UInt32 = 0x1 << 0
        static let bullet: UInt32 = 0x1 << 1
        static let enemy: UInt32  = 0x1 << 2
    }
    
    private func setupPlayer() {
        player = SKSpriteNode(color: .green, size: CGSize(width: 32, height: 32))
        player.position = CGPoint(x: size.width * 0.5, y: player.size.height * 4.0)
        player.zPosition = 10
        addChild(player)
        // static physics body so it can be referenced but not moved by physics engine
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = false
    }
    
    private func spawnEnemy(wave: String) {
        
        // Parse modifiers
        var size = CGSize(width: 32, height: 32)
        var count = 1
        var health = 2
        
        for char in wave {
            switch char {
                
            case "t":
                size = CGSize(width: 64, height: 32)
                health = 3
                
            case "2":
                count = 2
                
            case "3":
                count = 3
                
            default:
                continue
            }
        }
        
        // Compute layout
        let spacing: CGFloat = 10
        let totalWidth = CGFloat(count) * size.width + CGFloat(count - 1) * spacing
        let startX = (self.size.width - totalWidth) * 0.5 + size.width * 0.5
        let y = self.size.height - 100
        
        // Spawn enemie
        for i in 0..<count {
            let x = startX + CGFloat(i) * (size.width + spacing)
            
            let enemy = Enemy(color: .red, size: size)
            enemy.health = health
            enemy.position = CGPoint(x: x, y: y)
            enemy.name = "enemy"
            enemy.zPosition = 5
            enemy.physicsBody = SKPhysicsBody(rectangleOf: size)
            enemy.physicsBody?.isDynamic = false
            enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
            enemy.physicsBody?.contactTestBitMask = PhysicsCategory.bullet
            enemy.physicsBody?.collisionBitMask = PhysicsCategory.none
            // physics bodies may be added later
            addChild(enemy)
        }
    }
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        setupPlayer()
        setupHearts()
        scoreLabel = setupScoreLabel()
        spawnEnemy(wave: "3t")
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
        
        if currentHearts == 0 {
            // Trigger game over
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        let dt : TimeInterval
        if lastUpdateTime == 0 {
            dt = 0
        } else {
            dt = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
        
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
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
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
        
        // pause movement
        isPausedForShot = true
        lastShotTime = CACurrentMediaTime()
        
        // create bullet
        let bullet = Bullet(color: .yellow, size: CGSize(width: 6, height: 20))
        bullet.damage = 2
        bullet.position = CGPoint(x: player.position.x, y: player.position.y + player.size.height)
        bullet.zPosition = 8
        
        // physics body for collision
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.bullet
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.isDynamic = true
        
        addChild(bullet)
        
        // bullet movement
        let moveUp = SKAction.moveBy(x: 0, y: size.height, duration: 1.0)
        let remove = SKAction.removeFromParent()
        bullet.run(.sequence([moveUp, remove]))
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let first = contact.bodyA
        let second = contact.bodyB

        // sort so first is always bullet if present
        let bodyA = first.categoryBitMask
        let bodyB = second.categoryBitMask

        if bodyA == PhysicsCategory.bullet && bodyB == PhysicsCategory.enemy {
            handleHit(bullet: first.node!, enemy: second.node!)
        }
        else if bodyA == PhysicsCategory.enemy && bodyB == PhysicsCategory.bullet {
            handleHit(bullet: second.node!, enemy: first.node!)
        }
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
}
