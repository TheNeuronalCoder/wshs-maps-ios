//
//  Settings.swift
//  WSHS Maps
//
//  Created by Menelik Eyasu on 2/14/22.
//

import SwiftUI

struct Settings: View {
    var close: (() -> Void)?

    @AppStorage("distance_units") private var distance_units = "m"
    @AppStorage("conversion_factor") private var conversion_factor = 1.0
    @AppStorage("use_elevators") private var use_elevators = false

    var body: some View {
        VStack {
            HStack {
                Button(action: { close?() }) {
                    Image("back")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.black)
                        .frame(width: 35, height: 35)
                        .padding(.trailing, 20)
                }
                Text("Settings")
                    .font(Font.custom("Inter-ExtraBold", size: 40))
                Spacer()
            }.padding(.top, 30)

            HStack {
                Text("Distance Units")
                Picker("Mode", selection: $distance_units) {
                    Text("Meters").tag("m")
                    Text("Feet").tag("ft")
                    Text("Yards").tag("yd")
                }.pickerStyle(SegmentedPickerStyle())
                 .onChange(of: distance_units, perform: { unit in
                     switch unit {
                         case "ft":
                             conversion_factor = 3.280839895
                         case "yd":
                             conversion_factor = 1.093613298
                         default:
                             conversion_factor = 1.0
                     }
                 })
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Use Elevators").font(Font.custom("Inter-Bold", size: 25))
                    Text("Enable this option to utilize the school elevator in your route, instead of the stairs.")
                        .font(Font.custom("Inter-Regular", size: 16))
                        .foregroundColor(Color(red: 0.376470588, green: 0.403921569, blue: 0.439215686))
                }
                Toggle("Use Elevators", isOn: $use_elevators).labelsHidden()
            }
            Spacer()
        }.padding(.horizontal, 30)
         .background(.white)
         .navigationBarTitle("")
         .navigationBarHidden(true)
         .navigationBarBackButtonHidden(true)
    }
}
