//
//  StatItem.swift
//  y-server
//
//  Created by Kresimir Prcela on 15/11/16.
//
//

import Foundation
import MongoKitten

class StatItem
{
    static var allStatItems = [StatItem]()
    
    let player_id: String
    let match_type: String
    let dice_num: Int32
    let score: Int32
    let result: Int32
    let bet: Int32
    let timestamp: Date
    
    init(dic: [String:Any])
    {
        player_id = dic["player_id"] as! String
        match_type = dic["match_type"] as! String
        dice_num = dic["dice_num"] as! Int32
        score = dic["score"] as! Int32
        result = dic["result"] as! Int32
        bet = dic["bet"] as! Int32
        timestamp = Date()
    }
    
    init(document: Document)
    {
        player_id = document["player_id"].string
        match_type = document["match_type"].string
        dice_num = document["dice_num"].int32
        score = document["score"].int32
        result = document["result"].int32
        bet = document["bet"].int32
        timestamp = document["timestamp"].dateValue!
    }
    
    func document() -> Document
    {
        let doc: Document = [
            "player_id": .string(player_id),
            "match_type": .string(match_type),
            "dice_num": .int32(dice_num),
            "score": .int32(score),
            "result": .int32(result),
            "bet": .int32(bet),
            "timestamp": .dateTime(timestamp)
        ]
        
        return doc
    }
    
    func dic() -> [String:Any]
    {
        let timeInterval = timestamp.timeIntervalSince1970
        let dic: [String:Any] = [
            "player_id": player_id,
            "match_type": match_type,
            "dice_num": dice_num,
            "score": score,
            "result": result,
            "bet": bet,
            "timestamp": timeInterval
            ]
        return dic
    }
    
    class func loadStats()
    {
        allStatItems.removeAll()
        if let array = try? statItemsCollection.find().makeIterator()
        {
            for document in array
            {
                allStatItems.append(StatItem(document: document))
            }
        }
    }
    
    class func insert(dic: [String:Any]) throws
    {
        let statItem = StatItem(dic: dic)
        allStatItems.append(statItem)
        try statItemsCollection.insert(statItem.document())
    }
}
