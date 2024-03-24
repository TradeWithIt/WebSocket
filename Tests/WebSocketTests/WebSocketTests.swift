import XCTest
@testable import WebSocket

final class WebSocketTests: XCTestCase {
    func testWebSocket() throws {
        let websocket = WebSocket()
        
        XCTAssertFalse(websocket.isConnected)
        XCTAssertNotNil(websocket)
        
        let request = URLRequest(url: URL(string: "wss:my-url")!)
        try websocket.connect(to: request) { socket in
            socket.onText { ws, text in
                
            }
            socket.onData { ws, data in
                
            }
            socket.onClose { ws in
                
            }
        }
    }
    
    func testUtils() throws {
        XCTAssertNotNil(WebSocket.Utils.jsonDecoder)
        XCTAssertNotNil(WebSocket.Utils.jsonEncoder)
        XCTAssertNotNil(WebSocket.Utils.customDateFormatter)
    }
    
    func testOverrideDecoder() throws {
        let customDecoder = JSONDecoder()
        WebSocket.Utils.jsonDecoder = customDecoder
        XCTAssertTrue(customDecoder === WebSocket.Utils.jsonDecoder)
    }
}
