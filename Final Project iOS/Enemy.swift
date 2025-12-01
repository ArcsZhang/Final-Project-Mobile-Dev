//
//  Enemy.swift
//  Final Project iOS
//
//  Created by user284810 on 11/16/25.
//

import SpriteKit

class Enemy: SKSpriteNode {
    enum EnemyEntry {
        case top
        case left
        case right
        case none
    }
    
    enum EnemyMovementPattern {
        case none
        case zigzag
        case dive
        case retreat
        case chase
    }
    
    enum EnemyShootPattern {
        case none
        case blind
        case detectForward
        case aimAtPlayer
        case diagonal
    }
    
    enum EnemyBulletType {
        case none
        case normal
        case scatter
        case laser
        case bounce
        case gravity
    }
    
    var health: Int = 2
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
    
    func applyDamage(_ amount: Int) {
        health -= amount
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
        switch entry {
        case .none:
            entered = true
        default:
            entered = true
        }
    }
    
    func move (deltaTime: TimeInterval, scene: GameScene) {
        let halfW = size.width * 0.5
        let halfH = size.height * 0.5
        switch movePattern {
        case .none:
            return
        case .zigzag:
            let dx = hSpeed * deltaTime * hDirection
            position.x += dx
            position.y -= vSpeed * deltaTime
            vSpeed += acceleration * deltaTime
            
            // bounce at edges
            if position.x <= halfW {
                position.x = halfW
                hDirection = 1.0
            } else if position.x >= scene.size.width - halfW {
                position.x = scene.size.width - halfW
                hDirection = -1.0
            }
        case .dive:
            position.y -= vSpeed * deltaTime
            vSpeed += acceleration * deltaTime
        case .chase:
            let player = scene.player!
            if player.position.x > position.x {
                position.x += min(hSpeed * deltaTime, player.position.x - position.x)
            } else if player.position.x < position.x{
                position.x -= min(hSpeed * deltaTime, position.x - player.position.x)
            }
            position.y -= vSpeed * deltaTime
            vSpeed += acceleration * deltaTime
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
        // Create bullet
        let b = Bullet(color: .red, size: CGSize(width: 15, height: 15))
        b.owner = .enemy
        b.position = self.position
        b.zPosition = 8
        
            b.direction = direction
            b.bulletSpeed = speed
            b.zRotation = atan2(direction.y, direction.x)
            
            // Physics Body (CRITICAL: Without this, player won't take damage)
            // 关键：必须设置物理体，否则无法碰撞检测
            b.physicsBody = SKPhysicsBody(rectangleOf: b.size)
            b.physicsBody?.categoryBitMask = GameScene.PhysicsCategory.enemyBullet // distinct category
            b.physicsBody?.contactTestBitMask = GameScene.PhysicsCategory.player
            b.physicsBody?.collisionBitMask = GameScene.PhysicsCategory.none
            b.physicsBody?.affectedByGravity = false
            b.physicsBody?.isDynamic = true
            
            // Bounce logic
            if isBounce {
                b.bounceCount = 2 // bounce 2 times
                b.bounceFloor = false // Don't bounce off bottom (game over line)
            } else {
                b.bounceCount = 0
            }
            
            scene.addChild(b)
        }
        
        // Logic based on Enemy Type
        switch bulletType {
        case .scatter:
            // Shotgun: 3 bullets (Left, Center, Right)
            // 散弹：左中右三发
            fireEnemyBullet(direction: scene.normalize(CGPoint(x: 0, y: -1)), speed: 90)     // Center
            fireEnemyBullet(direction: scene.normalize(CGPoint(x: -0.3, y: -1)), speed: 90)  // Left
            fireEnemyBullet(direction: scene.normalize(CGPoint(x: 0.3, y: -1)), speed: 90)   // Right
            
        case .bounce:
            // Bouncing bullet: Shoots diagonally
            // 弹射：随机向左下或右下发射
            let dirX: CGFloat = Bool.random() ? 0.5 : -0.5
            fireEnemyBullet(direction: scene.normalize(CGPoint(x: dirX, y: -1)), speed: 110, isBounce: true)
            
        default: // .normal or others
            // Straight down
            // 普通：垂直向下
            fireEnemyBullet(direction: CGPoint(x: 0, y: -1), speed: 100)
        }
    }
    
    func startChargeUp () {
        guard chargeEffect == nil else { return }
        
        let glow = SKShapeNode(circleOfRadius: max(size.width, size.height) * 0.6)
        glow.strokeColor = .yellow
        glow.lineWidth = 4
        glow.alpha = 0.0
        glow.zPosition = -1
        
        addChild(glow)
        chargeEffect = glow
        
        // Animate glow pulsing
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
