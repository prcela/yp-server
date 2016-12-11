//
//  ChatHandler.swift
//  yp-server
//
//  Created by Kresimir Prcela on 10/12/16.
//
//

import Foundation
import PerfectWebSockets
import PerfectHTTP

// A WebSocket service handler must impliment the `WebSocketSessionHandler` protocol.
// This protocol requires the function `handleSession(request: WebRequest, socket: WebSocket)`.
// This function will be called once the WebSocket connection has been established,
// at which point it is safe to begin reading and writing messages.
//
// The initial `WebRequest` object which instigated the session is provided for reference.
// Messages are transmitted through the provided `WebSocket` object.
// Call `WebSocket.sendStringMessage` or `WebSocket.sendBinaryMessage` to send data to the client.
// Call `WebSocket.readStringMessage` or `WebSocket.readBinaryMessage` to read data from the client.
// By default, reading will block indefinitely until a message arrives or a network error occurs.
// A read timeout can be set with `WebSocket.readTimeoutSeconds`.
// When the session is over call `WebSocket.close()`.
class ChatHandler: WebSocketSessionHandler {
    
    // The name of the super-protocol we implement.
    // This is optional, but it should match whatever the client-side WebSocket is initialized with.
    let socketProtocol: String? = "chat"
    var player: Player? = nil
    
    // This function is called by the WebSocketHandler once the connection has been established.
    func handleSession(request: HTTPRequest, socket: WebSocket) {
        
        print("handle session( req: \(request) socket: \(socket))")
        socket.readTimeoutSeconds = -1
        
        func process(dic: [String:Any])
        {
            if let msgId = dic["ack"] as? Int
            {
                if let msgIdx = player?.sentMessages.index(where: { (msg) -> Bool in
                    return msg.id == msgId
                })
                {
                    print("message \(msgId) removed")
                    player?.sentMessages.remove(at: msgIdx)
                }
            }
            else if let msgFuncName = dic["msg_func"] as? String,
                let msgFunc = MessageFunc(rawValue: msgFuncName)
            {
                switch msgFunc {
                case .Join:
                    player = try! Room.main.join(dic: dic, ws: socket)
                    
                case .CreateMatch:
                    guard player != nil else {return}
                    Room.main.createMatch(dic: dic, player: player!)
                    
                    
                case .JoinMatch:
                    guard player != nil else {return}
                    Room.main.joinMatch(dic: dic, player: player!)
                    
                case .LeaveMatch:
                    guard player != nil else {return}
                    Room.main.leaveMatch(dic: dic, player: player!)
                    
                case .InvitePlayer:
                    
                    let recipientId = dic["recipient"] as! String
                    Room.main.connections[recipientId]?.sendStringMessage(string: try! dic.jsonEncodedString(), final: true, completion: {})
                    
                case .IgnoreInvitation:
                    
                    let senderId = dic["sender"] as! String
                    Room.main.connections[senderId]?.sendStringMessage(string: try! dic.jsonEncodedString(), final: true, completion: {})
                    
                case .TextMessage:
                    let recipientId = dic["recipient"] as! String
                    Room.main.connections[recipientId]?.sendStringMessage(string: try! dic.jsonEncodedString(), final: true, completion: {})
                    
                case .UpdatePlayer:
                    guard player != nil else {return}
                    try! Room.main.updatePlayer(dic: dic, player: player!)
                    
                case .Turn:
                    Room.main.turn(dic: dic)
                    
                default:
                    print("Not implemented on yet")
                    break
                }
            }
            
        }

        socket.readBytesMessage { (bytes, op, fin) in
            print("Read bytes msg: \(bytes) op: \(op) fin: \(fin)")
        }
        
        // Read a message from the client as a String.
        // Alternatively we could call `WebSocket.readBytesMessage` to get binary data from the client.
        socket.readStringMessage {
            // This callback is provided:
            //	the received data
            //	the message's op-code
            //	a boolean indicating if the message is complete (as opposed to fragmented)
            string, op, fin in
            
            // The data parameter might be nil here if either a timeout or a network error, such as the client disconnecting, occurred.
            // By default there is no timeout.
            guard let string = string else {
                // This block will be executed if, for example, the browser window is closed.
                socket.close()
                guard self.player != nil else {return}
                Room.main.onClose(player: self.player!)
                return
            }
            
            let dic = try! string.jsonDecode() as! [String : Any]
            process(dic: dic)
            
            // Print some information to the console for informational purposes.
            print("Read msg: \(string) op: \(op) fin: \(fin)")
            
            // Echo the data we received back to the client.
            // Pass true for final. This will usually be the case, but WebSockets has the concept of fragmented messages.
            // For example, if one were streaming a large file such as a video, one would pass false for final.
            // This indicates to the receiver that there is more data to come in subsequent messages but that all the data is part of the same logical message.
            // In such a scenario one would pass true for final only on the last bit of the video.
            socket.sendStringMessage(string: "ok", final: true) {
                
                // This callback is called once the message has been sent.
                // Recurse to read and echo new message.
                print("sent ok")
                self.handleSession(request: request, socket: socket)
            }
        }
    }
}
