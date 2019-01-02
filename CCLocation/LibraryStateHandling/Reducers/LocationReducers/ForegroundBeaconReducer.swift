//
//  ForegroundiBeaconReducer.swift
//  CCLocation
//
//  Created by Ralf Kernchen on 01/08/2017.
//  Copyright © 2017 Crowd Connected. All rights reserved.
//

import ReSwift
import CoreLocation

private struct ForegroundBeaconReducerConstants {
    static let userDefaultsForegroundiBeaconKey = "fGiBeaconKey"
    static let userDefaultsForegroundiBeaconRegionsKey = "fGiBeaconRegionsKey"
    static let userDefaultsForegroundiBeaconFilterRegionsKey = "fGiBeaconFilterRegionsKey"
}

private typealias C = ForegroundBeaconReducerConstants

func foregroundBeaconReducer (action: Action, state: ForegroundBeaconState?) -> ForegroundBeaconState {
    
    var fGiBeaconState = ForegroundBeaconState(fGiBeaconEnabled: false, maxRuntime: nil, minOffTime: nil, regions: [], filterWindowSize: nil, filterMaxObservations: nil, filterExcludeRegions: [], eddystoneScanEnabled: false)
    
    
    if let loadedfGiBeaconState = getForegroundiBeaconStateFromUserDefaults() {
        fGiBeaconState = loadedfGiBeaconState
    }
    
    var state = state ?? fGiBeaconState
    
    switch action {
    case let enableForegroundBeaconAction as EnableForegroundBeaconAction:
        
        state.maxRuntime = enableForegroundBeaconAction.maxRuntime
        state.minOffTime = enableForegroundBeaconAction.minOffTime
        
        state.regions = enableForegroundBeaconAction.regions
        
        state.filterWindowSize = enableForegroundBeaconAction.filterWindowSize
        state.filterMaxObservations = enableForegroundBeaconAction.filterMaxObservations
        
        state.filterExcludeRegions = enableForegroundBeaconAction.filterExcludeRegions
        
        state.isEddystoneScanningEnabled = enableForegroundBeaconAction.isEddystoneScanningEnabled
        
        state.isIBeaconRangingEnabled = enableForegroundBeaconAction.isIBeaconRangingEnabled

        saveForegroundiBeaconStateToUserDefaults(iBeaconState: state)
        
    case _ as DisableForegroundiBeaconAction:
        state.isIBeaconRangingEnabled = false
        
        saveForegroundiBeaconStateToUserDefaults(iBeaconState: state)
        
    default:
        break
    }
    return state
}

private func getForegroundiBeaconStateFromUserDefaults () -> ForegroundBeaconState? {
    let userDefaults = UserDefaults.standard
    
    var fgIBeaconState:ForegroundBeaconState?
    
    if let iBeaconDictionary = userDefaults.dictionary(forKey: C.userDefaultsForegroundiBeaconKey){
        
        if fgIBeaconState == nil {
            fgIBeaconState = ForegroundBeaconState(fGiBeaconEnabled: false, maxRuntime: nil, minOffTime: nil, regions: [], filterWindowSize: nil, filterMaxObservations: nil, filterExcludeRegions: [], eddystoneScanEnabled: false)
        }
        
        fgIBeaconState?.maxRuntime = iBeaconDictionary["maxRuntime"] as? UInt64
        fgIBeaconState?.minOffTime = iBeaconDictionary["minOffTime"] as? UInt64
        fgIBeaconState?.filterWindowSize = iBeaconDictionary["filterWindowSize"] as? UInt64
        fgIBeaconState?.filterMaxObservations = iBeaconDictionary["filterMaxObservations"] as? UInt32
        fgIBeaconState?.isEddystoneScanningEnabled = iBeaconDictionary["isEddystoneScanningEnabled"] as? Bool
        fgIBeaconState?.isIBeaconRangingEnabled = iBeaconDictionary["fGiBeaconEnabled"] as? Bool
    }
    
    if let decoded = userDefaults.object(forKey: C.userDefaultsForegroundiBeaconRegionsKey) as? Data {
        
        if fgIBeaconState == nil {
            fgIBeaconState = ForegroundBeaconState(fGiBeaconEnabled: false, maxRuntime: nil, minOffTime: nil, regions: [], filterWindowSize: nil, filterMaxObservations: nil, filterExcludeRegions: [], eddystoneScanEnabled: false)
        }
        
        let decodediBeaconRegions = NSKeyedUnarchiver.unarchiveObject(with: decoded) as? [CLBeaconRegion] ?? [CLBeaconRegion]()
        
        fgIBeaconState?.regions = decodediBeaconRegions
    }
    
    if let decoded = userDefaults.object(forKey: C.userDefaultsForegroundiBeaconFilterRegionsKey) as? Data {
        
        if fgIBeaconState == nil {
            fgIBeaconState = ForegroundBeaconState(fGiBeaconEnabled: false, maxRuntime: nil, minOffTime: nil, regions: [], filterWindowSize: nil, filterMaxObservations: nil, filterExcludeRegions: [], eddystoneScanEnabled: false)
        }
        
        let decodediBeaconFilteredRegions = NSKeyedUnarchiver.unarchiveObject(with: decoded) as? [CLBeaconRegion] ?? [CLBeaconRegion]()
        
        fgIBeaconState?.filterExcludeRegions = decodediBeaconFilteredRegions
    }
    
    return fgIBeaconState
}

private func saveForegroundiBeaconStateToUserDefaults (iBeaconState: ForegroundBeaconState?) {
    
    guard let iBeaconState = iBeaconState else {
        return
    }
    
    let userDefaults = UserDefaults.standard
    
    var dictionary = [String:Int64]()
    
    if let maxRuntime = iBeaconState.maxRuntime {
        dictionary["maxRuntime"] = Int64(maxRuntime)
    }
    
    if let minOffTime = iBeaconState.minOffTime {
        dictionary["minOffTime"] = Int64(minOffTime)
    }
    
    if let filterWindowSize = iBeaconState.filterWindowSize {
        dictionary["filterWindowSize"] = Int64(filterWindowSize)
    }
    
    if let filterMaxObservations = iBeaconState.filterMaxObservations {
        dictionary["filterMaxObservations"] = Int64(filterMaxObservations)
    }
    
    if let eddystoneScan = iBeaconState.isEddystoneScanningEnabled {
        dictionary["isEddystoneScanEnabled"] = eddystoneScan ? 1 : 0
    }
    
    if let fGiBeaconEnabled = iBeaconState.isIBeaconRangingEnabled {
        dictionary["fGiBeaconEnabled"] = fGiBeaconEnabled ? 1 : 0
    }
    
    userDefaults.set(dictionary, forKey: C.userDefaultsForegroundiBeaconKey)
    
    let encodedRegions = NSKeyedArchiver.archivedData(withRootObject: iBeaconState.regions)
    
    userDefaults.set(encodedRegions, forKey: C.userDefaultsForegroundiBeaconRegionsKey)
    
    let encodedFilterRegions = NSKeyedArchiver.archivedData(withRootObject: iBeaconState.filterExcludeRegions)
    
    userDefaults.set(encodedFilterRegions, forKey: C.userDefaultsForegroundiBeaconFilterRegionsKey)
    
    userDefaults.synchronize()
    
}
