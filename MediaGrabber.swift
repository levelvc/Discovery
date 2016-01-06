//
//  MediaGrabber.swift
//  ConnectedColors
//
//  Created by ALBERT AZOUT on 12/29/15.
//  Copyright © 2015 Ralf Ebert. All rights reserved.
//

import Foundation
import Photos
import RealmSwift

class LastPullDate : Object {
    dynamic var lastDate : NSDate? = nil
}

class PeerMediaUpdates : Object {
    dynamic var peerUpdateMap : NSData? = nil
}

@objc protocol MediaGrabberDelegate {
    func didReceiveMediaUpdate(photoAssets:NSArray, latestDate:NSDate, totalPhotoAssets:Int)
}

@objc class MediaGrabber : NSObject {
    
    var imgManager : PHImageManager!
    var persistDate : Bool = true
    var lastPullDate : NSDate!
    var mediaGrabberTimer : NSTimer!
    var delegate : MediaGrabberDelegate!
    
    override init() {
        super.init()
        self.imgManager = PHImageManager.defaultManager()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "startCheckingForMedia", name: UIApplicationWillEnterForegroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "pauseCheckingForMedia", name: UIApplicationDidEnterBackgroundNotification, object: nil)
        let realm = try! Realm()
        if let last_pull = realm.objects(LastPullDate).first {
            self.lastPullDate = last_pull.lastDate
        } else {
            self.lastPullDate = NSDate(timeIntervalSinceNow:-(24 * 3600) as NSTimeInterval)
        }
        
        // TESTING!!!!!!!!!!
        self.lastPullDate = NSDate(timeIntervalSinceNow:-(24 * 3600) as NSTimeInterval)
        
        print("Last media pull date:", self.lastPullDate)
    }
    
    func updatePeerMediaUpdate(username:String, updateDate:NSDate) {
        let realm = try! Realm()
        if let lastPeerMediaUpdates = realm.objects(PeerMediaUpdates).first {
            let map = lastPeerMediaUpdates.peerUpdateMap
            if(map != nil) {
                map?.setValue(updateDate, forKey: username)
                try! realm.write {
                    lastPeerMediaUpdates.peerUpdateMap = map
                }
            }
        } else {
            let peerMediaUpdate = PeerMediaUpdates()
            let dict = NSMutableDictionary()
            dict.setValue(updateDate as NSDate, forKey: username)
            peerMediaUpdate.peerUpdateMap = NSKeyedArchiver.archivedDataWithRootObject(dict)
            try! realm.write {
                realm.add(peerMediaUpdate)
            }
        }
    }
    
    func getPeerMediaUpdate(username:String) -> NSDate?{
        let realm = try! Realm()
        if let lastPeerMediaUpdates = realm.objects(PeerMediaUpdates).first {
            if let data = lastPeerMediaUpdates.peerUpdateMap {
                let map = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! NSDictionary
                return map[username] as? NSDate
            }
        }
        return nil
    }
    
    func startCheckingForMedia() {
        self.mediaGrabberTimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "updateMedia", userInfo: nil, repeats: true)
    }
    
    func pauseCheckingForMedia() {
        self.mediaGrabberTimer.invalidate()
    }
    
    func updateMedia() {
        if(self.lastPullDate != nil) {
            let assets = getPhotosAfterDate(afterTheDate: self.lastPullDate)
            print("Updating media, got:", assets.count, " photos.")
            if(assets.count > 0) {
                if(self.delegate != nil) {
                    let lastDate = assets.first!.1.creationDate!
                    let sendAssets = assets.map{(pId, asset) in
                        asset
                    }
                    self.delegate.didReceiveMediaUpdate(sendAssets, latestDate: lastDate, totalPhotoAssets: assets.count)
                    if(self.persistDate) {
                        let realm = try! Realm()
                        let lastPullDateObject = LastPullDate()
                        lastPullDateObject.lastDate = lastDate
                        try! realm.write {
                            realm.add(lastPullDateObject)
                        }
                    }
                }
            }
        }
    }
    
    func getPhotosAfterDate(afterTheDate date:NSDate) -> [(String, PHAsset)] {
        let fetchOptions = PHFetchOptions()
        var photos : [String:PHAsset] = [:]
        
        fetchOptions.predicate = NSPredicate(format: "creationDate > %@", date)
        if let fetchResult: PHFetchResult = PHAsset.fetchAssetsWithMediaType(PHAssetMediaType.Image, options: fetchOptions) {
            
            // If the fetch result isn't empty,
            // proceed with the image request
            if(fetchResult.count > 0) {
                print("Retrieved", fetchResult.count, "photos.")
                fetchResult.enumerateObjectsUsingBlock{(object: AnyObject!,
                    count: Int,
                    stop: UnsafeMutablePointer<ObjCBool>) in
                    
                    if object is PHAsset{
                        let asset = object as! PHAsset
                        //let imageSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
                        
                        /* For faster performance, and maybe degraded image */
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .FastFormat
                        options.synchronous = true
                        
                        photos[asset.localIdentifier] = asset                        
                        /*
                        self.imgManager.requestImageForAsset(asset,
                            targetSize: imageSize,
                            contentMode: .AspectFill,
                            options: options,
                            resultHandler: {
                                image, info in
                                //print(info)
                                //print(asset.creationDate)
                                photos[asset.localIdentifier] = asset
                            }
                        )*/
                    }
                }
            }
        }
        
        //Sort the photos in descending order
        let sortedPhotos = photos.sort{
            switch($1.1.creationDate!.compare($0.1.creationDate!)) {
            case NSComparisonResult.OrderedAscending:
                return true
            case NSComparisonResult.OrderedDescending:
                return false
            case NSComparisonResult.OrderedSame:
                return true
            }
        }
        
        return sortedPhotos
        
    }
    
}