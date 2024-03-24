import Foundation
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
