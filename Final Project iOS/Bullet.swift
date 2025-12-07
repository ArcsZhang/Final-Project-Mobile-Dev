//
//  Bullet.swift
//  Final Project iOS
//
//  Created by user284810 on 11/16/25.
//

import SpriteKit

class Bullet: SKSpriteNode {
    enum Owner {
        case player, enemy, neutral, none
    }
    
    var damage: Int = 2
    var direction: CGPoint = .zero
    var bulletSpeed: CGFloat = 0
    var maxSpeed: CGFloat = 600
    var minSpeed: CGFloat = 0
    var acceleration: CGFloat = 0
    
    var owner: Owner = .none
    
    var bounceCount: Int = 0
    var bounceFloor = false
    var bounceCelling = false
    
    // NEW: Init with Texture (for animated bullets)
    init(texture: SKTexture?, size: CGSize) {
        super.init(texture: texture, color: .white, size: size)
        setupDefaults()
    }
    
    // KEEP: Old Init with Color (for enemy bullets or simple shapes)
    init(color: UIColor, size: CGSize) {
        super.init(texture: nil, color: color, size: size)
        setupDefaults()
    }
    
    private func setupDefaults() {
        // Common setup if any
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateBullet (deltaTime: TimeInterval, scene: GameScene) {
        position.x += direction.x * bulletSpeed * deltaTime
        position.y += direction.y * bulletSpeed * deltaTime
        
        if bulletSpeed != maxSpeed || bulletSpeed != minSpeed {
            bulletSpeed += acceleration * deltaTime
        }
        
        // Bounce Logic
        if bounceCount != 0 {
            if position.x < 0 {
                position.x = -position.x
                direction.x *= -1
                zRotation = atan2(direction.y, direction.x) - .pi/2
            }
            if position.x > scene.size.width {
                position.x = scene.size.width - (position.x - scene.size.width)
                direction.x *= -1
                zRotation = atan2(direction.y, direction.x) - .pi/2
            }
            if position.y < 0 {
                if bounceFloor {
                    position.y = -position.y
                    direction.y *= -1
                    zRotation = atan2(direction.y, direction.x) - .pi/2
                    bounceCount -= 1
                    if bounceCount == 0 { removeFromParent() }
                } else { removeFromParent() }
            }
            if position.y > scene.size.height {
                if bounceCelling {
                    position.y = scene.size.height - (position.y - scene.size.height)
                    direction.y *= -1
                    zRotation = atan2(direction.y, direction.x) - .pi/2
                    bounceCount -= 1
                    if bounceCount == 0 { removeFromParent() }
                } else { removeFromParent() }
            }
        } else {
            // Remove if off screen
            if position.y > scene.size.height || position.y < 0 || position.x > scene.size.width || position.x < 0 {
                removeFromParent()
            }
        }
    }
}
