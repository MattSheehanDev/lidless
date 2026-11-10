import Foundation

public enum SessionRequest: Equatable {
    case indefinite
    case duration(TimeInterval)

    /// The duration to pass to `AwakeController.activate(for:)`; `nil` means indefinite.
    public var seconds: TimeInterval? {
        switch self {
        case .indefinite: return nil
        case let .duration(seconds): return seconds
        }
    }
}

public enum LaunchArguments {
    /// Parses `--indefinite` or `--minutes <n>`. Returns `nil` when no valid session was requested.
    public static func sessionRequest(from args: [String]) -> SessionRequest? {
        if args.contains("--indefinite") {
            return .indefinite
        }
        guard let i = args.firstIndex(of: "--minutes"), i + 1 < args.count,
              let minutes = Double(args[i + 1]), minutes.isFinite, minutes > 0 else {
            return nil
        }
        return .duration(minutes * 60)
    }
}
