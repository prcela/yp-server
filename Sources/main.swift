//
//  main.swift
//  PerfectTemplate
//
//  Created by Kyle Jessup on 2015-11-05.
//	Copyright (C) 2015 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import PerfectWebSockets
import PerfectThread
import MongoKitten


let mongo: Server
do {
    mongo = try Server(mongoURL: "mongodb://localhost:27017", automatically: true)
} catch {
    // Unable to connect
    fatalError("MongoDB is not available on the given host and port")
}

let database = mongo["yamb"]
let statItemsCollection = database["statItems"]
let playersCollection = database["players"]

StatItem.loadStats()
Player.loadPlayers()


// Create HTTP server.
let server = HTTPServer()

// Register your own routes and handlers
var routes = Routes()
routes.add(method: .get, uri: "/", handler: {
		request, response in
		response.setHeader(.contentType, value: "text/html")
		response.appendBody(string: "<html><title>Hello, world!</title><body>Hello, world!</body></html>")
		response.completed()
	}
)

// Adding a route to handle the GET people list URL
routes.add(method: .get, uri: "/info", handler: {
    request, response in
    
    let minRequiredVersion = 6
    
    let info = [
        "min_required_version": minRequiredVersion,
        "room_main_ct": Room.main.connections.count,
        "room_main_free_ct": 0
    ]
    
    var str = ""
    
    do {
        str = try info.jsonEncodedString()
    } catch {
        str = "error"
    }
    
    // Setting the response content type explicitly to application/json
    response.setHeader(.contentType, value: "application/json")
    // Setting the body response to the JSON list generated
    response.appendBody(string: str)
    // Signalling that the request is completed
    response.completed()
}
)

// Adding a route to handle the GET people list URL
routes.add(method: .get, uri: "/players", handler: {
    request, response in
    
    
    let players = Player.all.map({ (id,player) -> [String:Any] in
        return player.dic()
    })
    
    var str = ""
    
    do {
        str = try players.jsonEncodedString()
    } catch {
        str = "error"
    }
    
    // Setting the response content type explicitly to application/json
    response.setHeader(.contentType, value: "application/json")
    // Setting the body response to the JSON list generated
    response.appendBody(string: str)
    // Signalling that the request is completed
    response.completed()
}
)

// Adding a route to handle the GET people list URL
routes.add(method: .get, uri: "/statItems", handler: {
    request, response in
    
    
    let statItems = StatItem.allStatItems.map({ (item) -> [String:Any] in
        return item.dic()
    })
    
    var str = ""
    
    do {
        str = try statItems.jsonEncodedString()
    } catch {
        str = "error"
    }
    
    // Setting the response content type explicitly to application/json
    response.setHeader(.contentType, value: "application/json")
    // Setting the body response to the JSON list generated
    response.appendBody(string: str)
    // Signalling that the request is completed
    response.completed()
}
)

// Adding a route to handle the POST people add via JSON
routes.add(method: .post, uri: "/statItem", handler: {
    request, response in
    
    if let dic = try! request.postBodyString?.jsonDecode() as? [String:Any]
    {
        try? StatItem.insert(dic: dic)
    }
    
    // Setting the response content type explicitly to application/json
    response.setHeader(.contentType, value: "application/json")
    // Adding a new "person", passing the just the request's post body as a raw string to the function.
    response.appendBody(string: "ok")
    // Signalling that the request is completed
    response.completed()
}
)

// Adding a route to handle the POST people add via JSON
routes.add(method: .post, uri: "/updatePlayer", handler: {
    request, response in
    
    if let dic = try! request.postBodyString?.jsonDecode() as? [String:Any]
    {
        let id = dic["id"] as! String
        if let player = Player.all[id]
        {
            player.update(dic: dic)
            try? playersCollection.update(matching: ["_id": .string(id)], to: player.document())
        }
        else
        {
            // instantiate new player
            let player = Player(dic: dic)
            Player.all[player.id] = player
            try? playersCollection.insert(player.document())
        }
    }
    
    // Setting the response content type explicitly to application/json
    response.setHeader(.contentType, value: "application/json")
    // Adding a new "person", passing the just the request's post body as a raw string to the function.
    response.appendBody(string: "ok")
    // Signalling that the request is completed
    response.completed()
}
)


// Add the endpoint for the WebSocket example system
routes.add(method: .get, uri: "/chat/", handler: {
    request, response in
    
    // To add a WebSocket service, set the handler to WebSocketHandler.
    // Provide your closure which will return your service handler.
    WebSocketHandler(handlerProducer: {
        (request: HTTPRequest, protocols: [String]) -> WebSocketSessionHandler? in
                
        // Return our service handler.
        return ChatHandler()
    }).handleRequest(request: request, response: response)
})

// Add the routes to the server.
server.addRoutes(routes)

// Set a listen port of 8181
server.serverPort = 80

// Set a document root.
// This is optional. If you do not want to serve static content then do not set this.
// Setting the document root will automatically add a static file handler for the route /**
server.documentRoot = "./webroot"

// Gather command line options and further configure the server.
// Run the server with --help to see the list of supported arguments.
// Command line arguments will supplant any of the values set above.
configureServer(server)

let queue = Threading.getQueue(name: "clean", type: .serial)
queue.dispatch {
    while true {
        Threading.sleep(seconds: 3)
        print("background clean")
        Room.main.clean()
    }
}


do {
	// Launch the HTTP server.
	try server.start()
} catch PerfectError.networkError(let err, let msg) {
	print("Network error thrown: \(err) \(msg)")
}
