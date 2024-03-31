import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public typealias WebSocketClosure = (_ ws: WebSocket) -> Void
public typealias WebSocketTextClosure = (_ ws: WebSocket,  _ text: String) -> Void
public typealias WebSocketDataClosure = (_ ws: WebSocket,  _ data: Data) -> Void

public class WebSocket: NSObject {
    private let session = URLSession(configuration: .default)
    private var webSocketTask: URLSessionWebSocketTask?
    private var timer: RepeatingTimer?
    private var pingInterval: TimeInterval? = nil
    private var onTextClosure: WebSocketTextClosure?
    private var onDataClosure: WebSocketDataClosure?
    private var onCloseClosure: WebSocketClosure?
    private var onConnectClosure: WebSocketClosure?
    
    public private(set) var isConnected: Bool = false
    
    deinit {
        close()
        timer = nil
    }
    
    public func connect(to request: URLRequest, pingInterval: TimeInterval? = 30, _ closure: @escaping (WebSocket) -> ()) throws {
        guard let url = request.url else { throw URLError(.badURL) }
        self.onConnectClosure = closure
        self.pingInterval = pingInterval
        self.webSocketTask = session.webSocketTask(with: url)
        self.webSocketTask?.delegate = self
        self.webSocketTask?.resume()
        self.listen()
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] in
            switch $0 {
            case .success(let message):
                defer {
                    self?.listen()
                }
                switch message {
                case .data(let data):
                    if let self = self {
                        self.onDataClosure?(self, data)
                    }
                case .string(let text):
                    if let self = self {
                        self.onTextClosure?(self, text)
                    }
                @unknown default:
                    break
                }
            case .failure(let error):
                print("🛑", error)
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
        webSocketTask?.send(URLSessionWebSocketTask.Message.data(data)) { error in
            guard let error = error else { return }
            print("🔴 Failed with Error \(error.localizedDescription)")
        }
    }
    
    public func send(_ text: String) {
        webSocketTask?.send(URLSessionWebSocketTask.Message.string(text)) { error in
            guard let error = error else { return }
            print("🔴 Failed with Error \(error.localizedDescription)")
        }
    }
    
    public func send<T: Encodable>(_ obj: T) throws {
        let data = try Utils.jsonEncoder.encode(obj)
        send(data)
    }
    
    public func close() {
        timer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    private func setupPing(pingInterval: TimeInterval?) {
        guard let pingInterval = pingInterval else { return }
        webSocketTask?.sendPing { error in
            self.timer = RepeatingTimer(timeInterval: pingInterval) {
                self.setupPing(pingInterval: pingInterval)
            }
        }
    }
}

extension WebSocket: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.isConnected = true
        self.onConnectClosure?(self)
        self.setupPing(pingInterval: pingInterval)
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.isConnected = false
        self.onCloseClosure?(self)
    }
}
