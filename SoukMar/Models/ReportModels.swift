import Foundation

struct ReportRequest: Encodable {
    let reportedId: String
    let listingId: String?
    let reason: String
}

struct ReportRecordDto: Codable {
    var id: String?
}

struct ReportUserRefDto: Codable {
    let id: String
    let name: String
    let email: String
}

struct ReportListingRefDto: Codable {
    let id: String
    let title: String
}

/// Mirrors soukmar-backend's GET /api/reports/admin — a moderation-queue
/// row with reporter/reported/listing refs attached.
struct AdminReportDto: Codable, Identifiable {
    let id: String
    var listingId: String?
    let reporterId: String
    let reportedId: String
    let reason: String
    var status: String
    var adminNote: String?
    let createdAt: String
    var resolvedAt: String?
    var reporter: ReportUserRefDto?
    var reported: ReportUserRefDto?
    var listing: ReportListingRefDto?
}

struct AdminReportUpdateRequest: Encodable {
    let status: String
    var adminNote: String?
}

/// Mirrors soukmar-backend's GET /api/admin/id-verifications — staff-only,
/// pending-first queue of ID-verification requests (see AuthModels.swift's
/// IdVerificationStatusDto for the user-facing submission side).
struct IdVerificationAdminDto: Codable, Identifiable {
    let id: String
    let userId: String
    let idImageUrl: String
    let selfieImageUrl: String
    var status: String
    var adminNote: String?
    let createdAt: String
    var reviewedAt: String?
    var user: ReportUserRefDto?
}

struct IdVerificationReviewRequest: Encodable {
    let status: String
    var adminNote: String?
}
