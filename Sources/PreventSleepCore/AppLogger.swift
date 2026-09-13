import Foundation
import os

public enum LogLevel: Int, Comparable, Sendable, CaseIterable {
    case none = 0
    case error = 1
    case warning = 2
    case info = 3
    case debug = 4
    case trace = 5

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .none: return "NONE"
        case .error: return "ERROR"
        case .warning: return "WARN"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        case .trace: return "TRACE"
        }
    }

    public var emoji: String {
        switch self {
        case .none: return ""
        case .error: return "🛑"
        case .warning: return "⚠️"
        case .info: return "ℹ️"
        case .debug: return "🔍"
        case .trace: return "🔬"
        }
    }

    public static func from(string: String) -> LogLevel? {
        switch string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "none", "off", "0": return LogLevel.none
        case "error", "err", "1": return .error
        case "warning", "warn", "2": return .warning
        case "info", "3": return .info
        case "debug", "4": return .debug
        case "trace", "full", "verbose", "5": return .trace
        default: return nil
        }
    }
}

public final class AppLogger: @unchecked Sendable {
    public static let shared = AppLogger()

    private let lock = NSLock()
    private var _level: LogLevel

    public var level: LogLevel {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _level
        }
        set {
            lock.lock()
            _level = newValue
            lock.unlock()
        }
    }

    private let osLogger: os.Logger
    private let dateFormatter: DateFormatter

    public init(subsystem: String = "com.sramzz.mac-no-sleep", category: String = "App") {
        if let env = ProcessInfo.processInfo.environment["PREVENT_SLEEP_LOG_LEVEL"],
           let parsed = LogLevel.from(string: env) {
            self._level = parsed
        } else {
            #if DEBUG
            self._level = .debug
            #else
            if isatty(fileno(stdout)) != 0 {
                self._level = .debug
            } else {
                self._level = .info
            }
            #endif
        }

        let args = ProcessInfo.processInfo.arguments
        for (idx, arg) in args.enumerated() {
            if (arg == "--log-level" || arg == "-l") && idx + 1 < args.count {
                if let parsed = LogLevel.from(string: args[idx + 1]) {
                    self._level = parsed
                }
            } else if arg == "--verbose" || arg == "-v" || arg == "--trace" {
                self._level = .trace
            } else if arg == "--debug" || arg == "-d" {
                self._level = .debug
            } else if arg == "--quiet" || arg == "-q" {
                self._level = .none
            }
        }

        self.osLogger = Logger(subsystem: subsystem, category: category)
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        self.dateFormatter = df
    }

    public func log(_ level: LogLevel, category: String, message: @autoclosure () -> String) {
        guard level <= self.level && level != .none else { return }

        let msg = message()
        let timestamp: String
        lock.lock()
        timestamp = dateFormatter.string(from: Date())
        lock.unlock()

        let formatted = "[\(timestamp)] \(level.emoji) [\(level.label)] [\(category)] \(msg)"

        if level >= .error {
            fputs("\(formatted)\n", stderr)
            fflush(stderr)
        } else {
            fputs("\(formatted)\n", stdout)
            fflush(stdout)
        }

        switch level {
        case .none: break
        case .error: osLogger.error("[\(category)] \(msg, privacy: .public)")
        case .warning: osLogger.warning("[\(category)] \(msg, privacy: .public)")
        case .info: osLogger.info("[\(category)] \(msg, privacy: .public)")
        case .debug: osLogger.debug("[\(category)] \(msg, privacy: .public)")
        case .trace: osLogger.trace("[\(category)] \(msg, privacy: .public)")
        }
    }

    public func error(_ category: String, _ message: @autoclosure () -> String) {
        log(.error, category: category, message: message())
    }

    public func warning(_ category: String, _ message: @autoclosure () -> String) {
        log(.warning, category: category, message: message())
    }

    public func info(_ category: String, _ message: @autoclosure () -> String) {
        log(.info, category: category, message: message())
    }

    public func debug(_ category: String, _ message: @autoclosure () -> String) {
        log(.debug, category: category, message: message())
    }

    public func trace(_ category: String, _ message: @autoclosure () -> String) {
        log(.trace, category: category, message: message())
    }
}
