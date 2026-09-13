import Testing
@testable import PreventSleepCore

@Suite("PowerSettingParser Tests")
struct PowerSettingParserTests {
    @Test("Parse ON when SleepDisabled is 1")
    func testParseOn() throws {
        let output = """
        System-wide power settings:
         SleepDisabled		1
        Currently in use:
         standby              1
         sleep                1
        """
        let result = try PowerSettingParser.parseSleepDisabled(from: output)
        #expect(result == true)
    }

    @Test("Parse OFF when SleepDisabled is 0")
    func testParseOff() throws {
        let output = """
        System-wide power settings:
         SleepDisabled		0
        Currently in use:
         standby              1
         sleep                10
        """
        let result = try PowerSettingParser.parseSleepDisabled(from: output)
        #expect(result == false)
    }

    @Test("Throw missingField when SleepDisabled is omitted")
    func testParseMissingField() {
        let output = """
        Currently in use:
         standby              1
         sleep                10
        """
        #expect(throws: PreventSleepError.missingField) {
            try PowerSettingParser.parseSleepDisabled(from: output)
        }
    }

    @Test("Throw malformedOutput when SleepDisabled has unexpected value")
    func testParseMalformedValue() {
        let output = """
        System-wide power settings:
         SleepDisabled		maybe
        """
        #expect(throws: PreventSleepError.malformedOutput("Unrecognized SleepDisabled value: maybe")) {
            try PowerSettingParser.parseSleepDisabled(from: output)
        }
    }

    @Test("Throw missingField on empty input")
    func testParseEmptyInput() {
        #expect(throws: PreventSleepError.missingField) {
            try PowerSettingParser.parseSleepDisabled(from: "")
        }
    }
}
