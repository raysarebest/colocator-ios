//
//  CCLocationTests.swift
//  CCLocationTests
//
//  Created by Ralf Kernchen on 16/10/2016.
//  Copyright © 2016 Crowd Connected. All rights reserved.
//

import XCTest
import CoreLocation
@testable import CCLocation

class CCLocationTests: XCTestCase {
    
    class MockCCRequest:CCRequest{
        
        var messageQueue = [Data]()
        var sendData = Data()
        var ccRequestMessaging:CCRequestMessaging!
        var startDate = Date()
       
        override func messageQueuePopSwiftBridge() -> Data! {
            return messageQueue.popLast()
        }
        
        override func messageQueuePushSwiftBridge(_ message: Data!) {
            messageQueue.append(message)
        }
        
        override func messageQueueCountSwiftBridge() -> Int {
            return messageQueue.count
        }
        
        override func sendWebSocketMessageSwiftBridge(_ data: Data!) {
            sendData = data
        }
        
        override func getStartTimeSwiftBridge() -> Date! {
            
            var dateComponents = DateComponents()
            dateComponents.setValue(-30, for: .second)
            
            let date = Calendar.current.date(byAdding: dateComponents, to: startDate)
            
            return date
        }
    }
    
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSingleLocationMessage() {
        
        // Given
        
        let mockCCRequest = MockCCRequest()
        mockCCRequest.ccRequestMessaging = CCRequestMessaging(ccRequest: mockCCRequest)
        
        var locationMessage = Messaging_LocationMessage()
        var clientMessage = Messaging_ClientMessage()
        
        locationMessage.longitude = 5.0
        locationMessage.latitude = 6.0
        locationMessage.accuracy = 7.0
        locationMessage.altitude = 8.0
        locationMessage.timestamp = 123456
        
        clientMessage.locationMessage.append(locationMessage)
        
        let data = try? clientMessage.serializedData()
        
        print("compiled client message data length: \(data?.count ?? -1) and compiled message: \(clientMessage)")
        
        mockCCRequest.messageQueuePushSwiftBridge(data)
        
        let ccRequestMessaging = CCRequestMessaging(ccRequest: mockCCRequest)
        
        let returnedData = ccRequestMessaging.getCompiledClientMessageData(hasFirstMessage: true)
        
        let recodedClientMessage = try? Messaging_ClientMessage(serializedData: returnedData!)
        
        
        // Then
        XCTAssert(clientMessage == recodedClientMessage)
    }

    /**
        Test for sendLocationMessage a single location message from a CLLocation
     */
    func testLocationMessageNoAltitudeIsSent() {
        
        // 1. given
        
        let mockCCRequest = MockCCRequest()
        let ccRequestMessaging = CCRequestMessaging.init(ccRequest: mockCCRequest)
        mockCCRequest.ccRequestMessaging = ccRequestMessaging

        let location = CLLocation(latitude: 51.239760, longitude: -0.612358)
        
        var locationMessage = Messaging_LocationMessage()
        var clientMessage = Messaging_ClientMessage()
        
        let timeInterval = location.timestamp.timeIntervalSince(mockCCRequest.getStartTimeSwiftBridge())
        
        locationMessage.longitude = location.coordinate.longitude
        locationMessage.latitude = location.coordinate.latitude
        locationMessage.accuracy = location.horizontalAccuracy
        locationMessage.timestamp = UInt64(fabs(timeInterval * Double(1000.0)))
        
        clientMessage.locationMessage.append(locationMessage)

        guard let locationMessageData = try? clientMessage.serializedData() else {
            return
        }

//        print("test client message data length: \(data?.count ?? -1) and compiled message: \(clientMessage)")
        
        // 2. when
        
        ccRequestMessaging.stateStore.dispatch(WebSocketDidOpen())
        ccRequestMessaging.sendLocationMessage(location: location)

        guard let recodedClientMessage = try? Messaging_ClientMessage(serializedData: mockCCRequest.sendData) else {
            return
        }

        print("compiled client message data length: \(locationMessageData.count) and compiled message: \(recodedClientMessage)")

        
        // 3. then
        XCTAssert(clientMessage == recodedClientMessage)
    }

