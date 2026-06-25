import AppKit
import Foundation

public protocol MenuBarManagerDelegate: AnyObject {
    func menuBarDidChangeLanguage(_ languageCode: String)
    func menuBarDidRequestQuit()
    func menuBarDidRequestPermissionCheck()
}

public class MenuBarManager: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    
    // Checked states
    public private(set) var selectedLanguage = "fr"
    private var isModelLoaded = false
    private var modelName = "ggml-large-v3-turbo.bin"
    private var isAccessibilityTrusted = false
    
    public weak var delegate: MenuBarManagerDelegate?
    
    public override init() {
        super.init()
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else { return }
        
        // Use standard SF Symbol for waveform / dictation
        if let image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "LowWhisper") {
            image.isTemplate = true
            button.image = image
        } else {
            // Fallback to text
            button.title = "🎙️"
        }
        
        menu.delegate = self
        statusItem?.menu = menu
        
        buildMenu()
    }
    
    public func updateState(isModelLoaded: Bool, modelName: String, isAccessibilityTrusted: Bool) {
        self.isModelLoaded = isModelLoaded
        self.modelName = modelName
        self.isAccessibilityTrusted = isAccessibilityTrusted
        
        // Rebuild menu dynamically to reflect updated state
        buildMenu()
    }
    
    private func buildMenu() {
        menu.removeAllItems()
        
        // Title Info
        let titleItem = NSMenuItem(title: "LowWhisper Agent", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Model Loading Info
        let modelStatusTitle = isModelLoaded ? "Modèle : \(modelName)" : "Modèle : Non chargé ⚠️"
        let modelItem = NSMenuItem(title: modelStatusTitle, action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
        menu.addItem(modelItem)
        
        // System Accessibility Status Info
        let trustStatusTitle = isAccessibilityTrusted ? "Option d'accessibilité : Activée ✅" : "Activer l'accessibilité... ⚠️"
        let trustItem = NSMenuItem(
            title: trustStatusTitle,
            action: isAccessibilityTrusted ? nil : #selector(permissionClicked),
            keyEquivalent: ""
        )
        trustItem.target = self
        menu.addItem(trustItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Language Selection Submenu
        let languageMenuItem = NSMenuItem(title: "Langue de dictée", action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu()
        
        let languages = [
            ("Auto (Détecter)", "auto"),
            ("Français", "fr"),
            ("English", "en"),
            ("Español", "es"),
            ("Deutsch", "de")
        ]
        
        for (name, code) in languages {
            let item = NSMenuItem(title: name, action: #selector(languageClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = code
            item.state = (code == selectedLanguage) ? .on : .off
            languageSubmenu.addItem(item)
        }
        
        languageMenuItem.submenu = languageSubmenu
        menu.addItem(languageMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Help / Shortcut reminder
        let shortcutItem = NSMenuItem(title: "Raccourci : Maintenir la touche Globe (Fn)", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)
        
        let doubleTapItem = NSMenuItem(title: "Double-appui : Enregistrement continu", action: nil, keyEquivalent: "")
        doubleTapItem.isEnabled = false
        menu.addItem(doubleTapItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit option
        let quitItem = NSMenuItem(title: "Quitter LowWhisper", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc private func languageClicked(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        selectedLanguage = code
        delegate?.menuBarDidChangeLanguage(code)
        buildMenu()
    }
    
    @objc private func permissionClicked() {
        delegate?.menuBarDidRequestPermissionCheck()
    }
    
    @objc private func quitClicked() {
        delegate?.menuBarDidRequestQuit()
    }
}
