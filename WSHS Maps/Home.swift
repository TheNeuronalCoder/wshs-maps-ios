//
//  Home.swift
//  WSHS Maps
//
//  Created by Menelik Eyasu on 2/14/22.
//

import SwiftUI
import Foundation

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoomSelection {
    var name: String
    var floor: Int
    var icon: String

    init(name: String = "", floor: Int = 0) {
        self.name = name
        self.floor = floor
        self.icon = name == "Main Office"
                  ? "office"
                  : name == "Cafeteria"
                  ? "cafeteria"
                  : name == "Clinic"
                  ? "clinic"
                  : name == "Library"
                  ? "library"
                  : name == "Auditorium"
                  ? "auditorium"
                  : name == "Main Gym" || name == "Aux Gym"
                  ? "gym"
                  : name == "Boys Locker Room" || name == "Girls Locker Room"
                  ? "locker"
                  : name == "Weight Room"
                  ? "weights"
                  : name == "Wrestling Room"
                  ? "wrestling"
                  : name == "Studio"
                  ? "studio"
                  : "classroom"
    }
}

struct Home: View {
    @AppStorage("distance_units") private var distance_units = "m"
    @AppStorage("conversion_factor") private var conversion_factor = 1.0
    @AppStorage("use_elevators") private var use_elevators = false

    @State private var map_load_rotation: Double = 360
    @State private var route_load_rotation: Double = 360

    @State private var floors: [Int: Floor] = [:]
    @State private var rooms: [RoomSelection] = [RoomSelection]()

    @State private var recenter: Bool = false
    @State private var route: Route = Route()
    @StateObject var location = LocationManager()
    @State private var following_route: Bool = false
    @State private var fullscreen_directions: Bool = false

    @State private var open_popup: Bool = false
    @State private var route_end: String = ""
    @State private var route_start: String = "My Location"
    @FocusState private var route_end_focused: Bool
    @FocusState private var route_start_focused: Bool
    @State private var room_selection: RoomSelection = RoomSelection()
    @State private var route_suggestions: [RoomSelection] = [RoomSelection]()

    @State private var current_floor: Int = 2

    @State private var select_floor: Bool = false
    @State private var edit_settings: Bool = false

    @State private var scale: CGFloat = 1.0
    @State private var magnify: CGFloat = 1.0
    @State private var drag = CGPoint(x: 0, y: 0)
    @State private var translate = CGPoint(x: 0, y: 0)

    @State private var search: String = ""
    @State private var show_searchbar: Bool = false
    @State private var search_suggestions: [RoomSelection] = [RoomSelection]()
    
