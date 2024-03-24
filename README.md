# WebSocket
WebSocket client for **Apple** platforms build on top of Foundation `URLSessionWebSocketTask`

## Usage

Set auth:
```
import WebSocket

let websocket = WebSocket()
let request = URLRequest(url: URL(string: "wss:my-url")!)

try websocket.connect(to: request) { socket in
    socket.onText { ws, text in
        
    }
    socket.onData { ws, data in
        
    }
    socket.onClose { ws in
        
    }
}
```

## Installation

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the swift compiler.

Once you have your Swift package set up, adding a dependency is as easy as adding it to the dependencies value of your Package.swift.

Add the package dependency in your Package.swift:
```
dependencies: [
    .package(url: "https://github.com/TradeWithIt/WebSocket", branch: "main")
]
```
Next, in your target, add OpenAPIURLSession to your dependencies:
```
.target(name: "MyTarget", dependencies: [
    .product(name: "WebSocket", package: "WebSocket"),
]),
```
