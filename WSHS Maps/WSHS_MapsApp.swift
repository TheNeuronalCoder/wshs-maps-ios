//
//  WSHS_MapsApp.swift
//  WSHS Maps
//
//  Created by Menelik Eyasu on 12/20/21.
//

import SwiftUI

@main
struct WSHS_MapsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
