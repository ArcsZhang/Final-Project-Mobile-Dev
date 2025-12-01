//
//  PowerUp.swift
//  Final Project iOS
//
//  Created by ron on 11/30/25.
//

import SpriteKit

class PowerUp: SKSpriteNode {
    enum PowerType {
        case weaponUpgrade
        case heal
    }
    
    var type: PowerType = .weaponUpgrade
    
    init(type: PowerType, position: CGPoint) {
        let color: UIColor = type == .weaponUpgrade ? .cyan : .systemPink
        
        super.init(texture: nil, color: color, size: CGSize(width: 30, height: 30))
        self.position = position
        self.name = "powerup"
        self.zPosition = 8
        
        // Physics Setup
        self.physicsBody = SKPhysicsBody(circleOfRadius: 15)
        self.physicsBody?.categoryBitMask = GameScene.PhysicsCategory.powerUp
        self.physicsBody?.contactTestBitMask = GameScene.PhysicsCategory.player
        self.physicsBody?.collisionBitMask = GameScene.PhysicsCategory.none
        self.physicsBody?.isDynamic = true
        self.physicsBody?.affectedByGravity = false
        
        // Movement
        let moveAction = SKAction.moveBy(x: 0, y: -1000, duration: 10)
        let removeAction = SKAction.removeFromParent()
        self.run(SKAction.sequence([moveAction, removeAction]))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
