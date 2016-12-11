//
//  Player.swift
//  VaporApp
//
//  Created by Kresimir Prcela on 08/09/16.
//
//

import Foundation
import MongoKitten

class Player
{
    static var all = [String:Player]()
    
    var id: String
    var alias: String
    var diamonds: Int64
    
    // izračunato
    var avgScore5: Double?
    var avgScore6: Double?
    var connected = false
    var disconnectedAt: Date?
    
    var msgCounter: Int = 0
    var sentMessages = [SentMsg]()
    
    init(dic: [String:Any])
    {
        id = dic["id"] as! String
        alias = dic["alias"] as! String
        diamonds = Int64(dic["diamonds"] as! Int)
        avgScore6 = dic["avg_score_6"] as? Double
        avgScore5 = dic["avg_score_5"] as? Double
    }
    
    init(document: Document)
    {
        id = document["_id"].string
        alias = document["alias"].string
        diamonds = document["diamonds"].int64
        avgScore5 = document["avg_score_5"].doubleValue
        avgScore6 = document["avg_score_6"].doubleValue
    }
    
    func update(dic: [String:Any])
    {
        alias = dic["alias"] as! String
        diamonds = Int64(dic["diamonds"] as! Int)
        avgScore6 = dic["avg_score_6"] as? Double
        avgScore5 = dic["avg_score_5"] as? Double
    }
    
    
    func dic() -> [String:Any]
    {
        var dic: [String:Any] = [
            "id":id,
            "alias":alias,
            "diamonds":diamonds,
            "connected": connected]
        
        if avgScore5 != nil
        {
            dic["avg_score_5"] = avgScore5!
        }
        
        if avgScore6 != nil
        {
            dic["avg_score_6"] = avgScore6!
        }
        
        return dic
    }
    
    func document() -> Document
    {
        var doc: Document = [
            "_id": .string(id),
            "alias": .string(alias),
            "diamonds": .int64(diamonds)
        ]
        
        if avgScore5 != nil
        {
            doc["avg_score_5"] = .double(avgScore5!)
        }
        
        if avgScore6 != nil
        {
            doc["avg_score_6"] = .double(avgScore6!)
        }
        
        return doc
    }
    
    func send(dic: [String:Any], ttl: TimeInterval = 15)
    {
        msgCounter += 1
        // create a coy that is unique for player
        var dic = dic
        print("created copy")
        dic["msg_id"] = msgCounter
        
        if let socket = Room.main.connections[id]
        {
            socket.sendStringMessage(string: try! dic.jsonEncodedString(), final: true, completion: {})
        }
        
        print("sentmessages.append")
        sentMessages.append(SentMsg(id: msgCounter, timestamp: Date(), ttl:ttl,  dic: dic))
    }
    
    func deleteExpiredMessages()
    {
        let now = Date()
        for (idx,sentMsg) in sentMessages.enumerated().reversed()
        {
            if sentMsg.timestamp.addingTimeInterval(sentMsg.ttl) < now
            {
                sentMessages.remove(at: idx)
            }
        }
    }
    
    func sendUnsentMessages()
    {
        if let socket = Room.main.connections[id]
        {
            print("sending again messages that are not acknowledged...")
            for sentMsg in sentMessages
            {
                print(id)
                socket.sendStringMessage(string: try! sentMsg.dic.jsonEncodedString(), final: true, completion: {})
            }
            print("finished")
        }
    }
    
    
    
    class func loadPlayers()
    {
        all.removeAll()
        if let array = try? playersCollection.find().makeIterator()
        {
            for document in array
            {
                let id = document["_id"].string
                all[id] = Player(document: document)
            }
        }
    }
    
}

struct SentMsg
{
    let id: Int
    let timestamp: Date
    let ttl: TimeInterval
    let dic: [String:Any]
}
