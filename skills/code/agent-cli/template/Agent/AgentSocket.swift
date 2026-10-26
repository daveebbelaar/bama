import AppKit
import Foundation

/// A Unix domain socket that only this Mac user can open. The app listens;
/// the CLI connects, sends one JSON line, and reads one JSON line back.
///   ~/Library/Application Support/__APP_NAME__/agent.sock     the real app
///   <APP_STORE>.sock                                         a test run
///   APP_AGENT_SOCKET=<path>                                  any other place
nonisolated enum AgentSocket {
    static var path: String {
        let env = ProcessInfo.processInfo.environment
        if let path = env["APP_AGENT_SOCKET"], !path.isEmpty { return path }
        if let store = env["APP_STORE"], !store.isEmpty { return store + ".sock" }
        let dir = URL.applicationSupportDirectory.appending(path: "__APP_NAME__", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "agent.sock").path
    }

    private static func address(_ path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw AgentError.invalid("socket path is too long (over 103 bytes): \(path). Set APP_AGENT_SOCKET to a shorter path")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }
        return address
    }

    // MARK: App side

    /// Starts listening. `handle` runs on the main actor for each request.
    static func listen(handle: @escaping @MainActor @Sendable (Data) -> Data) {
        let path = self.path
        unlink(path)
        let server = socket(AF_UNIX, SOCK_STREAM, 0)
        guard server >= 0, var address = try? address(path) else { return }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(server, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, Darwin.listen(server, 16) == 0 else {
            print("AGENT could not listen on \(path): \(String(cString: strerror(errno)))")
            close(server)
            return
        }
        chmod(path, 0o600)
        Thread.detachNewThread {
            while true {
                let client = accept(server, nil, nil)
                guard client >= 0 else { continue }
                Thread.detachNewThread { serve(client, handle: handle) }
            }
        }
    }

    private static func serve(_ client: Int32, handle: @escaping @MainActor @Sendable (Data) -> Data) {
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        let request = readLine(client)
        let reply = DispatchQueue.main.sync { MainActor.assumeIsolated { handle(request) } }
        write(client, reply + Data("\n".utf8))
        close(client)
    }

    // MARK: CLI side

    /// Sends one request and returns the reply. Starts the app when it is
    /// not running, unless `launch` is false.
    static func send(_ request: Data, launch: Bool) throws -> Data {
        if let reply = try? exchange(request) { return reply }
        guard launch else { throw AgentError.unavailable("__APP_NAME__ is not running. Open it, or leave out --no-launch") }
        try startApp()
        for _ in 0..<50 {
            Thread.sleep(forTimeInterval: 0.2)
            if let reply = try? exchange(request) { return reply }
        }
        throw AgentError.unavailable("__APP_NAME__ did not answer within 10 seconds on \(path)")
    }

    private static func exchange(_ request: Data) throws -> Data {
        let client = socket(AF_UNIX, SOCK_STREAM, 0)
        guard client >= 0 else { throw AgentError.unavailable("no socket") }
        defer { close(client) }
        var address = try address(path)
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(client, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else { throw AgentError.unavailable("not running") }
        write(client, request + Data("\n".utf8))
        var timeout = timeval(tv_sec: 30, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        return readLine(client)
    }

    /// Opens the app in the background, with this process's environment, so a
    /// test run (APP_STORE) starts a test copy, never the real one.
    private static func startApp() throws {
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let bundle = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let process = Process()
        if bundle.pathExtension == "app" {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            var arguments = ["-g", "-n", bundle.path]
            for key in ["APP_STORE", "APP_AGENT_SOCKET"] {
                if let value = ProcessInfo.processInfo.environment[key] { arguments += ["--env", "\(key)=\(value)"] }
            }
            // Only a test run (APP_STORE set) may open a second copy.
            if ProcessInfo.processInfo.environment["APP_STORE"] == nil { arguments.remove(at: 1) }
            process.arguments = arguments
        } else {
            process.executableURL = executable
            process.arguments = []
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw AgentError.unavailable("could not start __APP_NAME__: \(error.localizedDescription)") }
    }

    // MARK: Bytes

    private static func readLine(_ socket: Int32) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while true {
            let count = read(socket, &buffer, buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
            if buffer[count - 1] == UInt8(ascii: "\n") { break }
        }
        return data
    }

    private static func write(_ socket: Int32, _ data: Data) {
        data.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let sent = Darwin.write(socket, raw.baseAddress! + offset, raw.count - offset)
                if sent <= 0 { return }
                offset += sent
            }
        }
    }
}
