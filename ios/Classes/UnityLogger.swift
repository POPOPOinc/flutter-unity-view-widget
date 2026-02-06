//
//  UnityLogger.swift
//  flutter_unity_widget
//
//  Unified logging utility for Unity lifecycle events
//

import Foundation
import os.log

/// Unified logger for Unity widget plugin
/// Logs to os.log, console (print), and app_logs.txt file
public class UnityLogger {
    public static let shared = UnityLogger()

    private let logger = Logger(subsystem: "com.xraph.plugin.flutter_unity_widget", category: "Unity")
    private let logQueue = DispatchQueue(label: "com.xraph.plugin.flutter_unity_widget.logQueue")

    private var logFilePath: String? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent("app_logs.txt").path
    }

    private init() {}

    /// Write log entry to app_logs.txt file
    private func writeToLogFile(_ message: String, category: String) {
        guard let filePath = logFilePath else {
            return
        }

        logQueue.async {
            // Format timestamp to match Flutter's DateTime.now().toString() format
            // "2026-02-04 18:21:17.828440"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
            formatter.timeZone = TimeZone.current
            let timestamp = formatter.string(from: Date())
            let logEntry = "\(timestamp)[Info][\(category)]\(message)\n\n"

            if let data = logEntry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: filePath) {
                    if let fileHandle = FileHandle(forWritingAtPath: filePath) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    // File doesn't exist yet, create it
                    try? data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
                }
            }
        }
    }

    /// Log info message
    public func info(_ message: String, category: String = "iOS-Unity") {
        logger.info("\(message)")
        print(message)
        writeToLogFile(message, category: category)
    }

    /// Log warning message
    public func warning(_ message: String, category: String = "iOS-Unity") {
        logger.warning("\(message)")
        print(message)
        writeToLogFile(message, category: category)
    }

    /// Log error message
    public func error(_ message: String, category: String = "iOS-Unity") {
        logger.error("\(message)")
        print(message)
        writeToLogFile(message, category: category)
    }
}
