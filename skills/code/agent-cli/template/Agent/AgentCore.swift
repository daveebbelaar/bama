import Foundation

// The agent interface: one list of commands (AgentCommands.swift) that the
// CLI, its help, and the MCP server all read. Commands run inside the app,
// on the main actor, so the window updates live and Undo keeps working.

typealias JSONObject = [String: Any]

/// One thing an agent can do. Keep names as "<noun> <verb>": "items add".
struct AgentCommand {
    struct Param {
        enum Kind: String { case string, integer, boolean }
        var name: String
        var kind: Kind = .string
        var required = false
        /// Given without its --name, right after the command: `items show 3f2a`.
        var positional = false
        var help: String
    }

    var name: String
    var summary: String
    var params: [Param] = []
    var example: String
    /// Only reads. Agents may run it without asking.
    var readOnly = false
    /// Removes data or cannot be undone. Without --yes it only reports what it would do.
    var destructive = false
    var run: (Args, AppModel) throws -> Any
}

/// The values a command was called with, checked against its params.
struct Args {
    var values: [String: String]

    func string(_ name: String) -> String? { values[name] }

    func required(_ name: String) throws -> String {
        guard let value = values[name], !value.isEmpty else { throw AgentError.usage("missing --\(name)") }
        return value
    }

    func int(_ name: String, default fallback: Int) throws -> Int {
        guard let raw = values[name] else { return fallback }
        guard let value = Int(raw) else { throw AgentError.usage("--\(name) must be a whole number, not \"\(raw)\"") }
        return value
    }

    func bool(_ name: String) throws -> Bool? {
        guard let raw = values[name] else { return nil }
        switch raw.lowercased() {
        case "", "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: throw AgentError.usage("--\(name) must be true or false, not \"\(raw)\"")
        }
    }

    var confirmed: Bool { (try? bool("yes")) == true }
}

/// An error with a stable code an agent can branch on, a message that says
/// how to fix it, and the exit code the CLI returns.
nonisolated struct AgentError: Error {
    var code: String
    var message: String
    var exit: Int32

    static func usage(_ message: String) -> AgentError { AgentError(code: "usage", message: message, exit: 2) }
    static func notFound(_ message: String) -> AgentError { AgentError(code: "not_found", message: message, exit: 3) }
    static func invalid(_ message: String) -> AgentError { AgentError(code: "invalid", message: message, exit: 1) }
    static func unavailable(_ message: String) -> AgentError { AgentError(code: "app_unavailable", message: message, exit: 4) }

    var json: JSONObject { ["ok": false, "error": ["code": code, "message": message]] }
}

/// Runs requests from the socket inside the app.
enum AgentRouter {
    static var model: AppModel?

    /// A request is {"command": "items add", "args": {"title": "Milk"}}.
    static func handle(_ request: Data) -> Data {
        let reply: JSONObject
        do {
            guard let object = try JSONSerialization.jsonObject(with: request) as? JSONObject,
                  let name = object["command"] as? String else { throw AgentError.usage("bad request") }
            guard let command = AgentCommands.all.first(where: { $0.name == name }) else {
                throw AgentError.usage("unknown command \"\(name)\". Run `__CLI_NAME__ help`")
            }
            guard let model else { throw AgentError.unavailable("the app is still starting. Try again") }
            let args = Args(values: object["args"] as? [String: String] ?? [:])
            reply = ["ok": true, "result": try command.run(args, model)]
        } catch let error as AgentError {
            reply = error.json
        } catch {
            reply = AgentError.invalid(error.localizedDescription).json
        }
        return JSON.data(reply)
    }
}

nonisolated enum JSON {
    static func data(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data("{}".utf8)
    }

    static func string(_ object: Any) -> String {
        String(decoding: data(object), as: UTF8.self)
    }

    static func date(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}
