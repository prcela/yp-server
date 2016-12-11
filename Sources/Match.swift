//
//  TimedMatch.swift
//  VaporApp
//
//  Created by Kresimir Prcela on 07/09/16.
//
//

import Foundation

enum MatchState: String
{
    case WaitingForPlayers = "Waiting"
    case Playing = "Playing"
    case Finished = "Finished"
}

private var matchIdCounter: Int = 0

class Match
{
    var id: Int
    var state:MatchState = .WaitingForPlayers
    var players = [Player]()
    var diceMaterials: [String] = ["a","b"]
    var diceNum: Int = 6
    var bet: Int = 0
    var isPrivate = false
    
    init()
    {
        matchIdCounter += 1
        id = matchIdCounter
    }
    
    func dic() -> [String:Any]
    {
        return ["id":id,
                     "name":"proba",
                     "state":state.rawValue,
                     "bet":bet,
                     "private":isPrivate,
                     "players":players.map({ $0.id }),
                     "dice_num":diceNum,
                     "dice_materials": diceMaterials ]
    }
    
    // send to all in match
    func send(_ dic: [String:Any], ttl: TimeInterval = 15)
    {
        print("match send")
        for player in players
        {
            print("pplayer send json ttl")
            player.send(dic: dic, ttl: ttl)
        }
    }
    
    // send to all others in match
    func sendOthers(fromPlayerId: String, dic: [String:Any])
    {
        for player in players
        {
            if player.id != fromPlayerId
            {
                player.send(dic: dic)
            }
        }
    }
    
    func clean() -> Bool
    {
        let now = Date()
        var anyDumped = false
        
        func dump(_ p: Player)
        {
            // dump the player
            print("Player dumped")
            p.sentMessages.removeAll()
            let dic = ["msg_func":"dump", "id":p.id, "match_id":id] as [String : Any]
            send(dic, ttl: 3600) // one hour
            anyDumped = true
        }
        
        func willBeDumped(_ p: Player)
        {
            // send to all that player may be dumped soon
            print("Player will be dumped soon")
            let dic: [String:Any] = ["msg_func":"maybe_someone_will_dump", "id":p.id, "match_id":id]
            sendOthers(fromPlayerId: p.id, dic: dic)
        }
        
        for p in players
        {
            if !p.sentMessages.isEmpty || !p.connected
            {
                
                if let lastShortMsg = p.sentMessages.filter({ (msg) -> Bool in
                    return msg.ttl < 20
                }).last
                {
                    if lastShortMsg.timestamp.addingTimeInterval(20) < now
                    {
                        print("player last message older than 20s")
                        dump(p)
                    }
                    else if lastShortMsg.timestamp.addingTimeInterval(10) < now
                    {
                        print("player last message older than 10s")
                        willBeDumped(p)
                    }
                }
                
                if let disconnectedAt = p.disconnectedAt
                {
                    if disconnectedAt.addingTimeInterval(20) < now
                    {
                        print("player disconnected longer than 20s")
                        dump(p)
                    }
                    else if disconnectedAt.addingTimeInterval(5) < now
                    {
                        print("player disconnected longer than 5s")
                        willBeDumped(p)
                    }
                }
            }
            
            p.deleteExpiredMessages()
        }
        return anyDumped
    }
}
