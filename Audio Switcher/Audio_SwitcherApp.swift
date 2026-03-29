//
//  Audio_SwitcherApp.swift
//  Audio Switcher
//
//  Created by David Pedersen on 29/03/2026.
//

import SwiftUI

@main
struct Audio_SwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
