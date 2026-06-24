enum ProjectImageStorage {
    static func saveImageData(_ data: Data) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        let url = documentsDirectory.appendingPathComponent(fileName)

        guard let image = UIImage(data: data) else {
            return nil
        }

        let resizedImage = image.resized(maxSide: 900)

        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.75) else {
            return nil
        }

        do {
            try jpegData.write(to: url)
            return fileName
        } catch {
            print("Failed to save image:", error)
            return nil
        }
    }

    static func loadImage(fileName: String?) -> UIImage? {
        guard let fileName else { return nil }

        let url = documentsDirectory.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let maxCurrentSide = max(size.width, size.height)

        guard maxCurrentSide > maxSide else {
            return self
        }

        let scale = maxSide / maxCurrentSide
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}