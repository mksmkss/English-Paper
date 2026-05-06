import Foundation

struct DatabaseBackupExporter {
    let paths: AppPaths

    func export() throws {
        let result = exportResult()
        guard result.exitCode == 0 else {
            let output = [result.standardError, result.standardOutput]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw AppError.backupExportFailed(output.isEmpty ? "sqlite3 .dump failed." : output)
        }
    }

    func exportResult() -> LocalCommandResult {
        do {
            try paths.ensureDirectoriesExist()
        } catch {
            return LocalCommandResult(exitCode: 1, standardOutput: "", standardError: error.localizedDescription)
        }

        let dumpResult = LocalCommandRunner.run("/usr/bin/env", arguments: ["sqlite3", paths.databaseURL.path, ".dump"])
        guard dumpResult.exitCode == 0 else {
            return dumpResult
        }

        let dumpText = dumpResult.standardOutput + "\n"
        do {
            try dumpText.write(to: paths.backupURL, atomically: true, encoding: .utf8)
            return LocalCommandResult(exitCode: 0, standardOutput: "Updated backup.sql", standardError: "")
        } catch {
            return LocalCommandResult(exitCode: 1, standardOutput: "", standardError: error.localizedDescription)
        }
    }
}
