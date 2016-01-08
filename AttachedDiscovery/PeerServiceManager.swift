//
//  ColorServiceManager.swift
//  ConnectedColors
//
//  Created by Ralf Ebert on 28/04/15.
//  Copyright (c) 2015 Ralf Ebert. All rights reserved.
//

import Foundation
import MultipeerConnectivity

@objc enum PeerServiceManagerEventTypes:Int {
    case EVENT_LAST_MEDIA_DATE = 0
}

@objc protocol PeerServiceManagerDelegate {
    
    func connectedDevicesChanged(manager : PeerServiceManager, connectedDevices: [String])
    //func colorChanged(manager : PeerServiceManager, colorString: String)
    func peerDiscovered(manager: PeerServiceManager, peerId: MCPeerID, withDiscoveryInfo: [String : String]?, timestamp:NSDate)
    func receivedData(manager: PeerServiceManager, data: NSData)
    
}

@objc class PeerServiceManager : NSObject {
    
    private let PeerServiceType = "attached-peer"
    private var myPeerId : MCPeerID? = nil
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser
    var delegate : PeerServiceManagerDelegate?
    private var isAdvertising : Bool = false
    private var isBrowsing : Bool = false
        
    /*
    A dictionary of key-value pairs that are made available to browsers. Each key and value must be an NSString object.

    This data is advertised using a Bonjour TXT record, encoded according to RFC 6763 (section 6). As a result:

    The key-value pair must be no longer than 255 bytes (total) when encoded in UTF-8 format with an equals sign (=) between the key and the value.
    Keys cannot contain an equals sign.
    For optimal performance, the total size of the keys and values in this dictionary should be no more than about 400 bytes so that the entire 
    advertisement can fit within a single Bluetooth data packet. For details on the maximum allowable length, read Monitoring a Bonjour Service.

    If the data you need to provide is too large to fit within these constraints, you should create a custom discovery class using Bonjour for 
    discovery and your choice of networking protocols for exchanging the information.
    */
    
    init(peerId: String) {
    
        self.myPeerId = MCPeerID(displayName: peerId)
        //TODO: Add anything to discovery info here
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: self.myPeerId!, discoveryInfo: nil, serviceType: PeerServiceType)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: self.myPeerId!, serviceType: PeerServiceType)

        super.init()
        
        self.serviceAdvertiser.delegate = self
        self.serviceAdvertiser.startAdvertisingPeer()
        self.isAdvertising = true
        
        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
        self.isBrowsing = true
    
        print("myPeerId:", self.myPeerId!)
    }
    
    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
    }
    
    func stopAdvertising() {
        if(self.isAdvertising){
            self.serviceAdvertiser.stopAdvertisingPeer()
        }
    }
    
    func stopBrowsing() {
        if(self.isBrowsing) {
            self.serviceBrowser.stopBrowsingForPeers()
        }
    }
    
    func startAdvertising() {
        if(!self.isAdvertising) {
            self.serviceAdvertiser.startAdvertisingPeer()
        }
    }
    
    func startBrowsing() {
        if(!self.isBrowsing) {
            self.serviceBrowser.startBrowsingForPeers()
        }
    }
    
    lazy var session: MCSession = {
        let session = MCSession(peer: self.myPeerId!, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.Required)
        session.delegate = self
        return session
    }()

    func sendColor(colorName : String) {
        //NSData *imageData = UIImagePNGRepresentation(image);
        NSLog("%@", "sendColor: \(colorName)")
        
        if session.connectedPeers.count > 0 {
            var error : NSError?
            do {
                try self.session.sendData(colorName.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!, toPeers: session.connectedPeers, withMode: MCSessionSendDataMode.Reliable)
            } catch let error1 as NSError {
                error = error1
                NSLog("%@", "\(error)")
            }
        }

    }
    
    func sendLastMediaDate(lastMediaDate:NSDate) {
        if session.connectedPeers.count > 0 {
            var error : NSError?
            do {
                let dict = ["event":PeerServiceManagerEventTypes.EVENT_LAST_MEDIA_DATE.rawValue, "timestamp":lastMediaDate.formattedISO8601]
                let data = NSKeyedArchiver.archivedDataWithRootObject(dict)
                try self.session.sendData(data, toPeers: session.connectedPeers, withMode: MCSessionSendDataMode.Reliable)
            } catch let error1 as NSError {
                error = error1
                NSLog("%@", "\(error)")
            }
        }
    }
    
}

extension PeerServiceManager : MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: NSError) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: NSData?, invitationHandler: ((Bool, MCSession) -> Void)) {
        
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)
    }

}

extension PeerServiceManager : MCNearbyServiceBrowserDelegate {
    
    func browser(browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: NSError) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }
    
    func browser(browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        self.delegate?.peerDiscovered(self, peerId: peerID, withDiscoveryInfo: info, timestamp:NSDate())
        browser.invitePeer(peerID, toSession: self.session, withContext: nil, timeout: 10)
    }
    
    func browser(browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
    
}

extension MCSessionState {
    
    func stringValue() -> String {
        switch(self) {
        case .NotConnected: return "NotConnected"
        case .Connecting: return "Connecting"
        case .Connected: return "Connected"
        //default: return "Unknown"
        }
    }
    
}

extension PeerServiceManager : MCSessionDelegate {
    
    func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state.stringValue())")
        self.delegate?.connectedDevicesChanged(self, connectedDevices: session.connectedPeers.map({$0.displayName}))
    }
    
    func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveData: \(data.length) bytes")
        //let str = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
        //self.delegate?.colorChanged(self, colorString: str)
        self.delegate?.receivedData(self, data:data)
    }
    
    func session(session: MCSession, didReceiveStream stream: NSInputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveStream")
    }
    
    func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError?) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }
    
    func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
        NSLog("%@", "didStartReceivingResourceWithName")
    }
    
}
