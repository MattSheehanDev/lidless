import Testing
import LidlessCore

struct LaunchArgumentsTests {
    @Test func noFlagsMeansNoSession() {
        #expect(LaunchArguments.sessionRequest(from: ["Lidless"]) == nil)
    }

    @Test func indefinite() {
        let request = LaunchArguments.sessionRequest(from: ["Lidless", "--indefinite"])
        #expect(request == .indefinite)
        #expect(request?.seconds == nil)
    }

    @Test(arguments: [("45", 2700.0), ("0.5", 30.0), ("720", 43_200.0)])
    func minutes(value: String, expectedSeconds: Double) {
        let request = LaunchArguments.sessionRequest(from: ["Lidless", "--minutes", value])
        #expect(request == .duration(expectedSeconds))
        #expect(request?.seconds == expectedSeconds)
    }

    @Test(arguments: [
        ["Lidless", "--minutes"],
        ["Lidless", "--minutes", "abc"],
        ["Lidless", "--minutes", "0"],
        ["Lidless", "--minutes", "-5"],
        ["Lidless", "--minutes", "inf"],
        ["Lidless", "--minutes", "nan"],
    ])
    func invalidMinutesAreIgnored(args: [String]) {
        #expect(LaunchArguments.sessionRequest(from: args) == nil)
    }

    @Test func indefiniteWinsOverMinutes() {
        let request = LaunchArguments.sessionRequest(from: ["Lidless", "--minutes", "10", "--indefinite"])
        #expect(request == .indefinite)
    }
}
