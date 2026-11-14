import SwiftUI

/// A scalable landscape drawn in normalized coordinates so the garden can
/// extend across a desktop window without stretching the cat illustration.
struct GardenCover: View {
    let date: Date
    let petals: Int

    var body: some View {
        GeometryReader { proxy in
            let narrow = proxy.size.width < 390
            ZStack(alignment: .bottomLeading) {
                Canvas { context, size in
                    let w = size.width, h = size.height
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                        Gradient(colors: [Color(red: 0.10, green: 0.22, blue: 0.23), Color(red: 0.34, green: 0.48, blue: 0.45)]),
                        startPoint: .zero, endPoint: CGPoint(x: w, y: h * 0.4)))
                    let sun = min(82, w * 0.16)
                    context.fill(Path(ellipseIn: CGRect(x: w * 0.83 - sun / 2, y: h * 0.12, width: sun, height: sun)), with: .color(Color(red: 0.96, green: 0.83, blue: 0.63)))
                    for layer in 0..<3 {
                        let level = CGFloat(layer)
                        var ridge = Path()
                        ridge.move(to: CGPoint(x: 0, y: h))
                        for i in 0...120 {
                            let x = CGFloat(i) / 120
                            let y = 0.69 + level * 0.11 + 0.10 * sin(x * 7 + level * 2) - 0.12 * x
                            ridge.addLine(to: CGPoint(x: x * w, y: y * h))
                        }
                        ridge.addLine(to: CGPoint(x: w, y: h))
                        ridge.closeSubpath()
                        context.fill(ridge, with: .color([Color.sage.opacity(0.48), Color(red: 0.21, green: 0.37, blue: 0.31), Color(red: 0.12, green: 0.27, blue: 0.24)][layer]))
                    }
                }.accessibilityHidden(true)
                SpriteCat(category: .create, frame: 0)
                    .frame(width: narrow ? 84 : 145, height: narrow ? 84 : 145)
                    .padding(.trailing, narrow ? 8 : 32)
                    .frame(maxWidth: .infinity, alignment: .trailing).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(date.formatted(.dateTime.weekday(.wide)).uppercased())
                        .font(.caption.weight(.bold)).tracking(2)
                    Text(date.formatted(.dateTime.month(.wide).day()))
                        .font(.system(size: narrow ? 31 : 49, weight: .regular, design: .serif))
                        .minimumScaleFactor(0.65).lineLimit(1)
                    Label("\(petals) \(petals == 1 ? "petal" : "petals") grown", systemImage: "camera.macro")
                        .font(.callout).padding(.top, 6)
                }.foregroundStyle(.white).padding(narrow ? 18 : 28)
                    .padding(.trailing, narrow ? 75 : 132)
            }.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }.frame(height: 180)
    }
}
