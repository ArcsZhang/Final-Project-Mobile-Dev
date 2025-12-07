//
//  Enemy.swift
//  Final Project iOS
//
//  Created by user284810 on 11/16/25.
//

import SpriteKit

class Enemy: SKSpriteNode {
    enum EnemyEntry {
        case top, left, right, none
    }
    
    enum EnemyMovementPattern {
        case none, zigzag, dive, retreat, chase
    }
    
    enum EnemyShootPattern {
        case none, blind, detectForward, aimAtPlayer, diagonal
    }
    
    enum EnemyBulletType {
        case none, normal, scatter, laser, bounce, gravity
    }
    
    // --- Stats ---
    var health: Int = 200
    var maxHealth: Int = 200 // Added: To calculate percentage
    
    // --- State ---
    var entry: EnemyEntry = .none
    var entered: Bool = false
    var movePattern: EnemyMovementPattern = .none
    var shootPattern: EnemyShootPattern = .none
    var bulletType: EnemyBulletType = .none
    var shootCooldown: CGFloat = 4.0
    var shootTimer: CGFloat = 0.0
    var shootCharge: CGFloat = 0.5
    var chargeTimer: CGFloat = 0.0
    var chargeEffect: SKNode?
    var charging: Bool = false
    
    var hSpeed: CGFloat = 0.0
    var vSpeed: CGFloat = 0.0
    var acceleration: CGFloat = 0.0
    var hDirection: CGFloat = 1.0 // 1 right -1 left
    
    // --- Visuals ---
    var healthBar: SKSpriteNode? // The red bar
    
    var deviceScale: CGFloat = 1.0
    
    // --- Methods ---
    
    // Setup the health bar visual
    func setupHealthBar() {
        // Capture initial health as max
        self.maxHealth = health
        
        // 1. Background Bar (Black)
        let barSize = CGSize(width: 40 * deviceScale, height: 5 * deviceScale)
        let bg = SKSpriteNode(color: .black, size: barSize)
        // Position: Above the enemy
        bg.position = CGPoint(x: 0, y: self.size.height / 2)
        bg.zPosition = 50 // High Z to be visible
        addChild(bg)
        
        // 2. Foreground Bar (Red)
        healthBar = SKSpriteNode(color: .red, size: barSize)
        // Anchor Point (0, 0.5) means it shrinks from right to left
        healthBar?.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthBar?.position = CGPoint(x: -barSize.width / 2, y: self.size.height / 2)
        healthBar?.zPosition = 51 // Above background
        addChild(healthBar!)
    }
    
    func applyDamage(_ amount: Int) {
        health -= amount
        if health < 0 { health = 0 }
        
        // Update bar width based on percentage
        if let bar = healthBar, maxHealth > 0 {
            let percentage = CGFloat(health) / CGFloat(maxHealth)
            bar.xScale = percentage
        }
    }
    
    func updateAI (deltaTime: TimeInterval, scene: GameScene) {
        if !entered {
            enter(deltaTime: deltaTime, scene: scene)
        } else {
            move(deltaTime: deltaTime, scene: scene)
            shootLogic(deltaTime: deltaTime, scene: scene)
        }
    }
    
    func enter (deltaTime: TimeInterval, scene: GameScene) {
        entered = true
    }
    
    func move (deltaTime: TimeInterval, scene: GameScene) {
        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        switch movePattern {
        case .none:
            return
        case .zigzag:
            let dx = hSpeed * deltaTime * hDirection * deviceScale
            position.x += dx
            position.y -= vSpeed * deltaTime * deviceScale
            vSpeed += acceleration * deltaTime * deviceScale
            
            if position.x <= halfW {
                position.x = halfW
                hDirection = 1.0
            } else if position.x >= scene.size.width - halfW {
                position.x = scene.size.width - halfW
                hDirection = -1.0
            }
        case .dive:
            position.y -= vSpeed * deltaTime * deviceScale
            vSpeed += acceleration * deltaTime * deviceScale
        case .chase:
            if let player = scene.player {
                if player.position.x > position.x {
                    position.x += min(hSpeed * deltaTime * deviceScale, player.position.x - position.x)
                } else if player.position.x < position.x{
                    position.x -= min(hSpeed * deltaTime * deviceScale, position.x - player.position.x)
                }
            }
            position.y -= vSpeed * deltaTime * deviceScale
            vSpeed += acceleration * deltaTime * deviceScale
        default:
            return
        }
        if position.y < -halfH {
            removeFromParent()
        }
    }
    
