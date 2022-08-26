//
//  ContentView.swift
//  WSHS Maps
//
//  Created by Menelik Eyasu on 12/20/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @AppStorage("dark_mode") private var dark_mode = false

    init() {
        UINavigationBar.setAnimationsEnabled(false)
    }

    var body: some View {
        NavigationView {
            Home()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
