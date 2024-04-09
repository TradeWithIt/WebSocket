import Foundation
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
