import Foundation
import SQLite3

/**
 * Lightweight raw SQLite database helper for the iOS Notification Service Extension.
 *
 * Requirements:
 * - Direct C SQLite3 API (never loads Drift/Flutter runtime).
 * - Opens SQLite database at the shared App Group container path (`group.com.katala.app`).
 * - Configures WAL mode and busy timeout (3000ms).
 * - Implements schema version validation against `app_metadata`.
 * - Performs optimistic locking state updates.
 */
public enum ExtensionDatabaseError: Error, LocalizedError {
    case containerNotFound
    case databaseOpenFailed(String)
    case queryPrepareFailed(String)
    case schemaVersionMismatch(expected: Int, found: Int)
    case statementExecutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .containerNotFound:
            return "App Group container URL could not be resolved."
        case .databaseOpenFailed(let msg):
            return "Failed to open SQLite database: \(msg)"
        case .queryPrepareFailed(let msg):
            return "Failed to prepare SQLite statement: \(msg)"
        case .schemaVersionMismatch(let expected, let found):
            return "Database schema version mismatch (Supported: \(expected), Found: \(found))."
        case .statementExecutionFailed(let msg):
            return "Failed to execute SQLite statement: \(msg)"
        }
    }
}

public final class ExtensionDatabase {
    public static let appGroupIdentifier = "group.com.katala.app"
    public static let dbFileName = "katala.db"
    public static let supportedSchemaVersion = 1

    private var db: OpaquePointer?

    public init(customDbPath: String? = nil) throws {
        let dbPath: String
        if let customDbPath = customDbPath {
            dbPath = customDbPath
        } else {
            guard let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: ExtensionDatabase.appGroupIdentifier
            ) else {
                throw ExtensionDatabaseError.containerNotFound
            }
            let fileURL = containerURL.appendingPathComponent(ExtensionDatabase.dbFileName)
            dbPath = fileURL.path
        }

        if sqlite3_open_v2(
            dbPath,
            &db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
            nil
        ) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw ExtensionDatabaseError.databaseOpenFailed(errorMsg)
        }

        // Configure WAL mode and busy timeout per ADR-8 & ARCHITECTURE.md §14.4
        sqlite3_busy_timeout(db, 3000)
        _ = executePragma("PRAGMA journal_mode=WAL;")
        _ = executePragma("PRAGMA busy_timeout=3000;")
        _ = executePragma("PRAGMA foreign_keys=ON;")

        try validateSchemaVersion()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    private func executePragma(_ pragmaSql: String) -> Bool {
        guard let db = db else { return false }
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, pragmaSql, -1, &statement, nil) == SQLITE_OK {
            let stepResult = sqlite3_step(statement)
            sqlite3_finalize(statement)
            return stepResult == SQLITE_DONE || stepResult == SQLITE_ROW
        }
        return false
    }

    /**
     * Reads schema version from `app_metadata` or PRAGMA user_version.
     * Throws `schemaVersionMismatch` if the database has migrated beyond the extension's supported version.
     */
    public func validateSchemaVersion() throws {
        let version = try getSchemaVersion()
        if version > ExtensionDatabase.supportedSchemaVersion {
            throw ExtensionDatabaseError.schemaVersionMismatch(
                expected: ExtensionDatabase.supportedSchemaVersion,
                found: version
            )
        }
    }

    public func getSchemaVersion() throws -> Int {
        guard let db = db else { throw ExtensionDatabaseError.databaseOpenFailed("Database not open") }

        // First check app_metadata table
        let query = "SELECT value FROM app_metadata WHERE key = 'schema_version' LIMIT 1;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let cString = sqlite3_column_text(stmt, 0) {
                    let valStr = String(cString: cString)
                    if let versionInt = Int(valStr) {
                        return versionInt
                    }
                }
            }
        }

        // Fallback: check PRAGMA user_version
        var pragmaStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &pragmaStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(pragmaStmt) }
            if sqlite3_step(pragmaStmt) == SQLITE_ROW {
                return Int(sqlite3_column_int(pragmaStmt, 0))
            }
        }

        return 1
    }

    /**
     * Reads current reminder version for optimistic locking.
     */
    public func getReminderVersion(reminderId: String) throws -> (version: Int, status: String)? {
        guard let db = db else { throw ExtensionDatabaseError.databaseOpenFailed("Database not open") }

        let query = "SELECT version, status FROM reminder WHERE id = ? AND is_deleted = 0 LIMIT 1;"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw ExtensionDatabaseError.queryPrepareFailed(errorMsg)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (reminderId as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let version = Int(sqlite3_column_int(stmt, 0))
            let statusStr: String
            if let cString = sqlite3_column_text(stmt, 1) {
                statusStr = String(cString: cString)
            } else {
                statusStr = "pending"
            }
            return (version, statusStr)
        }

        return nil
    }

    /**
     * Executes optimistic-locking reminder state transition (e.g. pending -> completed / snoozed).
     */
    @discardableResult
    public func transitionReminderState(
        reminderId: String,
        expectedVersion: Int,
        newStatus: String,
        completedAt: String? = nil,
        updatedAt: String? = nil
    ) throws -> Bool {
        guard let db = db else { throw ExtensionDatabaseError.databaseOpenFailed("Database not open") }

        let updateTimestamp = updatedAt ?? ISO8601DateFormatter().string(from: Date())
        let sql = """
            UPDATE reminder
            SET status = ?, completed_at = ?, version = version + 1, updated_at = ?
            WHERE id = ? AND version = ? AND is_deleted = 0;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw ExtensionDatabaseError.queryPrepareFailed(errorMsg)
        }
        defer { sqlite3_finalize(stmt) }

        // Bind params
        sqlite3_bind_text(stmt, 1, (newStatus as NSString).utf8String, -1, nil)
        if let completedAt = completedAt {
            sqlite3_bind_text(stmt, 2, (completedAt as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 2)
        }
        sqlite3_bind_text(stmt, 3, (updateTimestamp as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (reminderId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 5, Int32(expectedVersion))

        let stepResult = sqlite3_step(stmt)
        if stepResult != SQLITE_DONE {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw ExtensionDatabaseError.statementExecutionFailed(errorMsg)
        }

        return sqlite3_changes(db) > 0
    }

    /**
     * Retrieves associated action metadata for a given reminder.
     */
    public func getReminderAction(reminderId: String) throws -> (actionType: String, targetValue: String?)? {
        guard let db = db else { throw ExtensionDatabaseError.databaseOpenFailed("Database not open") }

        let query = "SELECT action_type, target_value FROM action_ WHERE reminder_id = ? LIMIT 1;"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw ExtensionDatabaseError.queryPrepareFailed(errorMsg)
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (reminderId as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let actionTypeStr: String
            if let cString = sqlite3_column_text(stmt, 0) {
                actionTypeStr = String(cString: cString)
            } else {
                actionTypeStr = ""
            }

            var targetValue: String? = nil
            if let cTarget = sqlite3_column_text(stmt, 1) {
                targetValue = String(cString: cTarget)
            }

            return (actionTypeStr, targetValue)
        }

        return nil
    }
}
