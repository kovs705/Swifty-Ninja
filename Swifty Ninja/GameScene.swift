//
//  GameScene.swift
//  Swifty Ninja
//
//  Created by Kovs on 11.12.2022.
//

import SpriteKit
import AVFoundation
import GameplayKit

enum SequenceType: CaseIterable {
    case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
}

enum ForceBomb {
    case never, always, random
}

// MARK: - GameScene
class GameScene: SKScene {
    
    // MARK: - properties for sequence:
    var popupTime = 0.9
    var sequence = [SequenceType]()
    var sequencePosition = 0      // where are we right now in the game
    var chainDelay = 3.0          // how long to wait before the new enemy creation
    var nextSequenceQueued = true // property to know when all enemies are destroyed and we're ready to reate more
    
    // MARK: - other properties
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    
    var gameScore: SKLabelNode!
    var score = 0 {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }
    
    var isGameEnded = false
    
    var livesImages = [SKSpriteNode]()
    var lives = 3
    
    // store enemies:
    var activeEnemies = [SKSpriteNode]()
    
    // sound:
    var bombSoundEffect: AVAudioPlayer?
    
    // store swipe points:
    var activeSlicePoints = [CGPoint]()
    var isSwooshSoundActive = false
    
    // MARK: - didMove
    override func didMove(to view: SKView) {
        
        let background = SKSpriteNode(fileNamed: "sliceBackground")!
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        
        addChild(background)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        physicsWorld.speed = 0.85
        
        createScore()
        createLives()
        createSlices()
        
        // MARK: - Sequence
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        
        for _ in 0 ... 1000 { // ... means up to and including (so it can be 1001, 1002..
            if let nextSequence = SequenceType.allCases.randomElement() {
                sequence.append(nextSequence)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.tossEnemies()
        }
        
    }
    
    
    // MARK: - update method:
    override func update(_ currentTime: TimeInterval) {
        var bombCount = 0
        
        if activeEnemies.count > 0 {
            for (index, node) in activeEnemies.enumerated().reversed() {
                if node.position.y < -140 {
                    node.removeAllActions()
                    
                    if node.name == "enemy" {
                        node.name = ""
                        substractLife()
                        
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    }
                    
                    
                }
            }
        } else { // if it's less or equals 0
            if !nextSequenceQueued {
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) { [weak self] in
                    self?.tossEnemies()
                }
                
                nextSequenceQueued = true
            }
        }
        
        
        for node in activeEnemies {
            if node.name == "bombContainer" {
                bombCount += 1
                break
            }
        }
        
        if bombCount == 0 {
            // no bombs == stop the fuse sound!
            bombSoundEffect?.stop()
            bombSoundEffect = nil
        }
        
    }
    
    
    // MARK: - Enemies:
    func createEnemy(forceBomb: ForceBomb = .random) {
        let enemy: SKSpriteNode
        
        var enemyType = Int.random(in: 0...6)
        
        if forceBomb == .never {
            enemyType = 1
        } else if forceBomb == .always {
            enemyType = 0
        }
        
        if enemyType == 0 {
            // MARK: create a bomb:
            
            //1
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            
            // 2
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage)
            
            // 3
            if bombSoundEffect != nil {
                bombSoundEffect?.stop()
                bombSoundEffect = nil
            }
            
            // 4
            if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf") {
                if let sound = try? AVAudioPlayer(contentsOf: path) {
                    bombSoundEffect = sound
                    sound.play()
                }
            }
            
