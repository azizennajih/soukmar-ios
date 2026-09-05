import Foundation

struct ReportRequest: Encodable {
    let reportedId: String
    let listingId: String?
    let reason: String
}

struct ReportRecordDto: Codable {
    var id: String?
}
