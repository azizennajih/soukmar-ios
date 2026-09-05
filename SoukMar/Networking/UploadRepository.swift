import Foundation

/// Mirrors soukmar-android's UploadRepository — POST /api/upload,
/// Cloudinary-backed, multipart field name "images".
final class UploadRepository {
    static let shared = UploadRepository()
    private let api = APIClient.shared

    func uploadImages(_ images: [(data: Data, filename: String, mimeType: String)]) async -> Result<[String], APIError> {
        do {
            let response: UploadResponseDto = try await api.upload(path: "upload", fieldName: "images", files: images)
            return .success(response.urls)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
