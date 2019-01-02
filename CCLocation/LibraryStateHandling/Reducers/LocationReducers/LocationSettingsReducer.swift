//
//  LocationSettingsReducer.swift
//  CCLocation
//
//  Created by Ralf Kernchen on 29/07/2017.
//  Copyright © 2017 Crowd Connected. All rights reserved.
//

import ReSwift

func locationSettingsReducer (action: Action, state: LocationSettingsState?) -> LocationSettingsState {
    var state = LocationSettingsState (
        currentLocationState: currentLocationReducer(action: action, state: state?.currentLocationState),
        foregroundLocationState: foregroundLocationReducer(action: action, state: state?.foregroundLocationState),
        backgroundLocationState: backgroundLocationReducer(action: action, state: state?.backgroundLocationState)
    )
    
    switch action {
        
    case let lifeCycleAction as LifeCycleAction:
        
        // if we move to foreground
        if lifeCycleAction.lifecycleState == LifeCycle.foreground {

            state.currentLocationState?.currentGEOState?.isStandardGEOEnabled = false
            
            if let foregroundLocationStateUnwrapped = state.foregroundLocationState {
                if let foregroundGEOStateUnwrapped = foregroundLocationStateUnwrapped.foregroundGEOState{
                    if let isStandardGEOEnabled = foregroundGEOStateUnwrapped.fgGEOEnabled {
                        if isStandardGEOEnabled {
                            state.currentLocationState?.currentGEOState?.activityType = foregroundGEOStateUnwrapped.fgActivityType
                            state.currentLocationState?.currentGEOState?.maxRuntime = foregroundGEOStateUnwrapped.fgMaxRuntime
                            state.currentLocationState?.currentGEOState?.minOffTime = foregroundGEOStateUnwrapped.fgMinOffTime
                            state.currentLocationState?.currentGEOState?.desiredAccuracy = foregroundGEOStateUnwrapped.fgDesiredAccuracy
                            state.currentLocationState?.currentGEOState?.distanceFilter = foregroundGEOStateUnwrapped.fgDistanceFilter
                            state.currentLocationState?.currentGEOState?.pausesUpdates = foregroundGEOStateUnwrapped.fgPausesUpdates
                            state.currentLocationState?.currentGEOState?.isStandardGEOEnabled = true
                            state.currentLocationState?.currentGEOState?.isInForeground = true
                        }
                    }
                }
                
                if let foregroundBeaconStateUnwrapped = foregroundLocationStateUnwrapped.foregroundBeaconState {
                    state.currentLocationState?.currentBeaconState?.isIBeaconRangingEnabled = foregroundBeaconStateUnwrapped.isIBeaconRangingEnabled
                    state.currentLocationState?.currentBeaconState?.isEddystoneScanningEnabled = foregroundBeaconStateUnwrapped.isEddystoneScanningEnabled
                    state.currentLocationState?.currentBeaconState?.maxRuntime = foregroundBeaconStateUnwrapped.maxRuntime
                    state.currentLocationState?.currentBeaconState?.minOffTime = foregroundBeaconStateUnwrapped.minOffTime
                    
                    if let regions = state.foregroundLocationState?.foregroundBeaconState?.regions {
                        state.currentLocationState?.currentBeaconState?.regions = regions
                    }
                    
                    state.currentLocationState?.currentBeaconState?.filterWindowSize = foregroundBeaconStateUnwrapped.filterWindowSize
                    state.currentLocationState?.currentBeaconState?.filterMaxObservations = foregroundBeaconStateUnwrapped.filterMaxObservations
                    
                    if let filterExcludeRegions = state.foregroundLocationState?.foregroundBeaconState?.filterExcludeRegions {
                        state.currentLocationState?.currentBeaconState?.filterExcludeRegions = filterExcludeRegions
                        
                    }
                    
                    state.currentLocationState?.currentBeaconState?.isInForeground = true
                }
            }
            
            saveCurrentGEOSateToUserDefaults(geoState: state.currentLocationState?.currentGEOState)
            saveCurrentiBeaconStateToUserDefaults(currentiBeaconState: state.currentLocationState?.currentBeaconState)
        }
        
        // if we move to backround
        if lifeCycleAction.lifecycleState == LifeCycle.background {

            state.currentLocationState?.currentGEOState?.isStandardGEOEnabled = false
            
            if let backgroundLocationStateUnwrapped = state.backgroundLocationState {
                if let backgroundGEOStateUnwrapped = backgroundLocationStateUnwrapped.backgroundGEOState {
                    if let isStandardGEOEnabled = backgroundGEOStateUnwrapped.bgGEOEnabled {
                        if isStandardGEOEnabled {
                            state.currentLocationState?.currentGEOState?.activityType = backgroundGEOStateUnwrapped.bgActivityType
                            state.currentLocationState?.currentGEOState?.maxRuntime = backgroundGEOStateUnwrapped.bgMaxRuntime
                            state.currentLocationState?.currentGEOState?.minOffTime = backgroundGEOStateUnwrapped.bgMinOffTime
                            state.currentLocationState?.currentGEOState?.desiredAccuracy = backgroundGEOStateUnwrapped.bgDesiredAccuracy
                            state.currentLocationState?.currentGEOState?.distanceFilter = backgroundGEOStateUnwrapped.bgDistanceFilter
                            state.currentLocationState?.currentGEOState?.pausesUpdates = backgroundGEOStateUnwrapped.bgPausesUpdates
                            state.currentLocationState?.currentGEOState?.isStandardGEOEnabled = true
                            state.currentLocationState?.currentGEOState?.isInForeground = false
                        }
                    }
                }
                
                if let backgroundBeaconStateUnwrapped = backgroundLocationStateUnwrapped.backgroundBeaconState{
                    state.currentLocationState?.currentBeaconState?.isIBeaconRangingEnabled = backgroundBeaconStateUnwrapped.isIBeaconRangingEnabled
                    state.currentLocationState?.currentBeaconState?.isEddystoneScanningEnabled = backgroundBeaconStateUnwrapped.isEddystoneScanningEnabled
                    state.currentLocationState?.currentBeaconState?.maxRuntime = backgroundBeaconStateUnwrapped.maxRuntime
                    state.currentLocationState?.currentBeaconState?.minOffTime = backgroundBeaconStateUnwrapped.minOffTime
                    
                    if let regions = state.backgroundLocationState?.backgroundBeaconState?.regions {
                        state.currentLocationState?.currentBeaconState?.regions = regions
                    }
                    
                    state.currentLocationState?.currentBeaconState?.filterWindowSize = backgroundBeaconStateUnwrapped.filterWindowSize
                    state.currentLocationState?.currentBeaconState?.filterMaxObservations = backgroundBeaconStateUnwrapped.filterMaxObservations
                    
                    if let filterExcludeRegions = state.backgroundLocationState?.backgroundBeaconState?.filterExcludeRegions {
                        state.currentLocationState?.currentBeaconState?.filterExcludeRegions = filterExcludeRegions
                        
                    }
                    
                    state.currentLocationState?.currentBeaconState?.isInForeground = false
                    
                }
            }
            
            saveCurrentGEOSateToUserDefaults(geoState: state.currentLocationState?.currentGEOState)
            saveCurrentiBeaconStateToUserDefaults(currentiBeaconState: state.currentLocationState?.currentBeaconState)
        }
        
    default:
        break
    }
    
    return state
}