            // 5
            if let emitter = SKEmitterNode(fileNamed: "sliceFuse") {
                emitter.position = CGPoint(x: 76, y: 64)
                enemy.addChild(emitter)
            }
            
        } else {
            
            // MARK: - create a penguin:
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"
        }
        
        // create a directory and position for future enemies and bombs:
        let randomPosition = CGPoint(x: Int.random(in: 64...960), y: -128)
        enemy.position = randomPosition
        
        // speed of the enemies spinning:
        let randomAngularVelocity = CGFloat.random(in: -3...3)
        
        // how far to move horizontally:
        let randomXVelocity: Int
        
        if randomPosition.x < 256 {
            randomXVelocity = Int.random(in: 9...15)
        } else if randomPosition.x < 512 {
            randomXVelocity = Int.random(in: 3...5)
        } else if randomPosition.x < 768 {
            randomXVelocity = -Int.random(in: 3...5)
        } else {
            randomXVelocity = -Int.random(in: 8...15)
        }
        
        // Make enemies fly higly at different speeds:
        let randomYVelocity = Int.random(in: 24...32)
        
        // Give every enemy a physics of the ball and delete the abillity to collide:
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        
        enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody?.angularVelocity = randomAngularVelocity
        
        enemy.physicsBody?.collisionBitMask = 0
        
        addChild(enemy)
        activeEnemies.append(enemy)
        
    }
    
    // MARK: - createScore
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        
        addChild(gameScore)
        
        gameScore.position = CGPoint(x: 8, y: 8)
        score = 0
    }
    
    // MARK: - createLives
    func createLives() {
        for i in 0 ..< 3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            
            livesImages.append(spriteNode)
        }
    }
    
    // MARK: - createSlices
    func createSlices() {
        activeSliceBG = SKShapeNode()
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 3
        
        activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBG.lineWidth = 9
        
        activeSliceFG.strokeColor = UIColor.white
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }
    
    
    // MARK: - Touches and Swipes
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        /// remove all existing points cause we are starting fresh
        activeSlicePoints.removeAll(keepingCapacity: true)
        
        /// get the touch location and add it to the activeSlicePoints
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        
        /// call redrawActiveSlice() to clear the slice shapes
        redrawActiveSlice()
        /// remove any actions that are currently attached to the slice shapes
        activeSliceBG.removeAllActions()
        activeSliceFG.removeAllActions()
        
        /// set both slice shapes to have an alpha value of 1 to make them fully visible
        activeSliceBG.alpha = 1
        activeSliceFG.alpha = 1
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if isGameEnded {
            return
        }
        
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        redrawActiveSlice()
        if !isSwooshSoundActive {
            playSwooshSound()
        }
        
        // MARK: - slicing enemies:
        let nodesAtPoint = nodes(at: location)
        
        for case let node as SKSpriteNode in nodesAtPoint {
            if node.name == "enemy" {
                // destroy this penguin
                destroyPenguin(node: node)
            } else if node.name == "bomb" {
                // destroy the bomb and GAME OVER
                destroyBomb(node: node)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    func redrawActiveSlice() {
        // 1
        if activeSlicePoints.count < 2 {
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }
        
        // 2
        if activeSlicePoints.count > 12 {
            activeSlicePoints.removeFirst(activeSlicePoints.count - 12) // first point
        }
        
        // 3
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])
        
        for i in 1 ..< activeSlicePoints.count {
            path.addLine(to: activeSlicePoints[i])
        }
        
        // 4
        activeSliceBG.path = path.cgPath
        activeSliceFG.path = path.cgPath
    }
    
    // MARK: - Play sound
    func playSwooshSound() {
        isSwooshSoundActive = true
        
        let randomNumber = Int.random(in: 1...3)
        let soundName = "swoosh\(randomNumber).caf"
        
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        
        run(swooshSound) { [weak self] in
            self?.isSwooshSoundActive = false
        }
    }
    
    // MARK: - Enemies and Bombs
    func tossEnemies() {
        
        if isGameEnded {
            return
        }
        
        popupTime *= 0.991 // get's faster
        chainDelay *= 0.99 // delay between enemies in the chain
        physicsWorld.speed *= 1.02
        
        let sequenceType = sequence[sequencePosition]
        
        switch sequenceType {
            
        case .oneNoBomb:
            createEnemy(forceBomb: .never)
            
        case .one:
            createEnemy()
            
        case .twoWithOneBomb:
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
            
        case .two:
            createEnemy()
            createEnemy()
            
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .chain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) { [weak self] in
                self?.createEnemy()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) { [weak self] in
                self?.createEnemy()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) { [weak self] in
                self?.createEnemy()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) { [weak self] in
                self?.createEnemy()
            }
            
        case .fastChain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) { [weak self] in
                self?.createEnemy()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) { [weak self] in
                self?.createEnemy()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) { [weak self] in
                self?.createEnemy()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) { [weak self] in
                self?.createEnemy()
            }
            
        } // end of switch
        
        sequencePosition += 1
        nextSequenceQueued = false
        
    }
    // MARK: - destroy penguin
    func destroyPenguin(node: SKSpriteNode) {
        // create a particle effect:
        if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy") {
            emitter.position = node.position
            addChild(emitter)
        }
        
        // clear its name to avoid repeated slicing:
        node.name = ""
        
        // delete isDynamic:
        node.physicsBody?.isDynamic = false
        
        // scale out and fade out at the same time:
        let scaleOut = SKAction.scale(by: 0.001, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([scaleOut, fadeOut])
        
        // remove the penguin from the scene:
        let seq = SKAction.sequence([group, .removeFromParent()])
        node.run(seq)
        
        // add 1 to score:
        score += 1
        
        // remove the enemy from the activeEnemies array:
        if let index = activeEnemies.firstIndex(of: node) {
            activeEnemies.remove(at: index)
        }
        
        // play a sound:
        run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
    }
    
    // MARK: - destroy bomb
    
    func destroyBomb(node: SKSpriteNode) {
        guard let bombContainer = node.parent as? SKSpriteNode else { return }
        
        if let emitter = SKEmitterNode(fileNamed: "sliceHitBomb") {
            emitter.position = bombContainer.position
            addChild(emitter)
        }
        
        node.name = ""
        bombContainer.physicsBody?.isDynamic = false
        
        let scaleOut = SKAction.scale(by: 0.001, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([scaleOut, fadeOut])
        
        let seq = SKAction.sequence([group, .removeFromParent()])
        bombContainer.run(seq)
        
        if let index = activeEnemies.firstIndex(of: node) {
            activeEnemies.remove(at: index)
        }
        
        run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
        endGame(triggeredByBomb: true)
    }
    
    // MARK: - Game Over
    func endGame(triggeredByBomb: Bool) {
        if isGameEnded {
            return
        }
        
        isGameEnded = true
        physicsWorld.speed = 0
        isUserInteractionEnabled = false
        
        bombSoundEffect?.stop()
        bombSoundEffect = nil
        
        if triggeredByBomb {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }
    }
    
    // MARK: - Substract life
    func substractLife() {
        lives -= 1
        
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        
        var life: SKSpriteNode
        
        if lives == 2 {
            life = livesImages[0]
        } else if lives == 1 {
            life = livesImages[1]
        } else {
            life = livesImages[2]
            endGame(triggeredByBomb: false)
        }
        
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        
        life.xScale = 1.3
        life.yScale = 1.3
        
        // and go the scale back to normal:
        run(SKAction.scale(to: 1, duration: 0.1))
        
    }
    
}
