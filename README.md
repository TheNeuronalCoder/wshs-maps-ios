# WSHS Maps
[![preview](https://i.ibb.co/4gsnCyW/preview.png)](https://apps.apple.com/app/wshs-maps/id1638877055)

## Description
Get walking directions to anywhere in West Springfield High School with WSHS Maps.

## How I made it
I scanned physical paper maps of West Springfield High School and created this internal [map builder](https://wshs-map-builder.theneuron.repl.co/floor-editor.html) tool to vectorize the map and convert it to the SVG format. I, essentially, traced over the map with thousands of lines to create a vector replica. I also made a JSON for each floor with data about the shapes and positions for rooms, staircases, hallways, and elevators as well as the physical location and orientation of the floors. Using all the data, I created an algorithm that constructs a graph of the school and my backend server utilizes that graph to compute the shortest path between classes. The app and website are able to track where you are in the school by using that physical location and orientation data of the floors to convert your latitude and longitude to local coordinates within the school using trigonometric formulas I developed.

### Languages
- Frontend: Swift (SwiftUI)
- Backend: Javascript (Node + Express)

## Author
I, Menelik Eyasu, developed the backend, website, and iOS app for WSHS Maps.
