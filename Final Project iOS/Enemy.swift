//
//  Enemy.swift
//  Final Project iOS
//
//  Created by user284810 on 11/16/25.
//

import SpriteKit

class Enemy: SKSpriteNode {
    var health: Int = 2

    func applyDamage(_ amount: Int) {
        health -= amount
        if health <= 0 {
            removeFromParent()
        }
    }
}
