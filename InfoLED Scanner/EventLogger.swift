//
//  EventLogger.swift
//  InfoLED Scanner
//
//  Created by Jackie Yang on 2/27/19.
//  Copyright © 2019 yangjunrui. All rights reserved.
//

struct Event {
    let context: Dictionary<String, Any>;
    let message: Dictionary<String, Any>;
}

protocol EventLogger {
    func recordMessage(dict: Dictionary<String, Any>, context: Dictionary<String, Any>)
}

extension EventLogger {

    func recordMessage(message: String) {
        recordMessage(message: message, context: [: ])
    }

    func recordMessage(dict: Dictionary<String, Any>) {
        recordMessage(dict: dict, context: [: ])
    }

    func recordMessage(message: String, context: Dictionary<String, Any>) {
        recordMessage(dict: ["message": message], context: [: ])
    }

    func Logger(with context: Dictionary<String, Any>) -> EventLogger {
        return ContextedEventLogger(parentLogger: self, contextFunction: {context})
    }

    func Logger(with context: @escaping () -> Dictionary<String, Any>) -> EventLogger {
        return ContextedEventLogger(parentLogger: self, contextFunction: context)
    }
}

class MemoryEventLogger: EventLogger {
    var events: [Event]

    init() {
        events = []
    }

    func recordMessage(dict: Dictionary<String, Any>, context: Dictionary<String, Any>) {
        events += [Event(context: context, message: dict)]
    }
}

class ContextedEventLogger: EventLogger {
    let contextFunction: () -> Dictionary<String, Any>
    let parentLogger: EventLogger

    init(parentLogger: EventLogger, contextFunction: @escaping () -> Dictionary<String, Any>) {
        self.parentLogger = parentLogger
        self.contextFunction = contextFunction
    }

    func recordMessage(dict: Dictionary<String, Any>, context: Dictionary<String, Any>) {
        let combinedContext = self.contextFunction().merging(context) { (_, new) -> Any in new}
        self.parentLogger.recordMessage(dict: dict, context: combinedContext)
    }
}
