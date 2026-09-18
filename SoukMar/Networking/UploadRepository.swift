import Foundation
import UIKit

/// Mirrors soukmar-android's UploadRepository — POST /api/upload,
/// Cloudinary-backed, multipart field name "images".
final class UploadRepository {
    static let shared = UploadRepository()
    private let api = APIClient.shared

    /// Downscales+re-encodes each image before upload — mirrors the web's
    /// `compressListingPhoto()`/`compressAvatar()` and Android's
    /// `compressToJpeg()`, needed because a raw phone-camera photo (8-12MB)
    /// can exceed the backend's 10MB multer limit and is otherwise sent
    /// unnecessarily large over mobile data. `type` also selects the
    /// backend's Cloudinary preset (listing: 1200px limit; avatar: 400x400
    /// face-crop) — sending no type (the previous behavior here) silently
    /// defaulted to the "listing" preset even for avatar uploads, giving
    /// avatars the wrong crop. Same bug Android found and fixed in its own
    /// image-compression tranche.
    func uploadImages(_ images: [(data: Data, filename: String, mimeType: String)], type: String = "listing") async -> Result<[String], APIError> {
        let maxDimension: CGFloat = type == "avatar" ? 640 : 1600
        let compressed = images.map { image -> (data: Data, filename: String, mimeType: String) in
            guard let jpeg = Self.compressToJpeg(image.data, maxDimension: maxDimension) else {
                return image
            }
            return (data: jpeg, filename: image.filename, mimeType: "image/jpeg")
        }
        do {
            let response: UploadResponseDto = try await api.upload(
                path: "upload", fieldName: "images", files: compressed, fields: ["type": type]
            )
            return .success(response.urls)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    /// Downscales the longer side to roughly `maxDimension` and re-encodes as
    /// an 82%-quality JPEG. Returns nil (caller falls back to the original
    /// data) if the bytes can't be decoded as an image, rather than failing
    /// the whole upload.
    private static func compressToJpeg(_ data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longerSide = max(image.size.width, image.size.height)
        guard longerSide > maxDimension else {
            return image.jpegData(compressionQuality: 0.82)
        }
        let scale = maxDimension / longerSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return scaled.jpegData(compressionQuality: 0.82)
    }
}
