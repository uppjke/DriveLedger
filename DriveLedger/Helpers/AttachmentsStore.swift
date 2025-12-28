import Foundation
import UniformTypeIdentifiers

enum AttachmentsStore {
    private static let folderName = "Attachments"

    static func attachmentsDirectoryURL() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = docs.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func fileURL(relativePath: String) throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return docs.appendingPathComponent(relativePath)
    }

    struct ImportedFile {
        var relativePath: String
        var originalFileName: String
        var uti: String
        var fileSizeBytes: Int?
    }

    static func importFile(from url: URL) throws -> ImportedFile {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let dir = try attachmentsDirectoryURL()

        let originalName = url.lastPathComponent
        let ext = url.pathExtension
        let destName = ext.isEmpty ? UUID().uuidString : "\(UUID().uuidString).\(ext)"
        let destURL = dir.appendingPathComponent(destName, isDirectory: false)

        // Copy (overwrite if needed, extremely unlikely due to UUID)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: url, to: destURL)

        let uti = UTType(filenameExtension: ext)?.identifier
            ?? (try? destURL.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier)
            ?? "public.data"

        let size = try? destURL.resourceValues(forKeys: [.fileSizeKey]).fileSize

        return ImportedFile(
            relativePath: "\(folderName)/\(destName)",
            originalFileName: originalName,
            uti: uti,
            fileSizeBytes: size
        )
    }

    static func deleteFile(relativePath: String) {
        do {
            let url = try fileURL(relativePath: relativePath)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            // Best-effort cleanup.
            return
        }
    }

    static func readBase64(relativePath: String) -> String? {
        guard let url = try? fileURL(relativePath: relativePath) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return data.base64EncodedString()
    }

    static func writeBase64(_ base64: String, preferredExtension: String?) throws -> String {
        let dir = try attachmentsDirectoryURL()
        let ext = (preferredExtension ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let destName = ext.isEmpty ? UUID().uuidString : "\(UUID().uuidString).\(ext)"
        let destURL = dir.appendingPathComponent(destName, isDirectory: false)
        guard let data = Data(base64Encoded: base64) else {
            throw NSError(domain: "AttachmentsStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid base64"])
        }
        try data.write(to: destURL, options: [.atomic])
        return "\(folderName)/\(destName)"
    }
}
