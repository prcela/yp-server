import Foundation
import PerfectWebSockets

class Room
{
    static let main = Room()
    
    var connections: [String: WebSocket]
    var matches = [Match]()
    
    init() {
        connections = [:]
    }
    
    func join(dic: [String:Any], ws: WebSocket) throws -> Player?
    {
        guard let id = dic["id"] as? String,
            let _ = dic["alias"] as? String
            else { return nil }
            
        var player = Player.all[id]
        
        if player == nil
        {
            // instantiate new player
            player = Player(dic: dic)
            Player.all[player!.id] = player!
            try playersCollection.insert(player!.document())
        }
        player?.connected = true
        player?.disconnectedAt = nil
        
        connections[id] = ws
        
        player?.deleteExpiredMessages()
        player?.sendUnsentMessages()
        
        // send room info to all
        sendInfo()
        return player
    }

    func createMatch(dic: [String:Any], player: Player)
    {
        let match = Match()
        match.diceMaterials = dic["dice_materials"] as! [String]
        match.diceNum = dic["dice_num"] as! Int
        match.bet = dic["bet"] as? Int ?? 0
        match.isPrivate = dic["private"] as? Bool ?? false
        
        
        match.players.append(player)
        matches.append(match)
        
        // send room info to all
        sendInfo()
    }
    
    func joinMatch(dic: [String:Any], player: Player)
    {
        guard
            let matchId = dic["match_id"] as? Int,
            let match = findMatch(id: matchId) else
        {
            return
        }
        
        // forbid 2 same players in match
        if match.players.contains(where: { (p) -> Bool in
            return p.id == player.id
        }) {
            return
        }
        
        match.players.append(player)
        match.state = .Playing
        
        if let diceMat = dic["dice_mat"] as? String
        {
            match.diceMaterials[1] = diceMat
        }
        
        // send room info to all
        
        sendInfo()
        print("info sent")
        
        let dic = ["msg_func":"join_match", "isOK":true, "match_id":matchId] as [String : Any]
        match.send(dic)
        
    }
    
    func leaveMatch(dic: [String:Any], player: Player) {
        let matchId = dic["match_id"] as? Int
        
        if let idx = matches.index(where: {$0.id == matchId})
        {
            let match = matches[idx]
            matches.remove(at: idx)
            match.sendOthers(fromPlayerId: player.id, dic: dic)
        }
        
        // send room info to all
        sendInfo()
    }
    
    func updatePlayer(dic: [String:Any], player: Player) throws
    {
        
        player.update(dic: dic)
        try playersCollection.update(matching: ["_id":.string(player.id)], to: player.document())
        
        sendInfo()
        
    }
    
    func turn(dic: [String:Any])
    {
        if let id = dic["id"] as? String,
            let matchId = dic["match_id"] as? Int,
            let match = findMatch(id: matchId)
        {
            // forward message to other participants in match
            match.sendOthers(fromPlayerId: id, dic: dic)
        }
    }
    
    func onClose(player: Player)
    {
        if connections[player.id] != nil
        {
            connections.removeValue(forKey: player.id)
        }
        
        player.connected = false
        player.disconnectedAt = Date()
        
        // send info to all players
        sendInfo()
    }
    
    func findMatch(id: Int) -> Match?
    {
        return matches.first(where: { m in
            return m.id == id
        })
    }
    
    
    
    // send to all in room
    func send(_ dic: [String:Any])
    {
        do {
            let str = try dic.jsonEncodedString()
            print("Send msg in room: \(str)")
            for (_, socket) in connections
            {
                socket.sendStringMessage(string: str, final: true, completion: {})
            }
        } catch {
            print(error)
        }
    }
    
    // send info to all in room
    func sendInfo()
    {
        send(dic())
    }
    
    
    
    func dic() -> [String:Any]
    {
        var playersInfo = connections.map({(key, ws) -> [String:Any] in
            return Player.all[key]!.dic()
        })
        
        let matchesInfo = matches.map({ match -> [String:Any] in
            
            print("Match id: \(match.id)")
            for player in match.players
            {
                print("player id \(player.id)")
                // add also player which is not connected but still exists in match :(
                if connections[player.id] == nil
                {
                    playersInfo.append(player.dic())
                }
            }
            return match.dic()
        })
        print("return room dic")
        return ["msg_func": "room_info",
                "players": playersInfo,
                "matches": matchesInfo]
    }
    
    func clean()
    {
        var ctCleaned = 0
        for (mIdx,m) in matches.enumerated().reversed()
        {
            if m.clean()
            {
                ctCleaned += 1
                matches.remove(at: mIdx)
            }
        }
        
        if ctCleaned > 0
        {
            sendInfo()
        }
    }
}
