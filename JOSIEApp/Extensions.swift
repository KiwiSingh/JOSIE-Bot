extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r: UInt64
    let g: UInt64
    let b: UInt64
    (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
    self.init(
      .sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
  }
}
