//
//  AppDelegate.swift
//  DarkModeBuddy
//
//  Created by Guilherme Rambo on 23/02/21.
//

import Cocoa
import SwiftUI
import DarkModeBuddyCore
import Sparkle

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    private var statusItem: NSStatusItem!
    private var statusUpdateTimer: Timer?
    
    let settings = DMBSettings()

    lazy var switcher: DMBSystemAppearanceSwitcher = {
        DMBSystemAppearanceSwitcher(settings: settings)
    }()
    
    private var shouldShowUI: Bool {
        !settings.hasLaunchedAppBefore
        || shouldShowSettingsOnNextLaunch
        || UserDefaults.standard.bool(forKey: "ShowSettings")
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        SUUpdater.shared()?.delegate = self
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Start as accessory app (status bar only)
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusBar()
        
        if shouldShowUI {
            settings.hasLaunchedAppBefore = true
            showSettingsWindow(nil)
        }
        
        switcher.activate()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(receivedShutdownNotification),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
    }
    
    private lazy var sensorReader = DMBAmbientLightSensorReader(frequency: .realtime)
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lightbulb", accessibilityDescription: "DarkModeBuddy")
            button.image?.isTemplate = true
        }
        
        setupStatusBarMenu()
    }
    
    private func setupStatusBarMenu() {
        let menu = NSMenu()
        
        // Current ambient light level
        let lightLevelItem = NSMenuItem(title: "Ambient Light: --", action: nil, keyEquivalent: "")
        lightLevelItem.tag = 100 // Tag for easy identification when updating
        menu.addItem(lightLevelItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Auto mode toggle
        let autoModeItem = NSMenuItem(title: "Enable Auto Mode", action: #selector(toggleAutoMode(_:)), keyEquivalent: "")
        autoModeItem.tag = 101 // Tag for easy identification when updating
        menu.addItem(autoModeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings option
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettingsWindow(_:)), keyEquivalent: "s"))
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit option
        menu.addItem(NSMenuItem(title: "Quit DarkModeBuddy", action: #selector(terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        // Update menu items periodically
        updateStatusBarMenu()
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStatusBarMenu()
        }
    }
    
    private func updateStatusBarMenu() {
        guard let menu = statusItem.menu else { return }
        
        // Update ambient light level
        if let lightLevelItem = menu.item(withTag: 100) {
            let lightLevel = sensorReader.ambientLightValue
            let formattedLevel = NumberFormatter.noFractionDigits.string(from: NSNumber(value: lightLevel)) ?? "--"
            lightLevelItem.title = "Ambient Light: \(formattedLevel)"
        }
        
        // Update auto mode toggle
        if let autoModeItem = menu.item(withTag: 101) {
            let isEnabled = settings.isChangeSystemAppearanceBasedOnAmbientLightEnabled
            autoModeItem.title = isEnabled ? "Disable Auto Mode" : "Enable Auto Mode"
            autoModeItem.state = isEnabled ? .on : .off
        }
    }
    
    @objc private func toggleAutoMode(_ sender: NSMenuItem) {
        settings.isChangeSystemAppearanceBasedOnAmbientLightEnabled = !settings.isChangeSystemAppearanceBasedOnAmbientLightEnabled
        updateStatusBarMenu()
    }

    @IBAction func showSettingsWindow(_ sender: Any?) {
        NSApp.setActivationPolicy(.regular)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 385, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Settings")
        window.titlebarAppearsTransparent = true
        window.title = "DarkModeBuddy Settings"
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.isReleasedWhenClosed = false
        
        let view = SettingsView()
            .environmentObject(sensorReader)
            .environmentObject(settings)
        
        window.contentView = NSHostingView(rootView: view)
        
        window.makeKeyAndOrderFront(nil)
        window.center()
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @IBAction func terminate(_ sender: Any?) {
        // No need to confirm on quit if the user's Mac is not supported.
        shouldSkipTerminationConfirmation = !sensorReader.isSensorReady
        
        NSApp.terminate(sender)
    }

    private var isShowingSettingsWindow: Bool {
        guard let window = window else { return false }
        return window.isVisible
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !isShowingSettingsWindow else { return true }
        
        showSettingsWindow(nil)
        
        return true
    }
    
    private var shouldShowSettingsOnNextLaunch: Bool {
        get {
            let value = UserDefaults.standard.bool(forKey: #function)
            
            if value {
                // Reset flag
                UserDefaults.standard.set(false, forKey: #function)
            }
            
            return value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: #function)
            UserDefaults.standard.synchronize()
        }
    }
    
    private var shouldSkipTerminationConfirmation = false
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !shouldSkipTerminationConfirmation else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "Quit DarkModeBuddy?"
        alert.informativeText = "If you quit DarkModeBuddy, it won't be able to monitor your ambient light level and change the system theme automatically."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")

        let result = alert.runModal()

        if result == .alertFirstButtonReturn {
            return .terminateNow
        } else {
            return .terminateCancel
        }
    }
    
    @objc func receivedShutdownNotification(_ note: Notification) {
        shouldSkipTerminationConfirmation = true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
        sensorReader.invalidate()
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

}

extension AppDelegate: NSWindowDelegate {

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        window = nil
    }
    
}

extension AppDelegate: SUUpdaterDelegate {
    
    func updaterWillRelaunchApplication(_ updater: SUUpdater) {
        shouldSkipTerminationConfirmation = true
        shouldShowSettingsOnNextLaunch = true
    }
    
    func updater(_ updater: SUUpdater, didCancelInstallUpdateOnQuit item: SUAppcastItem) {
        shouldSkipTerminationConfirmation = false
    }
    
}
