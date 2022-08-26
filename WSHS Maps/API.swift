//
//  API.swift
//  WSHS Maps
//
//  Created by Menelik Eyasu on 12/24/21.
//

import SwiftUI

struct Orientation: Decodable {
    var angle: Double
    var scale: [Double]
    var origin: [Double]
}

struct Staircase: Decodable {
    var openings: [[Double]]
    var boundary_box: [[Double]]
    var global_stair_index: String
}

struct Room: Decodable, Hashable {
    var name: String
    var openings: [[Double]]
    var text_boundary: [Double]
    var boundary_box: [[Double]]
}

struct Metadata: Decodable {
    var width: Int
    var height: Int
    var outline: String
    var rooms: [Room]
    var hallways: [[Double]]
    var staircases: [Staircase]
    var orientation: Orientation
}

struct Floor: Decodable {
    var path: String
    var metadata: Metadata
}

struct Trail: Decodable {
    var floor: Int
    var path: String
}

struct Route: Decodable {
    var distance: Double = 0
    var path: [Trail] = [Trail]()
    var directions: [String] = [String]()
}

class API {
    static func fetch_data(onFetch: @escaping ([Int: Floor]?) -> ()) {
        guard let url = URL(string: "https://monkfish-app-4ffx2.ondigitalocean.app/map") else {
            onFetch(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else {
                onFetch(nil)
                return
            }
            do {
                let res = try JSONDecoder().decode([Int: Floor].self, from: data)
                onFetch(res)
            } catch {
                onFetch(nil)
                return
            }
        }.resume()
    }

    static func find_route(start: [[Double]], end: [[Double]], elevators: Bool, onFind: @escaping (Route?) -> ()) {
        guard let url = URL(string: "https://monkfish-app-4ffx2.ondigitalocean.app/route") else {
            onFind(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "start": start,
            "end": end,
            "use_elevators": elevators
        ])

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                onFind(nil)
                return
            }
            do {
                let json_data = try JSONDecoder().decode(Route.self, from: data)
                onFind(json_data)
            } catch {
                onFind(nil)
                return
            }
        }.resume()
    }
}
