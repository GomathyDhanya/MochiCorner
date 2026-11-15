import AppKit
import Combine
import SwiftUI

extension Bundle {
    static let screenShireAssets: Bundle = {
        if let url = Bundle.main.url(forResource: "ScreenShire_ScreenShire", withExtension: "bundle"),
           let resources = Bundle(url: url) { return resources }
        return .module
    }()
}

@MainActor
final class FloatingWidgetController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private weak var state: AppState?
    private var cancellables = Set<AnyCancellable>()
    init(state: AppState) {
        self.state = state
        panel = NSPanel(contentRect: NSRect(x: 40, y: 80, width: 190, height: 180), styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
        super.init()
        panel.level = state.alwaysOnTop ? .floating : .normal; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false; panel.isMovableByWindowBackground = true; panel.minSize = NSSize(width: 120, height: 120); panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: CatWidgetView().environmentObject(state))
        panel.delegate = self
        state.applyWidgetPreferences = { [weak self] in self?.applyPreferences() }
        state.$widgetScale.sink { [weak self] _ in self?.applyPreferences() }.store(in: &cancellables)
        state.$widgetVisible.sink { [weak self] _ in self?.applyPreferences() }.store(in: &cancellables)
        state.$alwaysOnTop.sink { [weak self] _ in self?.applyPreferences() }.store(in: &cancellables)
        applyPreferences()
    }
    func show() { applyPreferences(); panel.orderFrontRegardless() }
    private func applyPreferences() {
        guard let state else { return }
        panel.level = state.alwaysOnTop ? .floating : .normal
        let side = 180 * state.widgetScale
        panel.setContentSize(NSSize(width: side, height: side))
        keepPanelOnScreen()
        if state.widgetVisible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }
    private func keepPanelOnScreen() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = NSPoint(x: min(max(panel.frame.origin.x, visible.minX), visible.maxX - panel.frame.width), y: min(max(panel.frame.origin.y, visible.minY), visible.maxY - panel.frame.height))
        panel.setFrameOrigin(origin)
    }
}

struct CatWidgetView: View {
    @EnvironmentObject private var state: AppState
    @State private var frame = 0
    @State private var isPetting = false
    var body: some View {
        SpriteCat(category: state.currentCategory, frame: state.reducedMotion ? 0 : frame, isPetting: isPetting)
            .padding(4).accessibilityElement(children: .combine).accessibilityLabel("MochiCorner cat widget. \(state.currentCategory.label)")
            .contentShape(Rectangle()).onHover { hovering in withAnimation(.easeInOut(duration: 0.16)) { isPetting = hovering } }.onTapGesture { (NSApp.delegate as? AppDelegate)?.openDashboard() }
            .contextMenu { Button(state.trackingPaused ? "Resume tracking" : "Pause tracking") { state.trackingPaused.toggle() }; Button("Open dashboard") { (NSApp.delegate as? AppDelegate)?.openDashboard() }; Divider(); Button("Hide widget") { state.widgetVisible = false } }
            .task(id: state.animationInterval) { while !Task.isCancelled { try? await Task.sleep(for: .seconds(state.animationInterval)); if !state.reducedMotion { frame = (frame + 1) % 3 } } }
    }
}

struct ScreenShireLogoMark: View {
    var size: CGFloat = 28
    var body: some View {
        if let url = Bundle.screenShireAssets.url(forResource: "AppIcon", withExtension: "png"), let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Image(systemName: "pawprint.fill").frame(width: size, height: size)
        }
    }
}

struct SpriteCat: View {
    let category: ActivityCategory
    let frame: Int
    var isPetting = false
    var body: some View {
        if let image = isPetting ? CatSpriteLibrary.bellyRub(frame: frame) : CatSpriteLibrary.image(for: category, frame: frame) { Image(nsImage: image).resizable().interpolation(.none).scaledToFit() }
        else { fallback }
    }
    private var fallback: some View {
        ZStack {
            Text("🐱").font(.system(size: 70 + CGFloat(frame * 2)))
            Text(accessory).font(.system(size: 30)).offset(x: 43, y: 25 + CGFloat(frame * 2))
        }.accessibilityHidden(true)
    }
    private var accessory: String { switch category { case .code: "💻"; case .work: "⌨️"; case .study: "📖"; case .music: "🎧"; case .entertainment: "📺"; case .social: "🐱"; case .create: "🎨"; case .game: "🎮"; case .idle: "💤"; case .uncategorized: "✨" } }
}

enum CatSpriteLibrary {
    static func bellyRub(frame: Int) -> NSImage? { load(named: "belly_rubs_0\(frame)_256") }
    static func image(for category: ActivityCategory, frame: Int) -> NSImage? {
        // The supplied pack has no idle/uncategorized frames. Keep Mochi visible
        // by showing the Work scene until a foreground app receives a category.
        let scene = (category == .idle || category == .uncategorized) ? ActivityCategory.work : category
        guard ActivityCategory.allCases.prefix(8).contains(scene), (0...2).contains(frame) else { return nil }
        return load(named: "\(scene.rawValue)_0\(frame)_256")
    }
    private static func load(named filename: String) -> NSImage? {
        // SwiftPM flattens processed resources into the target resource bundle.
        guard let url = Bundle.screenShireAssets.url(forResource: filename, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
}

extension Color { static let cream = Color(red: 0.98, green: 0.95, blue: 0.86); static let cocoa = Color(red: 0.28, green: 0.18, blue: 0.14); static let sage = Color(red: 0.53, green: 0.66, blue: 0.55); static let lilac = Color(red: 0.72, green: 0.65, blue: 0.82); static let peach = Color(red: 0.94, green: 0.68, blue: 0.55) }
