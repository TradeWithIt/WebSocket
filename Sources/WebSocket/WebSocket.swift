import Foundation
#if os(WASI)
import JavaScriptKit

public typealias WebSocketClosure = (_ ws: WebSocket) -> Void
public typealias WebSocketTextClosure = (_ ws: WebSocket,  _ text: String) -> Void
public typealias WebSocketDataClosure = (_ ws: WebSocket,  _ data: Data) -> Void

extension Data {
    func toJSArrayBuffer() -> JSObject? {
        guard let arrayBuffer = JSObject.global.ArrayBuffer.function?.new(count),
              let uint8Array = JSObject.global.Uint8Array.function?.new(arrayBuffer) else {
            return nil
        }

        self.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            for (index, byte) in bytes.enumerated() {
                uint8Array[index] = JSValue(integerLiteral: Int32(byte))
            }
        }

        return arrayBuffer
    }
}

public class WebSocket {
    private var jsWebSocket: JSObject?
    private var pingTimer: JSTimer?
    private var pingInterval: TimeInterval? = nil
    private var onTextClosure: WebSocketTextClosure?
    private var onDataClosure: WebSocketDataClosure?
    private var onCloseClosure: WebSocketClosure?
    private var onConnectClosure: WebSocketClosure?
    
    public private(set) var isConnected: Bool = false
    
    private var onopen: JSClosure?
    private var onmessage: JSClosure?
    private var onclose: JSClosure?
    private var onerror: JSClosure?
    
    deinit {
        close()
        pingTimer?.invalidate()
    }
    
    public init() {}
    
    public func connect(to url: String, pingInterval: TimeInterval? = 30, _ closure: @escaping (WebSocket) -> ()) throws {
        self.onConnectClosure = closure
        self.pingInterval = pingInterval
        try connectWebsocket(url: url)
    }
    
    private func connectWebsocket(url: String) throws {
        guard let webSocket = JSObject.global.WebSocket.function?.new(url) else {
            throw URLError(.badURL)
        }
        webSocket.binaryType = "arraybuffer".jsValue
        jsWebSocket = webSocket
        
        onopen = JSClosure { [weak self] _ in
            guard let self = self else { return .undefined }
            print("🟢 WebSocket connection opened")
            self.runSocketConnectedSequence()
            return .undefined
        }
        
        onmessage = JSClosure { [weak self] args -> JSValue in
            guard let self = self else { return .undefined }
            guard let event = args.first?.object else { return .undefined }

            if let text = event.data.string {
                print("🔴 onmessage text", text)
                self.onTextClosure?(self, text)
            } else if let dataObject = event.data.object,
                      let uint8Array = JSObject.global.Uint8Array.function?.new(dataObject) {
                let length = Int(uint8Array.length.number ?? 0)
                print("🔴 onmessage data", length)

                var data = Data(count: length)
                data.withUnsafeMutableBytes { buffer in
                    guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        print("🔴 Failed to get pointer to data buffer")
                        return
                    }
                    for i in 0..<length {
                        ptr[i] = UInt8(uint8Array[i].number ?? 0)
                    }
                }
                self.onDataClosure?(self, data)
            }
            return .undefined
        }

        onclose = JSClosure { [weak self] value -> JSValue in
            guard let self = self else { return .undefined }
            print("🟢 WebSocket connection closed")
            self.isConnected = false
            self.onCloseClosure?(self)
            return .undefined
        }
        
        onerror = JSClosure { [weak self] error -> JSValue in
            print("🔴 WebSocket error:", error)
            return .undefined
        }
        