    func testLocationMessageIsSent() {
        
        // 1. given
        
        let mockCCRequest = MockCCRequest()
        let ccRequestMessaging = CCRequestMessaging.init(ccRequest: mockCCRequest)
        mockCCRequest.ccRequestMessaging = ccRequestMessaging
        
        let location = CLLocation(coordinate:CLLocationCoordinate2D(latitude: 51.239760, longitude: -0.612358), altitude: 200, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date())
        
        var locationMessage = Messaging_LocationMessage()
        var clientMessage = Messaging_ClientMessage()
        
        let timeInterval = location.timestamp.timeIntervalSince(mockCCRequest.getStartTimeSwiftBridge())
        
        locationMessage.longitude = location.coordinate.longitude
        locationMessage.latitude = location.coordinate.latitude
        locationMessage.accuracy = location.horizontalAccuracy
        locationMessage.altitude = location.altitude
        locationMessage.timestamp = UInt64(fabs(timeInterval * Double(1000.0)))
        
        clientMessage.locationMessage.append(locationMessage)
        
        let data = try? clientMessage.serializedData()
        
        print("test client message data length: \(data?.count ?? -1) and compiled message: \(clientMessage)")
        
        ccRequestMessaging.stateStore.dispatch(WebSocketDidOpen())
        ccRequestMessaging.sendLocationMessage(location: location)
        
        let recodedClientMessage = try? Messaging_ClientMessage(serializedData: mockCCRequest.sendData)
        
        print("compiled client message data length: \(data?.count ?? -1) and compiled message: \(String(describing: recodedClientMessage))")
        
        
        // 3. then
        XCTAssert(clientMessage == recodedClientMessage)
    }

    func testLocationMessageIsQueuedOnTimerRunning() {
        
        // 1. given
        
        let mockCCRequest = MockCCRequest()
        let ccRequestMessaging = CCRequestMessaging.init(ccRequest: mockCCRequest)
        mockCCRequest.ccRequestMessaging = ccRequestMessaging
        
        let location = CLLocation(coordinate:CLLocationCoordinate2D(latitude: 51.239760, longitude: -0.612358), altitude: 200, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date())
        
        var locationMessage = Messaging_LocationMessage()
        var clientMessage = Messaging_ClientMessage()
        
        let timeInterval = location.timestamp.timeIntervalSince(mockCCRequest.getStartTimeSwiftBridge())
        
        locationMessage.longitude = location.coordinate.longitude
        locationMessage.latitude = location.coordinate.latitude
        locationMessage.accuracy = location.horizontalAccuracy
        locationMessage.altitude = location.altitude
        locationMessage.timestamp = UInt64(fabs(timeInterval * Double(1000.0)))
        
        clientMessage.locationMessage.append(locationMessage)

        guard let locationMessageData = try? clientMessage.serializedData() else {
            return
        }

        print("test location client message data length: \(locationMessageData.count) and compiled message: \(clientMessage)")

        var bluetoothMessage = Messaging_Bluetooth()
        
        let uuid = UUIDHelper.deviceApplicationIdentifierUUID
        
        bluetoothMessage.identifier = uuid().uuidString.data(using: .utf8)!
        bluetoothMessage.rssi = Int32(0)
        bluetoothMessage.tx = 0
        bluetoothMessage.timestamp = 0

        var bluetoothClientMessage = Messaging_ClientMessage()
        bluetoothClientMessage.bluetoothMessage.append(bluetoothMessage)
        
        print("compiled bluetooth message: \(bluetoothClientMessage)")

        // 2. when
        
        ccRequestMessaging.stateStore.dispatch(WebSocketDidOpen())
        ccRequestMessaging.stateStore.dispatch(TimeBetweenSendsTimerReceived(timeInMilliseconds: 30000))
        ccRequestMessaging.sendLocationMessage(location: location)
        
        guard let recodedClientMessage = try? Messaging_ClientMessage(serializedData: mockCCRequest.sendData) else {
            return
        }
        
        guard let messageInQueue = try? Messaging_ClientMessage(serializedData: mockCCRequest.messageQueue.popLast()!) else {
            return
        }
        
        print("recoded client message to send: \(recodedClientMessage)")
        print("message in queue: \(messageInQueue)")
        
        // 3. then
        XCTAssert(recodedClientMessage == bluetoothClientMessage)
        XCTAssert(messageInQueue == clientMessage)
    }

    func testAliasMessagesAreSent() {
        
        // Given
        
        let mockCCRequest = MockCCRequest()
        let ccRequestMessaging = CCRequestMessaging.init(ccRequest: mockCCRequest)
        mockCCRequest.ccRequestMessaging = ccRequestMessaging
        
        let aliasMessagesDict:[String:String] = ["key 1":"value 1", "key 2": "value 2"]
        
        var aliasMessage = Messaging_AliasMessage()
        var clientMessage = Messaging_ClientMessage()
        
        aliasMessage.key = "key 1"
        aliasMessage.value = "value 1"
        
        clientMessage.alias.append(aliasMessage)
        
        aliasMessage = Messaging_AliasMessage()
        
        aliasMessage.key = "key 2"
        aliasMessage.value = "value 2"
        
        clientMessage.alias.append(aliasMessage)
        
        let data = try? clientMessage.serializedData()
        
        
        print("test client message data length: \(data?.count ?? -1) and compiled message: \(clientMessage)")
        
        ccRequestMessaging.stateStore.dispatch(WebSocketDidOpen())
        ccRequestMessaging.sendAliasMessage(aliases: aliasMessagesDict)
        
        let recodedClientMessage = try? Messaging_ClientMessage(serializedData: mockCCRequest.sendData)
        
        print("compiled client message data length: \(data?.count ?? -1) and compiled message: \(String(describing: recodedClientMessage))")
        
        // Then
        XCTAssert(clientMessage == recodedClientMessage)
    }