    func shootLogic (deltaTime: TimeInterval, scene: GameScene) {
        shootTimer -= deltaTime
        if shootTimer > 0 { return }
        if charging {
            if chargeTimer <= 0{
                stopChargeEffect()
                shoot(deltaTime: deltaTime, scene: scene)
                charging = false
            } else {
                chargeTimer -= deltaTime
            }
            return
        }
        
        switch shootPattern {
        case .none:
            return
        case .blind:
            if !charging {
                charging = true
                chargeTimer = shootCharge
                startChargeUp()
            }
        default:
            return
        }
    }
    
    func shoot (deltaTime: TimeInterval, scene: GameScene) {
        shootTimer = shootCooldown
        chargeTimer = 0
        charging = false
        
        func fireEnemyBullet(direction: CGPoint, speed: CGFloat, isBounce: Bool = false) {
            let b = Bullet(color: .red, size: CGSize(width: 15 * deviceScale, height: 15 * deviceScale))
            b.owner = .enemy
            b.position = self.position
            b.zPosition = 8
            
            b.direction = direction
            b.bulletSpeed = speed * deviceScale
            b.zRotation = atan2(direction.y, direction.x)
            
            b.physicsBody = SKPhysicsBody(rectangleOf: b.size)
            b.physicsBody?.categoryBitMask = GameScene.PhysicsCategory.enemyBullet
            b.physicsBody?.contactTestBitMask = GameScene.PhysicsCategory.player
            b.physicsBody?.collisionBitMask = GameScene.PhysicsCategory.none
            b.physicsBody?.affectedByGravity = false
            b.physicsBody?.isDynamic = true
            
            if isBounce {
                b.color = .purple
                b.bounceCount = 2
                b.bounceFloor = false
            } else {
                b.bounceCount = 0
            }
            
            scene.addChild(b)
        }
        
        switch bulletType {
        case .scatter:
            fireEnemyBullet(direction: scene.normalize(CGPoint(x: 0, y: -1)), speed: 90)
            fireEnemyBullet(direction: scene.normalize(CGPoint(x: -0.3, y: -1)), speed: 90)
            fireEnemyBullet(direction: scene.normalize(CGPoint(x: 0.3, y: -1)), speed: 90)
            
        case .bounce:
            let dirX: CGFloat = Bool.random() ? 0.5 : -0.5
            fireEnemyBullet(direction: scene.normalize(CGPoint(x: dirX, y: -1)), speed: 110, isBounce: true)
            
        default:
            fireEnemyBullet(direction: CGPoint(x: 0, y: -1), speed: 100)
        }
    }
    
    func startChargeUp () {
        guard chargeEffect == nil else { return }
        
        let glow = SKShapeNode(circleOfRadius: max(size.width, size.height) * 0.4)
        glow.strokeColor = .yellow
        glow.lineWidth = 4
        glow.alpha = 0.0
        glow.zPosition = -1
        
        addChild(glow)
        chargeEffect = glow
        
        let fadeIn = SKAction.fadeAlpha(to: 0.8, duration: 0.1)
        let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 0.1)
        let pulse = SKAction.repeatForever(SKAction.sequence([fadeIn, fadeOut]))
        glow.run(pulse)
    }
    
    func stopChargeEffect() {
        chargeEffect?.removeAllActions()
        chargeEffect?.removeFromParent()
        chargeEffect = nil
    }
}
