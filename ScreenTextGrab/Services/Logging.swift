import OSLog

enum STGLog {
    private static let subsystem = "dev.screentextgrab.app"

    static let permission = Logger(subsystem: subsystem, category: "permission")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let pipeline = Logger(subsystem: subsystem, category: "pipeline")
    static let update = Logger(subsystem: subsystem, category: "update")
}