    init() {
        UISegmentedControl.appearance().backgroundColor = .clear
        UISegmentedControl.appearance().selectedSegmentTintColor = .white
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .normal)
    }

    func recenter_view(height: CGFloat) {
        if location.initialized {
            withAnimation(.spring()) {
                self.scale = 1
                self.translate.x = UIScreen.main.bounds.size.width/2 - self.location.x
                self.translate.y = height/2 - self.location.y
            }

            self.recenter = false
        }
    }

    func find_floor(name: String) -> Int {
        if name == "My Location" {
            return self.location.z
        }

        for (floor_num, floor) in self.floors {
            for room in floor.metadata.rooms {
                if room.name == name {
                    return floor_num
                }
            }
        }

        return 0
    }

    func find_location(name: String) -> [[Double]] {
        var openings: [[Double]] = []
        if name == "My Location" {
            openings.append([Double(self.location.z), self.location.x, self.location.y])
            return openings
        }

        self.floors.forEach { (floor_num, floor) in
            for room in floor.metadata.rooms {
                if room.name == name {
                    openings = room.openings.map({ [Double(floor_num), $0[0], $0[1]] })
                }
            }
        }

        return openings
    }

    func search_rooms(query: String, n: Int, cl: Bool = false) -> [RoomSelection] {
        var suggestions: [RoomSelection] = [RoomSelection]()
        if cl && location.initialized {
            suggestions.append(RoomSelection(name: "My Location"))
        }
        if query.isEmpty { return suggestions }
        for room in self.rooms {
            if room.name.lowercased().hasPrefix(query.lowercased()) {
                suggestions.append(room)

                if suggestions.count >= n {
                    break
                }
            }
        }

        return suggestions
    }

    func valid_room(name: String) -> Bool {
        if name == "My Location" {
            return true
        }

        for room in self.rooms {
            if room.name == name {
                return true
            }
        }

        return false
    }

    func update_path() {
        if !valid_room(name: self.route_start) { self.route = Route() }
        if !valid_room(name: self.route_end) { self.route = Route() }

        API.find_route(start: find_location(name: self.route_start), end: find_location(name: self.route_end), elevators: self.use_elevators, onFind: { r in
            if let rt = r {
                self.route = rt
            }
        })
    }

    var body: some View {
        GeometryReader { screen in
            ZStack {
                Canvas { context, size in
                }.background(Color(red: 0.980392157, green: 0.968627451, blue: 0.941176471))
                 .ignoresSafeArea()
                 .onTapGesture {
                     UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to:nil, from:nil, for:nil)
                 }
                 .gesture(DragGesture().onChanged { value in
                     self.translate.x += (value.translation.width - self.drag.x) / self.scale
                     self.translate.y += (value.translation.height - self.drag.y) / self.scale
                     self.drag.x = value.translation.width
                     self.drag.y = value.translation.height
                     if self.following_route && !self.recenter { self.recenter = true }
                 }.onEnded { value in
                     self.drag.x = 0
                     self.drag.y = 0
                 })
                 .gesture(MagnificationGesture().onChanged { value in
                     let new_scale = self.scale * value.magnitude / self.magnify
                     if (new_scale < 2 && new_scale > 0.2) {
                         self.scale = new_scale
                     }
                     self.magnify = value.magnitude

                     if self.following_route && !self.recenter { self.recenter = true }
                 }.onEnded { value in self.magnify = 1 })
                  .onAppear {
                      API.fetch_data { data in
                          if let floor_data = data {
                              self.floors = floor_data
                              if let floor = self.floors[self.current_floor] {
                                  self.scale = UIScreen.main.bounds.size.width / CGFloat(floor.metadata.width)
                                  self.translate.x = (UIScreen.main.bounds.size.width-CGFloat(floor.metadata.width)) / 2
                                  self.translate.y = (screen.size.height-CGFloat(floor.metadata.height)) / 2
                              }

                              self.floors.forEach { (floor_num, floor) in
                                  for room in floor.metadata.rooms {
                                      self.rooms.append(RoomSelection(name: room.name, floor: floor_num))
                                  }
                              }

                              location.set_metadata(floors: floor_data)
                          }
                      }
                  }
                  .onChange(of: location.initialized, perform: { init_status in
                      if init_status {
                          self.recenter_view(height: screen.size.height)
                      }
                  })
                  .onChange(of: location.updates, perform: { _ in
                      if self.location.initialized && self.following_route && !self.recenter {
                          self.recenter_view(height: screen.size.height)
                      }

                      self.update_path()
                  })

                if floors[current_floor] != nil {
                    ForEach(floors[current_floor]!.metadata.rooms, id: \.self) { room in
                        if room_selection.name == room.name || route_start == room.name || route_end == room.name {
                            Path { path in
                                path.move(to: CGPoint(x: room.boundary_box[0][0], y: room.boundary_box[0][1]))
                                for i in 1..<room.boundary_box.count {
                                    path.addLine(to: CGPoint(x: room.boundary_box[i][0], y: room.boundary_box[i][1]))
                                }
                                path.closeSubpath()
                            }.fill(Color(red: 0.933333333, green: 0.921568627, blue: 0.890196078))
                             .offset(x: translate.x, y: translate.y)
                             .scaleEffect(scale)
                        }
                    }

                    Path { path in
                        if let floor = self.floors[self.current_floor] {
                            for line_str in floor.path.split(separator: "M") {
                                let line = line_str.split { ["L", ","].contains($0.description) }.map({Double($0) ?? 0})
                                path.move(to: CGPoint(x: line[0], y: line[1]))
                                path.addLine(to: CGPoint(x: line[2], y: line[3]))
                            }
                        }
                    }.stroke(Color(red: 0.623529412, green: 0.619607843, blue: 0.611764706), style: StrokeStyle(lineCap: .round))
                     .offset(x: translate.x, y: translate.y)
                     .scaleEffect(scale)

                    ForEach(self.floors[current_floor]!.metadata.rooms, id: \.self) { room in
                        Text(room.name)
                            .foregroundColor(Color(red: 0.623529412, green: 0.619607843, blue: 0.611764706))
                            .minimumScaleFactor(0.1)
                            .multilineTextAlignment(.center)
                            .frame(
                                width: room.text_boundary[2]-room.text_boundary[0]-8,
                                height: room.text_boundary[3]-room.text_boundary[1]-4
                            )
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .position(
                                x: (room.text_boundary[0]+room.text_boundary[2])/2,
                                y: (room.text_boundary[1]+room.text_boundary[3])/2
                            )
                            .offset(x: translate.x, y: translate.y)
                            .scaleEffect(scale)
                    }

                    if self.route.distance > 0 {
                        Path { path in
                            for trail in self.route.path {
                                if trail.floor == self.current_floor {
                                    var points = trail.path.split(separator: "L").map({
                                        $0.split { ["M", ","].contains($0.description) }.map({Double($0) ?? 0})
                                    })
                                    path.move(to: CGPoint(x: points[0][0], y: points[0][1]))
                                    points.removeFirst()
                                    for pt in points {
                                        path.addLine(to: CGPoint(x: pt[0], y: pt[1]))
                                    }
                                }
                            }
                        }.stroke(Color(red: 0.48627451, green: 0.725490196, blue: 0.909803922), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                         .offset(x: translate.x, y: translate.y)
                         .scaleEffect(scale)
                    }

                    if current_floor == location.z && location.initialized {
                        ZStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 75, height: 75)
                                .opacity(0.5)

                            Circle()
                                .strokeBorder(.white, lineWidth: 5)
                                .background(Circle().fill(.blue))
                                .frame(width: 30, height: 30)
                        }.position(CGPoint(x: location.x, y: location.y))
                         .offset(x: translate.x, y: translate.y)
                         .scaleEffect(scale)
                    }
                } else {
                    ZStack {
                        Image("spartan")
                          .resizable()
                          .aspectRatio(contentMode: .fit)
                          .frame(height: 100)

                        Circle()
                            .trim(from: 1/2, to: 1)
                            .stroke(lineWidth: 5)
                            .frame(width: 150, height: 150)
                            .foregroundColor(Color(red: 0.623529412, green: 0.619607843, blue: 0.611764706))
                            .rotationEffect(.degrees(map_load_rotation))
                            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: map_load_rotation)
                            .onAppear {
                                if self.map_load_rotation == 0 { self.map_load_rotation = 360 }
                                else { self.map_load_rotation = 0 }
                            }
                    }
                }

                VStack(alignment: .trailing, spacing: 0) {
                    if following_route && !route.directions.isEmpty {
                        Button(action: {
                            withAnimation {
                                self.fullscreen_directions.toggle()
                            }
                        }) {
                            VStack(spacing: 20) {
                                HStack(alignment: .top) {
                                    Image(route.directions[0] == "Turn right"
                                          ? "turn-right"
                                          : route.directions[0] == "Turn left"
                                          ? "turn-left"
                                          : route.directions[0] == "Go down the stairs"
                                          ? "go-down"
                                          : "go-straight")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .padding(.trailing, 20)
                                    Text(route.directions[0])
                                        .font(Font.custom("Inter-ExtraBold", size: 40))
                                        .foregroundColor(.white)
                                    Spacer()
                                }.frame(maxWidth: .infinity)
                                 .padding(.top, 20)
                                 .padding(.horizontal, 40)

                                Image("up")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .rotationEffect(.degrees(fullscreen_directions ? 0 : 180))
                                    .padding(.leading, 20)
                                    .padding(.bottom, 20)
                            }.background(Color(red: 0.109803922, green: 0.109803922, blue: 0.11372549))
                        }
                    } else {
                        HStack(alignment: .top) {
                            if valid_room(name: route_start) && valid_room(name: route_end) && route.directions.isEmpty {
                                Circle()
                                    .trim(from: 1/2, to: 1)
                                    .stroke(lineWidth: 3)
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.blue)
                                    .rotationEffect(.degrees(route_load_rotation))
                                    .padding(.leading, 25)
                                    .animation(Animation.linear(duration: 0.5).repeatForever(autoreverses: false), value: route_load_rotation)
                                    .onAppear {
                                        if self.route_load_rotation == 0 { self.route_load_rotation = 360 }
                                        else { self.route_load_rotation = 0 }
                                    }

                                Spacer()
                            }

                            VStack(spacing: 0) {
                                HStack {
                                    if show_searchbar {
                                        TextField("Search WSHS", text: $search)
                                            .textInputAutocapitalization(.never)
                                            .disableAutocorrection(true)
                                            .font(Font.custom("Inter-Regular", size: 19))
                                            .onChange(of: search) { query in
                                                self.search_suggestions = search_rooms(query: query, n: 4)
                                            }
                                    }
                                    Button(action: {
                                        withAnimation { self.show_searchbar.toggle() }
                                        self.search = ""
                                        self.search_suggestions.removeAll()
                                    }) {
                                        Image("search")
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(.black)
                                            .frame(width: show_searchbar ? 20 : 32, height: show_searchbar ? 20 : 32)
                                    }
                                }.padding(.top, show_searchbar ? 12 : 0)
                                 .padding(.bottom, show_searchbar ? 12 : 0)
                                 .padding(.horizontal, show_searchbar ? 20 : 0)

                                if show_searchbar {
                                    if !search_suggestions.isEmpty{
                                        Divider()
                                            .padding(.horizontal, 10)
                                            .padding(.bottom, 10)
                                    }

                                    ForEach(search_suggestions, id: \.name) { suggestion in
                                        Button(action: {
                                            self.search = ""
                                            self.open_popup = true
                                            self.show_searchbar.toggle()
                                            self.room_selection = suggestion
                                            self.search_suggestions.removeAll()

                                            self.current_floor = self.find_floor(name: self.room_selection.name)
                                            if let floor = self.floors[self.current_floor] {
                                                self.scale = UIScreen.main.bounds.size.width / CGFloat(floor.metadata.width)
                                                self.translate.x = (UIScreen.main.bounds.size.width-CGFloat(floor.metadata.width)) / 2
                                                print(floor.metadata.height)
                                            }
                                        }) {
                                            HStack {
                                                Image("destination")
                                                    .resizable()
                                                    .renderingMode(.template)
                                                    .foregroundColor(Color(red: 133/255, green: 155/255, blue: 166/255))
                                                    .frame(width: 20, height: 20)

                                                Text(suggestion.name)
                                                    .font(Font.custom("Inter-Regular", size: 19))
                                                    .foregroundColor(Color(red: 133/255, green: 155/255, blue: 166/255))

                                                Spacer()
                                            }.padding(.bottom, 15)
                                             .padding(.leading, 20)
                                             .padding(.trailing, 10)
                                        }
                                    }
                                }
                            }.background(show_searchbar ? .white : .black.opacity(0))
                             .cornerRadius(10)
                             .padding(.leading, 15)
                             .padding(.trailing, show_searchbar ? 12 : 0)
                             .shadow(color: .black.opacity(0.2), radius: show_searchbar ? 3 : 0)

                            if !show_searchbar {
                                Button(action: {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    self.select_floor = true
                                }) {
                                    Image("level")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.black)
                                        .frame(width: 32, height: 32)
                                }.disabled(floors[current_floor] == nil)

                                Button(action: {
                                    self.edit_settings = true
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to:nil, from:nil, for:nil)
                                }) {
                                    Image("tune")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.black)
                                        .frame(width: 32, height: 32)
                                        .padding(.trailing, 25)
                                }
                            }
                        }.padding(.top, 10)
                    }

                    if fullscreen_directions {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(route.directions.dropFirst(), id: \.self) { direction in
                                    HStack {
                                        Image(direction == "Turn right"
                                              ? "turn-right"
                                              : direction == "Turn left"
                                              ? "turn-left"
                                              : direction == "Go down the stairs"
                                              ? "go-down"
                                              : "go-straight")
                                            .resizable()
                                            .frame(width: 40, height: 40)
                                            .padding(.trailing, 20)
                                        Text(direction)
                                            .font(Font.custom("Inter-ExtraBold", size: 40))
                                            .foregroundColor(.white)
                                        Spacer()
                                    }.padding(.vertical, 30)
                                     .padding(.horizontal, 60)
                                }
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                         .background(Color(red: 0.192156863, green: 0.192156863, blue: 0.207843137))
                         .transition(.move(edge: .top))
                    } else {
                        Spacer()

                        if following_route && recenter && location.initialized {
                            Button(action: { self.recenter_view(height: screen.size.height) }) {
                                Text("Recenter")
                                    .font(Font.custom("Inter-ExtraBold", size: 18))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 20)
                                    .background(.blue)
                                    .clipShape(Capsule())
                                    .padding(.bottom, 15)
                                    .padding(.trailing, 25)
                            }
                        }

                        VStack(spacing: 0) {
                            if room_selection.name.isEmpty {
                                Button(action: { withAnimation { self.open_popup.toggle() } }) {
                                    Capsule()
                                        .fill(Color(red: 0.6, green: 0.6, blue: 0.6))
                                        .frame(width: 50, height: 10)
                                        .padding(.bottom, open_popup ? 10 : 0)
                                        .frame(maxWidth: .infinity)
                                }.buttonStyle(.plain)
                            } else {
                                Button(action: { room_selection = RoomSelection() }) {
                                    Image("exit")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                        .frame(width: 30, height: 30)
                                        .padding(.top, 5)
                                }.buttonStyle(.plain)
                                 .frame(maxWidth: .infinity, alignment: .trailing)
                            }

                            if open_popup && following_route {
                                VStack {
                                    Text("\(Int(route.distance*conversion_factor))\(distance_units)")
                                        .font(Font.custom("Inter-Bold", size: 30))
                                        .foregroundColor(.black)

                                    if route_start == "My Location" {
                                        HStack {
                                            Text("Floor")
                                                .font(Font.custom("Inter-Regular", size: 16))
                                                .foregroundColor(.black)

                                            Picker("Mode", selection: $location.z) {
                                                ForEach(floors.keys.sorted(), id: \.self) { floor_num in
                                                    Text("\(floor_num)").tag(floor_num)
                                                }
                                            }.pickerStyle(SegmentedPickerStyle())
                                             .onChange(of: location.z, perform: { new_z in
                                                 self.current_floor = new_z
                                                 self.location.update_position(
                                                    lat: self.location.latitude,
                                                    long: self.location.longitude,
                                                    z: new_z
                                                 )
                                                 self.route = Route()
                                                 self.update_path()
                                             })
                                        }
                                    }
                                }

                                Button(action: {
                                    self.route = Route()
                                    self.route_start = ""
                                    self.route_end = ""
                                    self.following_route = false
                                }) {
                                    Text("End")
                                        .font(Font.custom("Inter-ExtraBold", size: 18))
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                        .padding(.top, 10)
                                }
                            } else if open_popup && room_selection.name.isEmpty {
                                Text("Route")
                                    .font(Font.custom("Inter-ExtraBold", size: 35))
                                    .foregroundColor(.black)
                                ZStack(alignment: .topLeading) {
                                    VStack(spacing: 0) {
                                        HStack {
                                            if route_start == "My Location" {
                                                Menu {
                                                    Picker(selection: $location.z, label: EmptyView()) {
                                                        ForEach(floors.keys.sorted().reversed(), id: \.self) { floor_num in
                                                            Text("\(floor_num)").tag(floor_num)
                                                        }
                                                    }.labelsHidden()
                                                     .pickerStyle(InlinePickerStyle())
                                                     .onChange(of: location.z, perform: { new_z in
                                                         self.location.update_position(
                                                            lat: self.location.latitude,
                                                            long: self.location.longitude,
                                                            z: new_z
                                                         )
                                                         self.update_path()
                                                     })
                                                } label: {
                                                    Text("\(location.z)")
                                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                                        .font(Font.custom("Inter-Regular", size: 18))
                                                    Image("down")
                                                        .resizable()
                                                        .frame(width: 10, height: 10)
                                                        .padding(.leading, -3)
                                                }
                                            }

                                            TextField("Current Location", text: $route_start)
                                                .textInputAutocapitalization(.never)
                                                .disableAutocorrection(true)
                                                .focused($route_start_focused)
                                                .font(Font.custom("Inter-Regular", size: 18))
                                                .foregroundColor(.black)
                                                .onChange(of: route_start) { query in
                                                    self.update_path()
                                                    self.route_suggestions = self.search_rooms(query: query, n: 3, cl: true)
                                                }
                                                .onChange(of: route_start_focused) { start_focus in
                                                    self.route_suggestions = self.search_rooms(query: start_focus ? self.route_start : self.route_end, n: 3, cl: start_focus)
                                                }
                                            Image("search")
                                                .resizable()
                                                .renderingMode(.template)
                                                .foregroundColor(.black.opacity(0.4))
                                                .frame(width: 18, height: 18)
                                        }.padding(.vertical, 12)
                                         .padding(.horizontal, 20)
                                         .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                                         .cornerRadius(10, corners: route_start_focused && !route_suggestions.isEmpty ? [.topLeft, .topRight] : .allCorners)
                                         .padding(.top, 10)

                                        HStack {
                                            TextField("Destination", text: $route_end)
                                                .textInputAutocapitalization(.never)
                                                .disableAutocorrection(true)
                                                .focused($route_end_focused)
                                                .font(Font.custom("Inter-Regular", size: 18))
                                                .foregroundColor(.black)
                                                .onChange(of: route_end) { query in
                                                    self.update_path()
                                                    self.route_suggestions = self.search_rooms(query: query, n: 3, cl: self.route_start_focused)
                                                }
                                                .onChange(of: route_end_focused) { end_focus in
                                                    self.route_suggestions = self.search_rooms(query: self.route_start_focused ? self.route_start : route_end, n: 3, cl: self.route_start_focused)
                                                }
                                            Image("search")
                                                .resizable()
                                                .renderingMode(.template)
                                                .foregroundColor(.black.opacity(0.4))
                                                .frame(width: 18, height: 18)
                                        }.padding(.vertical, 12)
                                         .padding(.horizontal, 20)
                                         .background(route_start_focused && !route_suggestions.isEmpty
                                                   ? Color(red: 0.9, green: 0.9, blue: 0.9)
                                                   : Color(red: 0.95, green: 0.95, blue: 0.95))
                                         .cornerRadius(10, corners: route_end_focused && !route_suggestions.isEmpty ? [.topLeft, .topRight] : .allCorners)
                                         .padding(.top, 10)

                                        if route_start_focused || route_end_focused {
                                            Spacer()
                                        } else if valid_room(name: route_start) && valid_room(name: route_end) {
                                            Button(action: {
                                                self.following_route = true
                                                self.current_floor = self.find_floor(name: self.route_start)
                                                self.recenter_view(height: screen.size.height)
                                            }) {
                                                Text("Start")
                                                    .font(Font.custom("Inter-ExtraBold", size: 18))
                                                    .padding(.vertical, 12)
                                                    .frame(maxWidth: .infinity)
                                                    .background(route.directions.isEmpty ? .blue.opacity(0.5) : .blue)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(10)
                                                    .padding(.top, 10)
                                            }.disabled(route.directions.isEmpty)
                                        }
                                    }.onTapGesture {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to:nil, from:nil, for:nil)
                                    }

                                    if (route_start_focused || route_end_focused) && !route_suggestions.isEmpty {
                                        VStack(spacing: 0) {
                                            ForEach(route_suggestions, id: \.name) { room in
                                                Button(action: {
                                                    if self.route_start_focused {
                                                        self.route_start = room.name
                                                        self.route_start_focused.toggle()
                                                    } else {
                                                        self.route_end = room.name
                                                        self.route_end_focused.toggle()
                                                    }
                                                }) {
                                                    HStack {
                                                        Image(room.name == "My Location" ? "my-location" : "destination")
                                                            .resizable()
                                                            .renderingMode(.template)
                                                            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                                            .frame(width: 20, height: 20)
                                                            .padding(.leading, 20)
                                                        Text(room.name)
                                                            .font(Font.custom("Inter-Regular", size: 18))
                                                          .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                                        Spacer()
                                                    }.padding(.vertical, 12)
                                                     .frame(maxWidth: .infinity)
                                                }
                                            }
                                        }.background(Color(red: 0.95, green: 0.95, blue: 0.95))
                                         .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
                                         .padding(.top, route_start_focused ? 52 : 114)
                                    }
                                }
                            } else if open_popup {
                                Image(room_selection.icon)
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.black)
                                Text(room_selection.name)
                                    .font(Font.custom("Inter-ExtraBold", size: 35))
                                    .foregroundColor(.black)
                                Text("\(room_selection.name), Floor \(room_selection.floor)")
                                    .font(Font.custom("Inter-Regular", size: 20))
                                    .foregroundColor(.black)
                                    .padding(.bottom, 20)

                                VStack {
                                    Button(action: {
                                        self.route_start = room_selection.name
                                        self.room_selection = RoomSelection()
                                    }) {
                                        HStack {
                                            Image("destination")
                                                .resizable()
                                                .renderingMode(.template)
                                                .frame(width: 30, height: 30)
                                                .foregroundColor(.blue)
                                                .padding(.leading, 18)
                                            Text("Set Start")
                                                .font(Font.custom("Inter-Bold", size: 20))
                                                .foregroundColor(.blue)
                                                .padding(.vertical, 10)
                                            Spacer()
                                        }.frame(maxWidth: .infinity)
                                         .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(.blue, lineWidth: 3)
                                         )
                                    }
                                    Button(action: {
                                        self.route_end = room_selection.name
                                        self.room_selection = RoomSelection()
                                    }) {
                                        HStack {
                                            Image("flag")
                                                .resizable()
                                                .renderingMode(.template)
                                                .frame(width: 22, height: 22)
                                                .foregroundColor(.white)
                                                .padding(.leading, 20)
                                            Text("Set Destination")
                                                .font(Font.custom("Inter-Bold", size: 20))
                                                .foregroundColor(.white)
                                                .padding(.vertical, 12)
                                            Spacer()
                                        }.frame(maxWidth: .infinity)
                                         .background(.blue)
                                         .cornerRadius(10)
                                    }
                                }
                            }
                        }.padding(.top, 10)
                         .padding(.bottom, open_popup ? 30 : 10)
                         .padding(.horizontal, 30)
                         .background(.white)
                         .cornerRadius(30)
                         .shadow(color: .black.opacity(0.2), radius: 3)
                    }
                }

                if select_floor {
                    VStack(alignment: .leading) {
                        Button(action: { self.select_floor = false }) {
                            Image("back")
                                .resizable()
                                .renderingMode(.template)
                                .foregroundColor(.white)
                                .frame(width: 35, height: 35)
                                .padding(.leading, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 20)
                        }

                        ForEach(floors.keys.sorted().reversed(), id: \.self) { floor in
                            Button(action: {
                                self.current_floor = floor
                                if let floor = self.floors[floor] {
                                    self.scale = UIScreen.main.bounds.size.width / CGFloat(floor.metadata.width)
                                    self.translate.x = (UIScreen.main.bounds.size.width-CGFloat(floor.metadata.width)) / 2
                                }

                                self.room_selection = RoomSelection()
                                self.open_popup = false
                            }) {
                                ZStack {
                                    Path { path in
                                        if let floor = self.floors[floor] {
                                            let points = floor.metadata.outline.split(separator: "L").map({
                                                $0.split { ["M", "z", ","].contains($0.description) }.map({Double($0) ?? 0})
                                            })
                                            path.move(to: CGPoint(x: points[0][0], y: points[0][1]))
                                            for point in points {
                                                path.addLine(to: CGPoint(x: point[0], y: point[1]))
                                            }
                                            path.addLine(to: CGPoint(x: points[0][0], y: points[0][1]))
                                        }
                                    }.stroke(.blue, lineWidth: 5)
                                     .scaleEffect((UIScreen.main.bounds.size.width-80) / CGFloat(self.floors[floor]!.metadata.width), anchor: .topLeading)

                                    Text("\(floor)")
                                        .font(Font.custom("Inter-ExtraBold", size: 80))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                        .padding(.leading, 20)
                                 }.frame(
                                    width: UIScreen.main.bounds.size.width-80,
                                    height: (CGFloat(self.floors[floor]!.metadata.height)/CGFloat(self.floors[floor]!.metadata.width))*(UIScreen.main.bounds.size.width-80)
                                 )
                            }.padding(.leading, 20)
                        }
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                     .background(.black.opacity(0.7))
                } else if edit_settings {
                    Settings(close: { self.edit_settings = false })
                }

                Spacer()
            }.navigationBarTitle("")
             .navigationBarHidden(true)
             .navigationBarBackButtonHidden(true)
             .preferredColorScheme(following_route ? .dark : .light)
        }
    }
}
