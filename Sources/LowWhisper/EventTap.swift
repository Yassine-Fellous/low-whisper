import Foundation
import CoreGraphics
import AppKit

public protocol EventTapManagerDelegate: AnyObject {
    func eventTapGlobeKeyDidPressDown()
    func eventTapGlobeKeyDidReleaseUp()
    func eventTapGlobeKeyDidDoublePress()
    func eventTapGlobeKeyDidTriggerStop()
}

public class EventTapManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isTapped = false
    
    // State tracking for Globe/Fn key
    private var fnKeyPressed = false
    private var isRecording = false
    private var recordingMode: RecordingMode = .none
    
    private var lastPressTime = Date.distantPast
    private var lastReleaseTime = Date.distantPast
    private let doublePressThreshold: TimeInterval = 0.35
    private var stopTask: DispatchWorkItem? = nil
    
    public weak var delegate: EventTapManagerDelegate?
    
    public enum RecordingMode {
        case none
        case pushToTalk
        case toggle
    }
    
    public init() {}
    
    public func isTrusted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    public func start() -> Bool {
        guard isTrusted() else {
            print("EventTap: App is not trusted. Requesting permissions.")
            requestAccessibilityPermission()
            return false
        }
        
        guard !isTapped else { return true }
        
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
        
        // Pass self pointer as refcon
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPointer
        ) else {
            print("EventTap: Failed to create event tap.")
            return false
        }
        
        self.eventTap = eventTap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        if let runLoopSource = self.runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            isTapped = true
            print("EventTap: Successfully started global event tap.")
            return true
        }
        
        return false
    }
    
    public func stop() {
        guard isTapped else { return }
        
        if let runLoopSource = self.runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let eventTap = self.eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        self.runLoopSource = nil
        self.eventTap = nil
        isTapped = false
        print("EventTap: Stopped global event tap.")
    }
    
    public func setRecordingState(isRecording: Bool, mode: RecordingMode) {
        self.isRecording = isRecording
        self.recordingMode = mode
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .flagsChanged {
            // NX_SECONDARYFNMASK is 0x00800000
            let fnMask: UInt64 = 0x00800000
            let flags = event.flags.rawValue
            let isFnPressed = (flags & fnMask) != 0
            
            if isFnPressed && !fnKeyPressed {
                // Key Down Event
                fnKeyPressed = true
                handleGlobeKeyPress()
            } else if !isFnPressed && fnKeyPressed {
                // Key Up Event
                fnKeyPressed = false
                handleGlobeKeyRelease()
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    private func handleGlobeKeyPress() {
        let now = Date()
        let timeSinceLastRelease = now.timeIntervalSince(lastReleaseTime)
        
        // Cancel any pending PTT stop task from a quick tap release
        stopTask?.cancel()
        stopTask = nil
        
        if !isRecording {
            if timeSinceLastRelease < doublePressThreshold {
                // Double press to toggle continuous recording
                recordingMode = .toggle
                delegate?.eventTapGlobeKeyDidDoublePress()
                print("EventTap: Double press detected! Continuous recording started.")
            } else {
                // Initial press (start as Push-to-Talk)
                recordingMode = .pushToTalk
                delegate?.eventTapGlobeKeyDidPressDown()
                print("EventTap: Single press detected! Push-to-talk recording started.")
            }
            lastPressTime = now
        } else {
            // If already recording in toggle mode, a single press stops it
            if recordingMode == .toggle {
                delegate?.eventTapGlobeKeyDidTriggerStop()
                print("EventTap: Globe press triggered stop for continuous recording.")
            }
        }
    }
    
    private func handleGlobeKeyRelease() {
        lastReleaseTime = Date()
        let pressDuration = lastReleaseTime.timeIntervalSince(lastPressTime)
        
        if recordingMode == .pushToTalk {
            if pressDuration > 0.25 {
                // User held it and released -> Stop immediately
                delegate?.eventTapGlobeKeyDidReleaseUp()
                print("EventTap: Held Globe key released. Stopping recording.")
            } else {
                // Quick tap release. Wait to check if it's the first tap of a double tap.
                let task = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    if self.recordingMode == .pushToTalk {
                        self.delegate?.eventTapGlobeKeyDidReleaseUp()
                        print("EventTap: Single quick tap timeout. Stopping recording.")
                    }
                }
                self.stopTask = task
                // Wait 0.25s to see if the second click of a double tap happens
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
            }
        }
        // If mode is .toggle, do nothing on release because we want continuous recording!
    }
}
