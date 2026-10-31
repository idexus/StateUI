/// A picture the application makes itself: its pixels written as a PNG's bytes.
enum MadePicture {
    /// A `side` by `side` picture of rings in `hue` (0 to 1), as a PNG - each pixel the share of it every
    /// color covers, so its edges stand smooth.
    static func rings(side: Int, hue: Double) -> [UInt8] {
        let color = rgb(hue: hue).map(Double.init)
        let (radius, band, samples) = (Double(side) / 2, Double(side) / 18, 4)
        var pixels: [UInt8] = []
        pixels.reserveCapacity(side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                var (sum, covered) = ([0.0, 0.0, 0.0], 0)
                for row in 0..<samples {
                    for column in 0..<samples {
                        let dx = Double(x) + (Double(column) + 0.5) / Double(samples) - radius
                        let dy = Double(y) + (Double(row) + 0.5) / Double(samples) - radius
                        let distance = (dx * dx + dy * dy).squareRoot()
                        guard distance <= radius else { continue }
                        let ink = Int(distance / band) % 2 == 0 ? color : [255, 255, 255]
                        sum = zip(sum, ink).map(+)
                        covered += 1
                    }
                }
                let alpha = Double(covered) / Double(samples * samples) * 255
                pixels += covered == 0 ? [0, 0, 0, 0] : sum.map { UInt8(($0 / Double(covered)).rounded()) }
                    + [UInt8(alpha.rounded())]
            }
        }
        return png(width: side, height: side, rgba: pixels)
    }

    /// The color of `hue` at full saturation and brightness.
    private static func rgb(hue: Double) -> [UInt8] {
        let sector = hue * 6
        let rising = sector - sector.rounded(.down)
        let channels: [Double] = switch Int(sector) % 6 {
        case 0: [1, rising, 0]
        case 1: [1 - rising, 1, 0]
        case 2: [0, 1, rising]
        case 3: [0, 1 - rising, 1]
        case 4: [rising, 0, 1]
        default: [1, 0, 1 - rising]
        }
        return channels.map { UInt8(($0 * 255).rounded()) }
    }

    /// `rgba`, eight bits a channel, as a PNG: each row unfiltered, in stored deflate blocks.
    private static func png(width: Int, height: Int, rgba: [UInt8]) -> [UInt8] {
        var rows: [UInt8] = []
        for row in 0..<height { rows += [0] + rgba[row * width * 4..<(row + 1) * width * 4] }

        var stream: [UInt8] = [0x78, 0x01]
        var start = 0
        repeat {
            let count = min(65_535, rows.count - start)
            let last: UInt8 = start + count == rows.count ? 1 : 0
            stream += [last, UInt8(count & 0xFF), UInt8(count >> 8), UInt8(~count & 0xFF), UInt8(~count >> 8 & 0xFF)]
            stream += rows[start..<start + count]
            start += count
        } while start < rows.count
        stream += bigEndian(adler32(rows))

        let header = bigEndian(UInt32(width)) + bigEndian(UInt32(height)) + [8, 6, 0, 0, 0]
        return [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
            + chunk("IHDR", header) + chunk("IDAT", stream) + chunk("IEND", [])
    }

    private static func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
        let named = Array(type.utf8) + data
        return bigEndian(UInt32(data.count)) + named + bigEndian(crc32(named))
    }

    private static func bigEndian(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    private static func adler32(_ bytes: [UInt8]) -> UInt32 {
        var (low, high): (UInt32, UInt32) = (1, 0)
        for byte in bytes {
            low = (low + UInt32(byte)) % 65_521
            high = (high + low) % 65_521
        }
        return high << 16 | low
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        (0..<8).reduce(UInt32(index)) { crc, _ in crc & 1 == 1 ? 0xEDB8_8320 ^ crc >> 1 : crc >> 1 }
    }

    private static func crc32(_ bytes: [UInt8]) -> UInt32 {
        ~bytes.reduce(UInt32.max) { crc, byte in crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ crc >> 8 }
    }
}
