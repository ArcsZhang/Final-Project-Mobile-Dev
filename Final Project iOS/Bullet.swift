//
//  Bullet.swift
//  Final Project iOS
//
//  Created by user284810 on 11/16/25.
//

import SpriteKit

class Bullet: SKSpriteNode {
    enum Owner {
        case player
        case enemy
        case neutral
        case none
    }
    
    var damage: Int = 2
    
    var direction: CGPoint	 = .zero
    var gravity: CGFloat = 0 // TODO
    var bulletSpeed: CGFloat = 0
    var maxSpeed: CGFloat = 600
    var minSpeed: CGFloat = 0
    var acceleration: CGFloat = 0

    var owner: Owner = .none
    
    var bounceCount: Int = 0 // 0 = can't bounce, n = bounce number, -1 = infinite bounce
    var bounceFloor = false
    var bounceCelling = false
    var isLaser = false
    
    func updateBullet (deltaTime: TimeInterval, scene: GameScene) {
        position.x += direction.x * bulletSpeed * deltaTime
        position.y += direction.y * bulletSpeed * deltaTime
        
        if bulletSpeed != maxSpeed || bulletSpeed != minSpeed {
            bulletSpeed += acceleration * deltaTime
        }
        if bulletSpeed > maxSpeed {
            bulletSpeed = maxSpeed
        }
        if bulletSpeed < minSpeed {
            bulletSpeed = minSpeed
        }
        
        if bounceCount != 0 {
            if position.x < 0 {
                position.x = -position.x
                direction.x *= -1
                zRotation = atan2(direction.y, direction.x)
            }
            if position.x > scene.size.width {
                position.x = scene.size.width - (position.x - scene.size.width)
                direction.x *= -1
                zRotation = atan2(direction.y, direction.x)
            }
            if position.y < 0 {
                if bounceFloor {
                    position.y = -position.y
                    direction.y *= -1
                    zRotation = atan2(direction.y, direction.x)
                    bounceCount -= 1
                    if bounceCount == 0 {
                        removeFromParent()
                    }
                } else {
                    removeFromParent()
                }
            }
            if position.y > scene.size.height {
                if bounceCelling {
                    position.y = scene.size.height - (position.y - scene.size.height)
                    direction.y *= -1
                    zRotation = atan2(direction.y, direction.x)
                    bounceCount -= 1
                    if bounceCount == 0 {
                        removeFromParent()
                    }
                } else {
                    removeFromParent()
                }
            }
        } else {
            if position.y > scene.size.height || position.y < 0 || position.x > scene.size.width || position.x < 0 {
                removeFromParent()
            }
        }
    }
}
