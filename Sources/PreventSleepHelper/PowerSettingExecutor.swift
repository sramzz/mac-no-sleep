import Foundation
import PreventSleepCore

public protocol ProcessRunnerProtocol: Sendable {
    func run(executable: String, arguments: [String], timeoutSeconds: Double) throws -> (exitCode: Int32, stdout: String, stderr: String)
}

public final class DefaultProcessRunner: ProcessRunnerProtocol {
    public init() {}

    public func run(executable: String, arguments: [String], timeoutSeconds: Double) throws -> (exitCode: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            throw PreventSleepError.timedOut
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

        return (process.terminationStatus, stdoutString, stderrString)
    }
}

public final class PowerSettingExecutor: @unchecked Sendable {
    private let runner: ProcessRunnerProtocol
    private let pmsetPath = "/usr/bin/pmset"
    private let lock = NSLock()

    public init(runner: ProcessRunnerProtocol = DefaultProcessRunner()) {
        self.runner = runner
    }

    public func readState() throws(PreventSleepError) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        do {
            let result = try runner.run(executable: pmsetPath, arguments: ["-g"], timeoutSeconds: 3.0)
            guard result.exitCode == 0 else {
                throw PreventSleepError.commandFailed(exitCode: result.exitCode, message: result.stderr)
            }
            return try PowerSettingParser.parseSleepDisabled(from: result.stdout)
        } catch let err as PreventSleepError {
            throw err
        } catch {
            throw PreventSleepError.commandFailed(exitCode: -1, message: error.localizedDescription)
        }
    }

    public func setPreventSleep(_ enabled: Bool) throws(PreventSleepError) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let arg = enabled ? "1" : "0"
        do {
            AppLogger.shared.info("PowerExecutor", "⚡ Executing pmset disablesleep \(arg)...")
            let writeResult = try runner.run(
                executable: pmsetPath,
                arguments: ["disablesleep", arg],
                timeoutSeconds: 10.0
            )

            guard writeResult.exitCode == 0 else {
                AppLogger.shared.error("PowerExecutor", "pmset disablesleep \(arg) exited with code \(writeResult.exitCode): \(writeResult.stderr)")
                throw PreventSleepError.commandFailed(exitCode: writeResult.exitCode, message: writeResult.stderr)
            }

            AppLogger.shared.debug("PowerExecutor", "pmset write completed with exitCode 0. Verifying with readback...")

            // Confirmed readback immediately
            let readbackResult = try runner.run(
                executable: pmsetPath,
                arguments: ["-g"],
                timeoutSeconds: 3.0
            )

            guard readbackResult.exitCode == 0 else {
                AppLogger.shared.error("PowerExecutor", "pmset -g readback exited with code \(readbackResult.exitCode): \(readbackResult.stderr)")
                throw PreventSleepError.commandFailed(exitCode: readbackResult.exitCode, message: readbackResult.stderr)
            }

            let observed = try PowerSettingParser.parseSleepDisabled(from: readbackResult.stdout)
            AppLogger.shared.info("PowerExecutor", "Readback observed SleepDisabled = \(observed) (expected = \(enabled))")
            guard observed == enabled else {
                AppLogger.shared.error("PowerExecutor", "Readback mismatch! Expected \(enabled), observed \(observed)")
                throw PreventSleepError.mismatchedReadback(expected: enabled, actual: observed)
            }

            return observed
        } catch let err as PreventSleepError {
            throw err
        } catch {
            AppLogger.shared.error("PowerExecutor", "Unexpected error executing pmset: \(error.localizedDescription)")
            throw PreventSleepError.commandFailed(exitCode: -1, message: error.localizedDescription)
        }
    }
}
