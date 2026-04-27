import Foundation

/// Logger for console output with different severity levels
struct Logger {
    let verbose: Bool
    
    /// Log informational messages (only in verbose mode)
    func info(_ message: String) {
        if verbose {
            fputs("ℹ️  \(message)\n", stderr)
        }
    }
    
    /// Log warning messages (always shown)
    func warning(_ message: String) {
        fputs("⚠️  \(message)\n", stderr)
    }
    
    /// Log error messages (always shown)
    func error(_ message: String) {
        fputs("❌ \(message)\n", stderr)
    }
    
    /// Log debug messages (only in verbose mode)
    func debug(_ message: String) {
        if verbose {
            fputs("🔍 \(message)\n", stderr)
        }
    }
}
