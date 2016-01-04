//
//  PeerManager.swift
//  ConnectedColors
//
//  Created by ALBERT AZOUT on 12/29/15.
//  Copyright © 2015 Ralf Ebert. All rights reserved.
//

import Foundation
import SwiftyJSON
import CoreLocation
import Photos
import AFDateHelper
import AFNetworking
import RealmSwift

/*
Class for managing peer and beacon events for proximity tracking. 
*/

class User : Object {
    dynamic var userId : String? = nil
    dynamic var uuid : String? = nil
    dynamic var username : String? = nil
    dynamic var firstname : String? = nil
    dynamic var lastname : String? = nil    
}

@objc class APIRequestManager : NSObject {
    
    let api_key, host_url : String
    var user_id : String
    
    let requestManager : AFHTTPRequestOperationManager
    
    init(api_key:String, host_url:String) {
        self.api_key = api_key
        self.host_url = host_url
        self.requestManager = AFHTTPRequestOperationManager()
        self.user_id = ""
    }
    
    func getUser() -> User? {
        let realm = try! Realm()
        if let saved_user = realm.objects(User).first {
            return saved_user
        } else {
            return nil
        }
    }
    
    
    func login(username:String, password:String) -> NSString {
        let semaphore = dispatch_semaphore_create(0)
        self.requestManager.completionQueue = dispatch_queue_create("login", nil)
        self.requestManager.requestSerializer.clearAuthorizationHeader()
        self.requestManager.requestSerializer.setAuthorizationHeaderFieldWithUsername(username, password:password)
        
        var userId : NSString!
        
        self.requestManager.GET(self.host_url + "/login",
            parameters: nil,
            success: { (operation: AFHTTPRequestOperation!, responseObject: AnyObject!) in
                let json = JSON(responseObject)
                
                let user = User()
                user.userId = json["id"].string
                if(json["uuid"] != nil) {
                    user.uuid = json["uuid"].string!
                }
                user.username = json["username"].string
                user.firstname = json["firstname"].string
                user.lastname = json["lastname"].string
                                
                let realm = try! Realm()
                try! realm.write {
                    realm.add(user)
                }
                
                userId = user.userId!
                
                dispatch_semaphore_signal(semaphore)
            },
            failure: {(operation: AFHTTPRequestOperation?, error: NSError!) in
                print("Error: " + error!.description)
                dispatch_semaphore_signal(semaphore)
        })
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        print("userId", userId)
        return userId!;
    }
    
    func postMedia(photos:[(String, PHAsset)], success:(() -> Void), failure:((error: NSError!) -> Void)){
        if(photos.count > 0) {
            let medias = NSMutableArray()
            for photo in photos {
                let media = [
                    "user_id":self.user_id,
                    "media_type":"photo",
                    "timestamp":photo.1.creationDate!.toString(format: .ISO8601(ISO8601Format.DateTimeMilliSec))
                ]
                //print(media)
                medias.addObject(media)
            }
            post(JSON(medias), path:"/media", success: success, failure:failure)
        }
    }
    
    func registerNearbyPeerEvent(nearbyPeers:[String:NSDictionary], success:(() -> Void), failure:((error: NSError!) -> Void)){
        
        let nearby_peers = NSMutableArray()
        
        for peer in nearbyPeers {
            let timestamp = peer.1["timestamp"] as! NSDate
            let nearby_peer = [
                "username":peer.0,
                "timestamp":timestamp.toString(format: .ISO8601(ISO8601Format.DateTimeMilliSec)),
                "discovery_info":peer.1
            ]
            nearby_peers.addObject(nearby_peer)
        }
        
        post(JSON(nearby_peers), path:"/users/self/peers", success: success, failure:failure)
    }
    
    func post(data:JSON, path:String, success:(() -> Void), failure:((error: NSError!) -> Void)) {
        
        requestManager.requestSerializer = AFJSONRequestSerializer()
        requestManager.requestSerializer.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requestManager.requestSerializer.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Set the HMAC
        requestManager.requestSerializer.setValue(
            String(self.api_key + self.user_id).hmac(CryptoAlgorithm.SHA1, key: ";hi^897t7utf"),
            forHTTPHeaderField: "X-Auth-Signature")
        
        let peerQuery = [
            host_url,
            path,
            "?user_id=",
            self.user_id,
            "&timestamp=",
            UInt64(floor(NSDate().timeIntervalSince1970)).description,
            "&api_key=",
            self.api_key
        ]
        
        requestManager.POST(
            peerQuery.joinWithSeparator(""),
            parameters: data.object,
            success: { (operation: AFHTTPRequestOperation!, responseObject: AnyObject!) in
                success()
            },
            failure: { (operation: AFHTTPRequestOperation?, error: NSError!) in
                print(operation!.responseString!)
                failure(error:error)
        })
    }
    
    func registerNearbyBLTEEvent(username:String, range: Int, _timestamp:NSDate, success:(() -> Void), failure:((error: NSError!) -> Void)) {
        //let timestamp = UInt64(floor(_timestamp.timeIntervalSince1970)).description
        let nearby_peer = [
            "timestamp":_timestamp.toString(format: .ISO8601(ISO8601Format.DateTimeMilliSec)),
            "distance":range,
            "username":username
        ]
        let nearby_peers = [nearby_peer]
        post(JSON(nearby_peers), path:"/users/self/peers", success:success, failure:failure)
    }
    
    func registerNearbyBeaconEvent(didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion, _timestamp: NSDate, success:(() -> Void), failure:((error: NSError!) -> Void)) {
        if(beacons.count > 0) {
            let nearby_peers = NSMutableArray()
            for beacon in beacons {
                var distance = "unknown"
                switch beacon.proximity {
                case CLProximity.Far:
                    //message = "You are far away from the beacon"
                    distance = "far"
                case CLProximity.Near:
                    //message = "You are near the beacon"
                    distance = "near"
                case CLProximity.Immediate:
                    //message = "You are in the immediate proximity of the beacon"
                    distance = "immediate"
                default:
                    distance = "unknown"
                }
                
                let nearby_peer = [
                    "uuid":beacon.proximityUUID.description,
                    "timestamp":_timestamp.toString(format: .ISO8601(ISO8601Format.DateTimeMilliSec)),
                    "distance":distance
                ]
                
                nearby_peers.addObject(nearby_peer)
                
            }
            
            post(JSON(nearby_peers), path:"/users/self/peers", success:success, failure:failure)
        }
    }
}


