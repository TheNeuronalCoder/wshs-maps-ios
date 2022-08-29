# WSHS Maps
![preview](https://i.ibb.co/4gsnCyW/preview.png)

## Description
Get walking directions to anywhere in West Springfield High School with WSHS Maps.

## How I made it
I scanned physical paper maps of West Springfield High School and created this personal [digital map builder](https://wshs-map-builder.theneuron.repl.co/floor-editor.html) to digitize the map and convert it into a vector format. I, essentially, traced over the map with thousands of lines to create a vector replica. I also made a JSON for each floor with data about the shapes and positions for rooms, staircases, hallways, and elevators as well as the physical location and orientation of the floors. Using all the data, I created an algorithm that constructs a graph of the school and my backend server utilizes that graph to calculate the shortest path between classes. The app and website are able to track where you are in the school by using that physical location and orientation data of the floors to convert your latitude and longitude to local coordinates within the school using trigonometric formulas I developed. The altitude sensor on most phones isn't accurate enough for the app to accurately find what floor the user is on, so the user has to specify the floor they are on in the app.

### Languages
- Frontend: Swift (SwiftUI)
- Backend: Javascript (Node + Express)

## Author
I, Menelik Eyasu, created the backend, website, and iOS app for WSHS Maps.
