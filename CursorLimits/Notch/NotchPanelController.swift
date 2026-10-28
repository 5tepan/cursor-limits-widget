import AppKit
import SwiftUI

@MainActor
final class NotchPanelState: ObservableObject {
    @Published var expanded = false
    @Published var metrics = NotchMetrics.fallback
}

/// Shows and hides the notch card. Pointer position is sampled — that does not
/// need Accessibility, and clicks outside the card pass through.
@MainActor
final class NotchPanelController {
    private let state = NotchPanelState()
    private weak var model: AppModel?
    private var panel: LimitsNotchPanel?
    private var timer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var collapseTask: Task<Void, Never>?
    private var passThroughToken = UUID()
    private var expanded = false
    /// Stays true through the close animation so a still-visible card does not
    /// pass a click through to whatever is underneath.
    private var passThroughExpanded = false
    private var idleTicks = 0

    func sync(model: AppModel) {
        self.model = model
        if model.preferences.notchPanelEnabled {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard panel == nil, let model else { return }
        let hosting = NSHostingView(rootView: NotchLimitsView(model: model, state: state))
        hosting.sizingOptions = []
        let panel = LimitsNotchPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200))
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        self.panel = panel
        observeScreens()
        relayout(orderFront: true)
        startTimer()
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        collapseTask?.cancel()
        collapseTask = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
        expanded = false
        passThroughExpanded = false
        state.expanded = false
    }

    private func observeScreens() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.relayout(orderFront: false)
            }
        }
    }

    private func relayout(orderFront: Bool) {
        guard let panel else { return }
        guard let screen = NotchMetrics.screen() else {
            panel.orderOut(nil)
            return
        }
        let metrics = NotchMetrics.measure(screen)
        if state.metrics != metrics {
            state.metrics = metrics
        }
        let frame = NotchLayout.windowFrame(metrics: metrics)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        if orderFront || !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard panel != nil, let model else { return }
        let point = NSEvent.mouseLocation
        let metrics = state.metrics
        let near = point.y > metrics.screenMaxY - 320 && abs(point.x - metrics.notchCenterX) < 700
        if !near && !expanded {
            idleTicks += 1
            if idleTicks % 4 != 0 { return }
            panel?.ignoresMouseEvents = true
            return
        }
        idleTicks = 0

        let count = providerCount
        let inside = NotchLayout.pointerInside(
            metrics: metrics,
            expanded: expanded,
            providerCount: count,
            point: point,
            sloppy: true
        )
        if inside {
            open()
        } else if expanded {
            scheduleCollapse()
        }

        let interactive = passThroughExpanded && NotchLayout.interactive(
            metrics: metrics,
            expanded: true,
            providerCount: count,
            point: point
        )
        panel?.ignoresMouseEvents = !interactive
    }

    private var providerCount: Int {
        guard let model else { return 0 }
        return NotchContent.providers(
            snapshot: model.snapshot,
            enabled: model.preferences.enabledProviderIDs,
            primary: model.preferences.primaryProviderID
        ).count
    }

    private func open() {
        collapseTask?.cancel()
        collapseTask = nil
        let wasClosed = !expanded
        expanded = true
        passThroughExpanded = true
        guard wasClosed else { return }
        state.expanded = true
        panel?.orderFrontRegardless()
        guard let model else { return }
        Task { await model.refresh() }
    }

    private func scheduleCollapse() {
        guard collapseTask == nil else { return }
        collapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            self.collapseTask = nil
            self.close()
        }
    }

    private func close() {
        guard expanded else { return }
        expanded = false
        state.expanded = false
        let token = UUID()
        passThroughToken = token
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 340_000_000)
            guard self.passThroughToken == token, !self.expanded else { return }
            self.passThroughExpanded = false
        }
    }
}
