import Foundation

/// Starts the CLI when there is a command after the app's name, else the app.
@main
enum Main {
    static func main() {
        if let code = AgentCLI.runIfRequested() { exit(code) }
        __APP_NAME__App.main()
    }
}
