import Foundation

#if os(WASI)
import JavaScriptKit

class RepeatingTimer {
    private enum State {
        case suspended
        case resumed
    }
    
    private var state: State = .suspended
    private let timeInterval: TimeInterval
    private var eventHandler: (() -> Void)?
    private var jsTimer: JSTimer?
    
    init(timeInterval: TimeInterval, eventHandler: (() -> Void)? = nil) {
        self.timeInterval = timeInterval
        self.eventHandler = eventHandler
        self.resume()
    }
    
    deinit {
        jsTimer?.invalidate()
        eventHandler = nil
    }
    
    func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        jsTimer = JSTimer(interval: timeInterval, repeats: true) { [weak self] in
            self?.eventHandler?()
        }
    }
    
    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        jsTimer?.invalidate()
        jsTimer = nil
    }
}

class JSTimer {
    private var timer: JSObject?
    private var callback: JSClosure?
    
    init(interval: TimeInterval, repeats: Bool, action: @escaping () -> Void) {
        callback = JSClosure { _ in
            action()
            return .undefined
        }
        
        if repeats {
            if let object = JSObject.global.setInterval?(callback, interval * 1000).object {
                timer = object
            }
        } else if let object = JSObject.global.setTimeout?(callback, interval * 1000).object {
            timer = object
        }
    }
    
    func invalidate() {
        if let clearInterval = JSObject.global.clearInterval.function {
            clearInterval(timer)
        }
        if let clearTimeout = JSObject.global.clearTimeout.function {
            clearTimeout(timer)
        }
        callback = nil
    }
}

#else
import Dispatch

extension WebSocket {
    class RepeatingTimer {
        private enum State {
            case suspended
            case resumed
        }
        
        private var state: State = .suspended
        private let queue: DispatchQueue = DispatchQueue(label: "repeating.timer")
        private let timeInterval: TimeInterval
        private var eventHandler: (() -> Void)?
        
        init(timeInterval: TimeInterval, eventHandler: (() -> Void)? = nil) {
            self.timeInterval = timeInterval
            self.eventHandler = eventHandler
            self.resume()
        }
        
        private lazy var timer: DispatchSourceTimer = {
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)
            t.setEventHandler(handler: { [weak self] in
                self?.eventHandler?()
            })
            return t
        }()
        
        deinit {
            timer.setEventHandler {}
            timer.cancel()
            /*
             If the timer is suspended, calling cancel without resuming
             triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
             */
            resume()
            eventHandler = nil
        }
        
        func resume() {
            if state == .resumed {
                return
            }
            state = .resumed
            timer.activate()
        }
        
        func suspend() {
            if state == .suspended {
                return
            }
            state = .suspended
            timer.suspend()
        }
    }
}
#endif
