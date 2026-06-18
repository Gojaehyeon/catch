import OSLog

/// 카테고리별 OSLog 로거. 삼켜지던 에러(특히 동기화/네트워크)를 Console.app에서 진단할 수 있게 한다.
enum Log {
    private static let subsystem = "com.tntlabs.catch"

    static let camera = Logger(subsystem: subsystem, category: "camera")
    static let sync    = Logger(subsystem: subsystem, category: "sync")
    static let data    = Logger(subsystem: subsystem, category: "data")
    static let auth    = Logger(subsystem: subsystem, category: "auth")
}
