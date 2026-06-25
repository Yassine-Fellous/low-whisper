import Foundation
import AppKit
import CoreGraphics

public class TextInjector {
    public init() {}
    
    /// Injects the specified text at the current cursor position by copying it to the clipboard,
    /// simulating Cmd+V, and restoring the user's original clipboard contents.
    public func injectText(_ text: String) {
        guard !text.isEmpty else { return }
        
        let pasteboard = NSPasteboard.general
        
        // 1. Backup existing pasteboard contents
        let originalPasteboardItems = backupPasteboard(pasteboard)
        
        // 2. Set new text to general pasteboard
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(text, forType: .string)
        
        // 3. Post Cmd+V keystroke events
        simulatePaste()
        
        // 4. Restore the original pasteboard items after a short delay
        // 150-200ms is enough for most target applications to fetch the pasteboard data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            pasteboard.clearContents()
            if let items = originalPasteboardItems, !items.isEmpty {
                for item in items {
                    // Re-write backup objects
                    pasteboard.writeObjects([item])
                }
                print("TextInjector: Restored original clipboard contents.")
            }
        }
    }
    
    private func backupPasteboard(_ pasteboard: NSPasteboard) -> [NSPasteboardItem]? {
        guard let items = pasteboard.pasteboardItems else { return nil }
        
        var backups: [NSPasteboardItem] = []
        for item in items {
            let backupItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    backupItem.setData(data, forType: type)
                }
            }
            backups.append(backupItem)
        }
        return backups
    }
    
    private func simulatePaste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        
        // Virtual Key Code for 'V' is 9 on QWERTY and AZERTY (macOS hardware independent)
        let vKeyCode: CGKeyCode = 9
        
        guard let cmdVDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true) else {
            print("TextInjector: Failed to create Cmd+V Down event.")
            return
        }
        cmdVDown.flags = .maskCommand
        
        guard let cmdVUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) else {
            print("TextInjector: Failed to create Cmd+V Up event.")
            return
        }
        cmdVUp.flags = .maskCommand
        
        // Post events to the session
        cmdVDown.post(tap: .cgSessionEventTap)
        cmdVUp.post(tap: .cgSessionEventTap)
        
        print("TextInjector: Simulated Cmd+V keystroke.")
    }
}
