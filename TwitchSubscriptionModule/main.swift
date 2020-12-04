//
//  main.swift
//  EmoteModule
//
//  Created by Zeke Snider on 4/16/16.
//  Copyright © 2016 Zeke Snider. All rights reserved.
//

import Foundation
import JaredFramework
import Telegraph

public class TwitchSubscriptionModule: RoutingModule {
    var sender: MessageSender
    var server: Server
    
    let defaults = UserDefaults.standard
    public var routes: [Route] = []
    public var description = "A Description"

    required public init(sender: MessageSender) {
        self.sender = sender
        server = Server()
        server.route(.POST, "webhook", {[weak self] in self?.handleTwitchPost(request: $0)})
        server.route(.GET, "webhook", {[weak self] in self?.handleTwitchGet(request: $0)})
        
        let testRoute = Route(name: "Subscribe to twitch notifications", comparisons: [.startsWith: ["/twitch"]], call: {[weak self] in self?.twitch(message: $0)}, description: "Subscribe to notifications from a twitch streamer. /twitch,subscribe,username")
        let diceRoute = Route(name: "Roll a die", comparisons: [.startsWith: ["/roll"]], call: {[weak self] in self?.handleDiceRoll($0)}, description: "Roll x y sided die. /roll,xdy")
        routes = [testRoute, diceRoute]
        
        try! server.start(port: 8090)
    }
    
    deinit {
        server.stop()
    }
    
    public func twitch(message: Message) -> Void {
        guard let params = message.getTextParameters() else {
            sender.send("I couldn't parse that message", to: message.RespondTo())
            return
        }
        if (params.count != 3) {
            sender.send("Please specify three parameters", to: message.RespondTo())
            return
        }
        
        if params[1] == "unsubscribe" {
            sender.send("Sorry I don't allow you to unsubscribe yet lol :)", to: message.RespondTo())
            return
        }
        if params[1] == "subscribe" {
            let streamer = params[2]
            var currentSubscribers = defaults.array(forKey: "stream:\(streamer)") as? [String] ?? []
            currentSubscribers.append(message.RespondTo()!.handle)
            defaults.set(currentSubscribers, forKey: "stream:\(streamer)")
            sender.send("You are now subscribed to stream notifications from \(streamer)! To unsubscribe, use /twitch,unsubscribe,\(streamer)", to: message.RespondTo())
            return
        } else {
            sender.send("Unsupported parameter.", to: message.RespondTo())
            return
        }
    }
    
    private func handleTwitchPost(request: HTTPRequest) -> HTTPResponse {
        let json = try? JSONSerialization.jsonObject(with: request.body, options: [])
        guard let jsonDict = json as? [String: Any] else {
            return HTTPResponse(content: "first string decode fail")
        }
        guard let data = jsonDict["data"] as? [[String: Any]] else {
            return HTTPResponse(content: "second string decode fail")
        }
        guard data[0]["type"] as? String == "live" else {
            return HTTPResponse(content: "not live")
        }
        guard let streamer = data[0]["user_name"] as? String, let title = data[0]["title"] as? String else {
            return HTTPResponse(content: "no user name or title")
        }
        
        let subscribers = defaults.array(forKey: "stream:\(streamer.lowercased())") as? [String]
        subscribers?.forEach({ subscriber in
            let recipient: RecipientEntity = subscriber.contains(";=;") ? Group(name: nil, handle: subscriber, participants: []) : Person(givenName: nil, handle: subscriber, isMe: false)
            sender.send("https://twitch.tv/\(streamer) \(streamer) is now live with \(title)!", to: recipient)
        })
        
        
        return HTTPResponse(content: "it worked")
    }
    
    private func handleTwitchGet(request: HTTPRequest) -> HTTPResponse {
        print("PARAMS: \(request.uri.queryItems!)")
        print(request.uri.queryItems![0])
        print(request.uri.queryItems![0].name)
        print(request.uri.queryItems![0].value)
        let hubChallenge = request.uri.queryItems?.filter { $0.name == "hub.challenge" }
        
        guard hubChallenge?.count == 1 else {
            return HTTPResponse(content: "no challenge")
        }
        
        return HTTPResponse(content: hubChallenge?[0].value ?? "")
    }
    
    private func handleDiceRoll(_ message: Message) {
        guard message.getTextParameters()?.count == 2 else {
            sender.send("That's not even the right format. One comma only", to: message.RespondTo())
            return
        }
        let dieParam = message.getTextParameters()![1]
        let dieSplit = dieParam.split(separator: "d")
        
        guard dieSplit.count == 2 else {
            sender.send("You gotta put a d in there bro", to: message.RespondTo())
            return
        }
        
        guard let numRoll = Int(dieSplit[0]), let dieSides = Int(dieSplit[1]) else {
            sender.send("bruh both of those things gotta be numbers", to: message.RespondTo())
            return
        }
        
        guard numRoll < 50 && numRoll > 0 else {
            sender.send("no way I'm gonna roll a die that many times", to: message.RespondTo())
            return
        }
        
        guard dieSides < 10000 && dieSides > 0 else {
            sender.send("no way I'm gonna roll a die that many times", to: message.RespondTo())
            return
        }
        
        var returnString = ""
        for i in 1...numRoll {
            let number = Int.random(in: 1 ... dieSides)
            returnString.append("\(convertToEmoji(String(number)))\n")
        }
        
        sender.send(returnString, to: message.RespondTo())
    }
    
    private func convertToEmoji(_ original: String) -> String {
        var newString = original
        newString = newString.replacingOccurrences(of: "0", with: "0️⃣")
        newString = newString.replacingOccurrences(of: "1", with: "1️⃣")
        newString = newString.replacingOccurrences(of: "2", with: "2️⃣")
        newString = newString.replacingOccurrences(of: "3", with: "3️⃣")
        newString = newString.replacingOccurrences(of: "4", with: "4️⃣")
        newString = newString.replacingOccurrences(of: "5", with: "5️⃣")
        newString = newString.replacingOccurrences(of: "6", with: "6️⃣")
        newString = newString.replacingOccurrences(of: "7", with: "7️⃣")
        newString = newString.replacingOccurrences(of: "8", with: "8️⃣")
        newString = newString.replacingOccurrences(of: "9", with: "9️⃣")
        
        return newString
    }
}