        _ = webSocket.addEventListener?("open", onopen)
        _ = webSocket.addEventListener?("message", onmessage)
        _ = webSocket.addEventListener?("close", onclose)
        _ = webSocket.addEventListener?("error", onerror)
    }
    
    public func onText(_ closure: @escaping WebSocketTextClosure) {
        self.onTextClosure = closure
    }
    
    public func onData(_ closure: @escaping WebSocketDataClosure) {
        self.onDataClosure = closure
    }
    
    public func onClose(_ closure: @escaping WebSocketClosure) {
        self.onCloseClosure = closure
    }
    
    public func send(_ data: Data) {
        guard let webSocket = jsWebSocket,
        let buffer = data.toJSArrayBuffer() else { return }
        _ = webSocket.send?(buffer)
    }

    public func send(_ text: String) {
        guard let webSocket = jsWebSocket else { return }
        _ = webSocket.send?(text.jsValue)
    }
    
    public func send<T: Encodable>(_ obj: T) throws {
        let data = try JSONEncoder().encode(obj)
        send(data)
    }
    
    public func ping() {
        _ = jsWebSocket?.send?(JSObject.global.Uint8Array.function!.new(0))
    }
    
    public func close() {
        _ = jsWebSocket?.close?()
        pingTimer?.invalidate()
    }
    
    private func setupPing(pingInterval: TimeInterval?) {
        guard let pingInterval = pingInterval else { return }
        pingTimer = JSTimer(interval: pingInterval, repeats: true) { [weak self] in
            self?.ping()
        }
    }
    
    private func runSocketConnectedSequence() {
        isConnected = true
        onConnectClosure?(self)
        setupPing(pingInterval: pingInterval)
    }
}

#else
import WebSocketKit
import NIO

public typealias WebSocketClosure = (_ ws: WebSocket) -> Void
public typealias WebSocketTextClosure = (_ ws: WebSocket,  _ text: String) -> Void
public typealias WebSocketDataClosure = (_ ws: WebSocket,  _ data: Data) -> Void

public class WebSocket {
    private let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private var client: EventLoopFuture<Void>?
    private var timer: RepeatingTimer?
    private var pingInterval: TimeInterval? = nil
    private var onTextClosure: WebSocketTextClosure?
    private var onDataClosure: WebSocketDataClosure?
    private var onCloseClosure: WebSocketClosure?
    private var onConnectClosure: WebSocketClosure?
    
    public private(set) var isConnected: Bool = false
    private weak var socket: WebSocketKit.WebSocket?
    
    deinit {
        close()
        timer = nil
        client = nil
        try? eventLoopGroup.syncShutdownGracefully()
    }
    
    public init() {}
    
    public func connect(to request: URLRequest, pingInterval: TimeInterval? = 30, _ closure: @escaping (WebSocket) -> ()) throws {
        self.onConnectClosure = closure
        self.pingInterval = pingInterval
        try connectWebsocket(request: request)
    }
    
    private func connectWebsocket(request: URLRequest) throws {
        guard let url = request.url else { throw URLError(.badURL) }
        client = WebSocketKit.WebSocket.connect(
            to: url,
            headers: HTTPHeaders(request.allHTTPHeaderFields?.map({($0.key, $0.value)}) ?? []),
            on: eventLoopGroup) {[weak self] ws in
                self?.socket = ws
                self?.runSocketConnectedSequance()
                ws.onText {[weak self] ws, text in
                    guard let self = self else { return }
                    self.onTextClosure?(self, text)
                }
                ws.onBinary {[weak self] ws, byteBuffer in
                    guard let self = self else { return }
                    self.onDataClosure?(self, Data(buffer: byteBuffer, byteTransferStrategy: .automatic))
                }
                ws.onClose.whenComplete {[weak self] result in
                    guard let self = self else { return }
                    self.isConnected = false
                    self.onCloseClosure?(self)
                }
            }
    }
    
    public func onText(_ closure: @escaping WebSocketTextClosure) {
        self.onTextClosure = closure
    }
    
    public func onData(_ closure: @escaping WebSocketDataClosure) {
        self.onDataClosure = closure
    }
    
    public func onClose(_ closure: @escaping WebSocketClosure) {
        self.onCloseClosure = closure
    }
    
    public func send(_ data: Data) {
        socket?.send(ByteBuffer(data: data))
    }
    
    public func send(_ text: String) {
        socket?.send(text)
    }
    
    public func send<T: Encodable>(_ obj: T) throws {
        let data = try Utils.jsonEncoder.encode(obj)
        send(data)
    }
    
    public func ping() {
        socket?.sendPing()
    }
    
    public func close() {
        timer = nil
        try? socket?.close().wait()
    }
    
    private func setupPing(pingInterval: TimeInterval?) {
        guard let pingInterval = pingInterval else { return }
        if let socket {
            socket.sendPing()
            self.timer = RepeatingTimer(timeInterval: pingInterval) {
                self.setupPing(pingInterval: pingInterval)
            }
        }
    }
    
    private func runSocketConnectedSequance() {
        isConnected = true
        onConnectClosure?(self)
        setupPing(pingInterval: pingInterval)
    }
}

#endif
