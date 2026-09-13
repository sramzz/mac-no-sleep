import Testing
import Foundation
@testable import PreventSleepCore
@testable import PreventSleepHelperLib

final class MockProcessRunner: ProcessRunnerProtocol, @unchecked Sendable {
    var outputs: [String: (exitCode: Int32, stdout: String, stderr: String)] = [:]
    var recordedInvocations: [(executable: String, arguments: [String])] = []

    func run(executable: String, arguments: [String], timeoutSeconds: Double) throws -> (exitCode: Int32, stdout: String, stderr: String) {
        recordedInvocations.append((executable, arguments))
        let key = ([executable] + arguments).joined(separator: " ")
        if let result = outputs[key] {
            return result
        }
        return (0, "", "")
    }
}

@Suite("PowerSettingExecutor Tests")
struct PowerSettingExecutorTests {
    @Test("Read state calls /usr/bin/pmset -g and parses correctly")
    func testReadState() throws {
        let mock = MockProcessRunner()
        mock.outputs["/usr/bin/pmset -g"] = (0, "System-wide power settings:\n SleepDisabled 1\n", "")

        let executor = PowerSettingExecutor(runner: mock)
        let result = try executor.readState()
        #expect(result == true)
        #expect(mock.recordedInvocations.count == 1)
        #expect(mock.recordedInvocations[0].executable == "/usr/bin/pmset")
        #expect(mock.recordedInvocations[0].arguments == ["-g"])
    }

    @Test("Write executes pmset disablesleep 0 and confirms with readback")
    func testWriteWithConfirmedReadback() throws {
        let mock = MockProcessRunner()
        mock.outputs["/usr/bin/pmset disablesleep 0"] = (0, "", "")
        mock.outputs["/usr/bin/pmset -g"] = (0, "System-wide power settings:\n SleepDisabled 0\n", "")

        let executor = PowerSettingExecutor(runner: mock)
        let result = try executor.setPreventSleep(false)
        #expect(result == false)
        #expect(mock.recordedInvocations.count == 2)
        #expect(mock.recordedInvocations[0].arguments == ["disablesleep", "0"])
        #expect(mock.recordedInvocations[1].arguments == ["-g"])
    }

    @Test("Write throws mismatchedReadback when readback differs")
    func testMismatchedReadback() {
        let mock = MockProcessRunner()
        mock.outputs["/usr/bin/pmset disablesleep 1"] = (0, "", "")
        mock.outputs["/usr/bin/pmset -g"] = (0, "System-wide power settings:\n SleepDisabled 0\n", "")

        let executor = PowerSettingExecutor(runner: mock)
        #expect(throws: PreventSleepError.mismatchedReadback(expected: true, actual: false)) {
            try executor.setPreventSleep(true)
        }
    }

    @Test("Write throws commandFailed when pmset exits with nonzero status")
    func testCommandFailure() {
        let mock = MockProcessRunner()
        mock.outputs["/usr/bin/pmset disablesleep 1"] = (1, "", "permission denied")

        let executor = PowerSettingExecutor(runner: mock)
        #expect(throws: PreventSleepError.commandFailed(exitCode: 1, message: "permission denied")) {
            try executor.setPreventSleep(true)
        }
    }
}