    func testAliasAndLocationMessagesAreSent() {
        
        // 1. Given
        
        let mockCCRequest = MockCCRequest()
        let ccRequestMessaging = CCRequestMessaging.init(ccRequest: mockCCRequest)
        mockCCRequest.ccRequestMessaging = ccRequestMessaging
        
        let location = CLLocation(coordinate:CLLocationCoordinate2D(latitude: 51.239760, longitude: -0.612358), altitude: 200, horizontalAccuracy: 0, verticalAccuracy: 0, timestamp: Date())

        let aliasMessagesDict:[String:String] = ["key 1":"value 1", "key 2": "value 2"]

        var clientMessage = Messaging_ClientMessage()

        var locationMessage = Messaging_LocationMessage()

        let timeInterval = location.timestamp.timeIntervalSince(mockCCRequest.getStartTimeSwiftBridge())
        
        locationMessage.longitude = location.coordinate.longitude
        locationMessage.latitude = location.coordinate.latitude
        locationMessage.accuracy = location.horizontalAccuracy
        locationMessage.altitude = location.altitude
        locationMessage.timestamp = UInt64(fabs(timeInterval * Double(1000.0)))
        
        clientMessage.locationMessage.append(locationMessage)
        
        var aliasMessage = Messaging_AliasMessage()
        
        aliasMessage.key = "key 1"
        aliasMessage.value = "value 1"
        
        clientMessage.alias.append(aliasMessage)
        
        aliasMessage = Messaging_AliasMessage()
        
        aliasMessage.key = "key 2"
        aliasMessage.value = "value 2"
        
        clientMessage.alias.append(aliasMessage)
        
        let data = try? clientMessage.serializedData()
        
        print("test client message data length: \(data?.count ?? -1) and compiled message: \(clientMessage)")

        // 2. When
        
        ccRequestMessaging.sendLocationMessage(location: location)
        
        ccRequestMessaging.stateStore.dispatch(WebSocketDidOpen())
        
        ccRequestMessaging.sendAliasMessage(aliases: aliasMessagesDict)
        
        // 3. Then

        let recodedClientMessage = try? Messaging_ClientMessage(serializedData: mockCCRequest.sendData)
        
        print("compiled client message data length: \(mockCCRequest.sendData.count) and compiled message: \(String(describing: recodedClientMessage))")
        
        XCTAssert(recodedClientMessage == clientMessage)
    }

    func testTimerReceived() {
        
        // 1. Given

        let mockCCRequest = MockCCRequest()
        let ccRequestMessaging = CCRequestMessaging.init(ccRequest: mockCCRequest)
        mockCCRequest.ccRequestMessaging = ccRequestMessaging
    
        var serverMessage = Messaging_ServerMessage()
        var systemMessage = Messaging_SystemMessage()
        
        systemMessage.type = .timebetweensends
        systemMessage.value = 30000
        
        serverMessage.systemMessage.append(systemMessage)
        
        // 2. When

        guard let serverMessageData = try? serverMessage.serializedData() else {
            return
        }

        XCTAssert(ccRequestMessaging.timeBetweenSendsTimer == nil)

        // 3. Then
        
        ccRequestMessaging.stateStore.dispatch(WebSocketDidOpen())
        
        guard (try? ccRequestMessaging.processServerMessage(data: serverMessageData)) != nil else {
            return
        }

        XCTAssert(ccRequestMessaging.timeBetweenSendsTimer != nil)
    }

    func testNoTimerReceived() {
        
        // 1. Given
        
        let mockCCRequest = MockCCRequest()
        let ccRequestMessaging = CCRequestMessaging.init(ccRequest: mockCCRequest)
        mockCCRequest.ccRequestMessaging = ccRequestMessaging
        
        var serverMessage = Messaging_ServerMessage()
        var systemMessage = Messaging_SystemMessage()
        
        // just using a different message type than TIMEBETWEENSENDS at random
        systemMessage.type = .cachepackagesize
        systemMessage.value = 1000
        
        serverMessage.systemMessage.append(systemMessage)
        
        // 2. When
        
        guard let serverMessageData = try? serverMessage.serializedData() else {
            return
        }
        
        XCTAssert(ccRequestMessaging.timeBetweenSendsTimer == nil)
        
        ccRequestMessaging.stateStore.dispatch(WebSocketDidOpen())
        
        // 3. Then
        
        guard (try? ccRequestMessaging.processServerMessage(data: serverMessageData)) != nil else {
            return
        }
        
        XCTAssert(ccRequestMessaging.timeBetweenSendsTimer == nil)
    }

    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
