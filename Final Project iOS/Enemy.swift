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
    var shootCooldown: CGFloat = 2.0
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
        if health <= 0 {
            removeFromParent()
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
        // Create bullet
        let b = Bullet(color: .red, size: CGSize(width: 20, height: 10))
        b.owner = .enemy
        b.position = self.position
        b.direction = scene.normalize(CGPoint(x: 0, y: -1))  // straight down
        b.bulletSpeed = 200
        b.zRotation = atan2(b.direction.y, b.direction.x)
        
        scene.addChild(b)
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
