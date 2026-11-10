import Foundation

/// Controls the system-wide `pmset disablesleep` flag, the only switch that stops lid-close sleep.
public protocol LidSleepControl {
    func isSleepDisabled() -> Bool
    /// Returns whether the change succeeded.
    @discardableResult func setSleepDisabled(_ disabled: Bool) -> Bool
}

public struct PmsetLidSleepControl: LidSleepControl {
    public init() {}

    public func isSleepDisabled() -> Bool {
        guard let output = Shell.run("/usr/bin/pmset", ["-g"]).output else { return false }
        return PmsetOutput.isSleepDisabled(output)
    }

    public func setSleepDisabled(_ disabled: Bool) -> Bool {
        // -n: fail instead of prompting; the sudoers rule installed by LidSleepHelper allows this without a password.
        Shell.run("/usr/bin/sudo", ["-n"] + LidSleepHelper.pmsetArguments(disabled)).status == 0
    }
}

public enum PmsetOutput {
    /// Parses the `SleepDisabled` line from `pmset -g`.
    public static func isSleepDisabled(_ output: String) -> Bool {
        for line in output.split(separator: "\n") {
            let fields = line.split(whereSeparator: \.isWhitespace)
            if fields.first == "SleepDisabled" {
                return fields.last == "1"
            }
        }
        return false
    }
}

/// Installs and removes the sudoers rule that lets the current user toggle `disablesleep` without a password.
public enum LidSleepHelper {
    public static let sudoersPath = "/etc/sudoers.d/lidless"

    public static func pmsetArguments(_ disabled: Bool) -> [String] {
        ["/usr/bin/pmset", "-a", "disablesleep", disabled ? "1" : "0"]
    }

    public static var isInstalled: Bool {
        guard FileManager.default.fileExists(atPath: sudoersPath) else { return false }
        // -l checks permission without running the command.
        return Shell.run("/usr/bin/sudo", ["-n", "-l"] + pmsetArguments(false)).status == 0
    }

    /// Returns `nil` for usernames that aren't safe to put in a sudoers file.
    public static func sudoersContents(for user: String) -> String? {
        guard !user.isEmpty, user.range(of: #"\A[A-Za-z0-9_][A-Za-z0-9_.-]*\z"#, options: .regularExpression) != nil else {
            return nil
        }
        let commands = [true, false].map { pmsetArguments($0).joined(separator: " ") }.joined(separator: ", ")
        return """
        # Installed by Lidless so it can keep this Mac awake with the lid closed.
        # Remove it from Lidless Preferences, or delete this file.
        \(user) ALL=(root) NOPASSWD: \(commands)

        """
    }

    public enum HelperError: LocalizedError {
        case unsupportedUsername(String)
        case cancelled
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case let .unsupportedUsername(user): return "The username “\(user)” isn't supported."
            case .cancelled: return "Setup was cancelled."
            case let .failed(message): return message
            }
        }
    }

    /// Prompts for an administrator password once and installs the rule. Must run on the main thread.
    public static func install() throws {
        let user = NSUserName()
        guard let contents = sudoersContents(for: user) else { throw HelperError.unsupportedUsername(user) }

        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("lidless-sudoers-\(UUID().uuidString)")
        try contents.write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }

        let tempPath = shellQuoted(temp.path)
        try runAsAdmin(
            "/usr/sbin/visudo -cf \(tempPath) && /bin/mkdir -p /etc/sudoers.d && " +
            "/usr/bin/install -m 0440 -o root -g wheel \(tempPath) \(sudoersPath)"
        )
        guard isInstalled else {
            throw HelperError.failed("The helper was installed but sudo doesn't accept it.")
        }
    }

    /// Prompts for an administrator password and removes the rule. Must run on the main thread.
    public static func uninstall() throws {
        try runAsAdmin("/bin/rm -f \(sudoersPath)")
    }

    private static func runAsAdmin(_ command: String) throws {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) == -128 { throw HelperError.cancelled }
            throw HelperError.failed(error[NSAppleScript.errorMessage] as? String ?? "Unknown error.")
        }
    }

    private static func shellQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum Shell {
    static func run(_ path: String, _ args: [String]) -> (status: Int32, output: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return (-1, nil)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8))
    }
}
