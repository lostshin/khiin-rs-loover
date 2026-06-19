import InputMethodKit
import SwiftyBeaver
import KhiinSwift

class KhiinInputController: IMKInputController {
    lazy var window: NSWindow? = nil

    lazy var currentClient: IMKTextInput? = nil {
        didSet {
            if window != nil {
                self.resetWindow()
            }
        }
    }

    lazy var currentOrigin: CGPoint? = nil

    let candidateViewModel = CandidateViewModel()

    override func activateServer(_ sender: Any!) {
        Logger.setup()
        EngineController.instance.reset()
        self.currentClient = sender as? IMKTextInput
        self.currentOrigin = self.currentClient?.position
    }

    override func deactivateServer(_ sender: Any!) {
        log.debug("deactivateServer ");
        _ = commitAll()
        candidateViewModel.reset()
        self.currentClient?.clearMarkedText()
        self.window?.setFrame(.zero, display: true)
        self.resetWindow()
    }

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        setupMouseEventMonitor()
    }

    func setupMouseEventMonitor() {
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            log.debug("mouse click event")
            self!.resetController()
        }
    }

    func resetController() {
        _ = commitAll()
        candidateViewModel.reset()
        self.currentClient?.clearMarkedText()
        self.window?.setFrame(.zero, display: true)
        self.resetWindow()
    }

    override func menu() -> NSMenu! {
        let khiinMenu = NSMenu()

        // Informational version row (disabled). Shows the bundle version plus
        // the build time, so it is clear exactly which build is running even
        // across rebuilds of the same version number.
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "?"
        var versionTitle = "Khíín \(version)"
        if let exec = Bundle.main.executableURL,
            let attrs = try? FileManager.default
                .attributesOfItem(atPath: exec.path),
            let built = attrs[.modificationDate] as? Date {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm"
            versionTitle += "  (\(fmt.string(from: built)))"
        }
        // action: nil leaves the item disabled (greyed) via auto-enabling.
        khiinMenu.addItem(
            NSMenuItem(title: versionTitle, action: nil, keyEquivalent: ""))
        khiinMenu.addItem(.separator())

        let settingMenuItem = NSMenuItem(
            title: "Settings..",
            action: #selector(self.openSettingApp),
            keyEquivalent: ""
        )
        settingMenuItem.target = self
        khiinMenu.addItem(settingMenuItem)

        return khiinMenu
    }

    func isEdited() -> Bool {
        return self.candidateViewModel.currentCommand.response.editState != .esEmpty
    }

    func isCommited() -> Bool {
        return self.candidateViewModel.currentCommand.response.committed;
    }

    func isIllegal() -> Bool {
        return self.candidateViewModel.currentCommand.response.editState == .esIllegal
    }

    func isManualMode() -> Bool {
        return EngineController.instance.isManualMode();
    }

    func isClassicMode() -> Bool {
        return EngineController.instance.isClassicMode();
    }

    func isHanjiFirst() -> Bool {
        return EngineController.instance.isHanjiFirst();
    }

    func isHyphenOrKhinKey(_ char: String) -> Bool {
        return isEdited() && (char == EngineController.instance.hyphenKey() || char == EngineController.instance.khinKey())
    }

    func getCommitedText() -> String {
        return self.candidateViewModel.currentCommand.response.committedText
    }

    func handleResponse() -> Bool {
        guard let client = self.currentClient else {
            return false
        }
        if (self.isCommited()) {
            let commitText = self.candidateViewModel
                .currentCommand
                .response
                .committedText
            client.insert(commitText)
            self.reset()
        } else {
            self.resetWindow()
            client.mark(self.currentDisplayText())
        }
        return true
    }

    func handlePunctuation(_ char: String) -> Bool {
        _ = self.commitAll();
        self.candidateViewModel.handleChar(char)
        return self.handleResponse();
    }

    func commitAll() -> Bool {
        var commitText = ""
        if (isManualMode()) {
            commitText = currentDisplayText();
        } else if (isClassicMode()) {
            self.candidateViewModel.handleCommit();
            commitText = self.candidateViewModel
                .currentCommand
                .response
                .committedText
        } else {
            let candList = self.candidateViewModel
                .currentCommand
                .response
                .candidateList

            let candidates = candList.candidates
            let focus = Int(candList.focused)
            
            guard candidates.count > 0 else {
                return false
            }

            commitText = candidates[focus < 0 ? 0 : focus].value
        }


        if (commitText.isEmpty) {
            return false
        }
        
        guard let client = self.currentClient else {
            return false
        }

        client.insert(commitText)
        if (isClassicMode()) {
            self.resetWindow()
            client.mark(self.currentDisplayText())
        } else {
            self.candidateViewModel.reset()
            EngineController.instance.reset()
            self.window?.setFrame(.zero, display: true)
        }
        return true
    }

    func commitCurrent() -> Bool {
        var commitText = ""
        if (isManualMode()) {
            commitText = currentDisplayText();
        } else if (isClassicMode()) {
            self.candidateViewModel.handleEnter();
            commitText = self.candidateViewModel
                .currentCommand
                .response
                .committedText
        } else {
            let candList = self.candidateViewModel
                .currentCommand
                .response
                .candidateList

            let candidates = candList.candidates
            let focus = Int(candList.focused)
            
            guard candidates.count > 0 else {
                return false
            }

            commitText = candidates[focus < 0 ? 0 : focus].value
        }


        if (commitText.isEmpty) {
            return false
        }
        
        guard let client = self.currentClient else {
            return false
        }

        client.insert(commitText)
        if (isClassicMode()) {
            self.resetWindow()
            client.mark(self.currentDisplayText())
        } else {
            self.candidateViewModel.reset()
            EngineController.instance.reset()
            self.window?.setFrame(.zero, display: true)
        }
        return true
    }

    func currentDisplayText() -> String {
    
        // Khiin_Proto_Preedit
        let preedit = self.candidateViewModel
            .currentCommand
            .response
            .preedit
        
        var disp_buffer = ""
        // var attr_buffer = ""

        // var char_count = 0
        // var caret = 0

        for segment in preedit.segments {
            log.debug("segment: \(segment)")
            var disp_seg = ""

            // if preedit.caret == char_count {
            //     caret = disp_buffer.count + disp_seg.count
            // }

            for ch in segment.value {
                disp_seg.append(ch)
                // char_count += 1
            }

            // let attr: Character
            // switch segment.status {
            // case .ssUnmarked:
            //     attr = " "
            // case .ssComposing:
            //     attr = "┄"
            // case .ssConverted:
            //     attr = "─"
            // case .ssFocused:
            //     attr = "━"
            // default:
            //     attr = " "
            // }

            // let seg_width = disp_seg.count
            // let seg_attr = String(repeating: String(attr), count: seg_width)
            disp_buffer.append(disp_seg)
            // attr_buffer.append(seg_attr)
            log.debug("disp_buffer: \(disp_buffer)")
        }

        // if preedit.caret == char_count {
        //     caret = disp_buffer.count
        // }

        return disp_buffer

    }

    func reset() {
        self.candidateViewModel.reset()
        self.window?.setFrame(.zero, display: true)
        self.resetWindow()
        EngineController.instance.reset()
    }

    @objc func openSettingApp() {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Applications/khiin_helper.app")

        guard FileManager.default.fileExists(atPath: helperURL.path) else {
            log.debug("Can't find helper app.")
            return
        }

        // Launch the helper through LaunchServices so it runs as its own GUI
        // app. Running its executable directly (via Process) as a child of this
        // background-only input method makes the Tauri/WebKit helper hang.
        let center = NSWorkspace.shared.notificationCenter
        center.removeObserver(
            self, name: NSWorkspace.didTerminateApplicationNotification,
            object: nil)
        center.addObserver(
            self, selector: #selector(helperDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        NSWorkspace.shared.openApplication(
            at: helperURL, configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error = error {
                log.debug("Run helper error: \(error)")
            }
        }
    }

    // Reload engine settings once the helper quits so edits take effect.
    @objc private func helperDidTerminate(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        guard app?.bundleIdentifier == "app.khiin" else { return }
        EngineController.instance.reloadSettings()
        log.debug("Helper quit; settings reloaded.")
        NSWorkspace.shared.notificationCenter.removeObserver(
            self, name: NSWorkspace.didTerminateApplicationNotification,
            object: nil)
    }
    //    override func inputText(_ string: String!, client sender: Any!) -> Bool {
    //        log.debug("inputText: \(string ?? "n/a")")
    //
    //        guard let client = self.currentClient else {
    //            return false
    //        }
    //
    //        if let first = string.first, first.isASCII && first.isLetter {
    //            let engine = EngineController.instance
    //
    //            let cmd = engine.handleChar(Int32(first.asciiValue!))
    //            if let cand = cmd?.response.candidateList.candidates.first?.value {
    //                client.insertText(
    //                    cand,
    //                    replacementRange: NSRange(
    //                        location: NSNotFound,
    //                        length: NSNotFound
    //                    )
    //                )
    //
    //                return true
    //            }
    //        }
    //
    //        client.insertText(
    //            string + string + string,
    //            replacementRange: NSRange(
    //                location: NSNotFound,
    //                length: NSNotFound
    //            )
    //        )
    //
    //        return true
    //    }
}
