//
//  MessageType.swift
//  VaporApp
//
//  Created by Kresimir Prcela on 08/09/16.
//
//

import Foundation

enum MessageFunc: String
{
    case Join = "join"
    case Disconnected = "disconnected"
    case Match = "match"
    case Message = "message"
    case CreateMatch = "create_match"
    case JoinMatch = "join_match"
    case LeaveMatch = "leave_match"
    case Turn = "turn"
    case InvitePlayer = "invite_player"
    case IgnoreInvitation = "ignore_invitation"
    case TextMessage = "text_message"
    case UpdatePlayer = "update_player"
}

enum Turn: String
{
    case RollDice = "roll_dice"
    case End = "end"
}
