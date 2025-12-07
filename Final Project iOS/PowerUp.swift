//
//  PowerUp.swift
//  Final Project iOS
//
//  Created by ron on 11/30/25.
//

import SpriteKit

class PowerUp: SKSpriteNode {
    
    enum PowerType {
        case shield // Blue/Cyan
        case heal   // Blue/Cyan
        case berserk // New: Berserk Mode (Red/Purple)
    }
    
    var type: PowerType
    
    init(type: PowerType, position: CGPoint, deviceScale: CGFloat) {
        self.type = type
        
        // Set color based on type for visual distinction
        let color: UIColor
        switch type {
        case .shield:
            color = .cyan
        case .heal:
            color = .green
        case .berserk:
            color = .magenta // New: Berserk uses magenta for visibility
        }
        
        // Large hitbox for easy collection
        super.init(texture: nil, color: color, size: CGSize(width: 30 * deviceScale, height: 30 * deviceScale))
        
        self.position = position
        self.name = "powerup"
        self.zPosition = 8
        
        self.physicsBody = SKPhysicsBody(circleOfRadius: 45 * deviceScale)
        self.physicsBody?.categoryBitMask = GameScene.PhysicsCategory.powerUp
        self.physicsBody?.contactTestBitMask = GameScene.PhysicsCategory.player
        self.physicsBody?.collisionBitMask = GameScene.PhysicsCategory.none
        self.physicsBody?.isDynamic = true
        self.physicsBody?.affectedByGravity = false
        
        // Increase falling speed slightly for urgency
        let moveAction = SKAction.moveBy(x: 0, y: -1200 * deviceScale, duration: 10)
        let removeAction = SKAction.removeFromParent()
        self.run(SKAction.sequence([moveAction, removeAction]))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
