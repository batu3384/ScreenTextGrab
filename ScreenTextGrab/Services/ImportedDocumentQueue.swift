import Foundation

struct ImportedDocumentQueue {
    private(set) var pendingCommands: [AutomationCommand] = []
    private(set) var importedFileCommandInFlight = false

    var isEmpty: Bool {
        pendingCommands.isEmpty
    }

    mutating func enqueue(_ commands: [AutomationCommand]) {
        pendingCommands.append(contentsOf: commands)
    }

    mutating func nextCommand(captureState: CaptureState) -> AutomationCommand? {
        guard !pendingCommands.isEmpty, !captureState.isBusy else {
            return nil
        }

        if pendingCommands[0].isImportedFileCommand, importedFileCommandInFlight {
            return nil
        }

        let command = pendingCommands.removeFirst()
        if command.isImportedFileCommand {
            importedFileCommandInFlight = true
        }
        return command
    }

    mutating func markDispatchResult(for command: AutomationCommand, startedBusyWork: Bool) {
        guard command.isImportedFileCommand, !startedBusyWork else {
            return
        }

        importedFileCommandInFlight = false
    }

    mutating func captureStateDidChange(_ captureState: CaptureState) {
        if !captureState.isBusy {
            importedFileCommandInFlight = false
        }
    }
}

typealias AutomationCommandQueue = ImportedDocumentQueue
