import SwiftUI

extension KhiinInputController {
    // Build the candidate window and its SwiftUI host exactly once. The host
    // observes `candidateViewModel`, so its content updates reactively without
    // tearing down and rebuilding the view tree.
    private func ensureWindow() {
        if self.window == nil {
            let window = NSWindow(
                contentRect: self.windowFrame(),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.collectionBehavior = .moveToActiveSpace
            window.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
            window.backgroundColor = .clear
            self.window = window
        }

        if self.candidateHost == nil {
            let host = NSHostingController(
                rootView: CandidateView().environmentObject(self.candidateViewModel)
            )
            host.view.translatesAutoresizingMaskIntoConstraints = false
            self.window?.contentView?.addSubview(host.view)
            self.window?.contentViewController?.addChild(host)
            self.candidateHost = host
            self.candidateAnchoredTop = nil  // force constraint setup below
        }
    }

    func resetWindow() {
        self.ensureWindow()

        let frame: CGRect = self.windowFrame()
        log.debug("Resetting window to frame: \(frame)")

        // Anchor the content to the top of the window when it sits below the
        // caret, or to the bottom when it sits above (the near-screen-edge
        // fallback). Only rebuild constraints when the side actually flips.
        if let contentView = self.window?.contentView,
            let hostView = self.candidateHost?.view {
            let origin = self.currentOrigin ?? self.currentClient?.position ?? .zero
            let anchorTop = origin.y > frame.minY
            if self.candidateAnchoredTop != anchorTop {
                self.candidateAnchoredTop = anchorTop
                self.candidateLeadingConstraint?.isActive = false
                self.candidateVerticalConstraint?.isActive = false

                let leading = hostView.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor)
                let vertical = anchorTop
                    ? hostView.topAnchor.constraint(equalTo: contentView.topAnchor)
                    : hostView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
                NSLayoutConstraint.activate([leading, vertical])
                self.candidateLeadingConstraint = leading
                self.candidateVerticalConstraint = vertical
            }
        }

        self.window?.setFrame(frame, display: true)
        self.window?.orderFrontRegardless()
    }

    func windowFrame() -> CGRect {
        let height: CGFloat = 24 * 9 + 8 * 2
        let origin = self.currentOrigin ?? self.currentClient?.position ?? .zero
        let size = CGSize(width: 500, height: height)

        guard let screenFrame = NSScreen.main?.visibleFrame else {
            return CGRect(
                x: origin.x, y: origin.y - height, width: size.width, height: size.height)
        }

        let y = origin.y - height < screenFrame.minY ? origin.y + 24 : origin.y - height
        return CGRect(
            x: origin.x, y: y, width: size.width, height: size.height)
    }
}
