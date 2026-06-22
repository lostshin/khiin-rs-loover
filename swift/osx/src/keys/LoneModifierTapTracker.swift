struct LoneModifierTapTracker {
    private(set) var targetKeyCodes: Set<UInt16>
    private var pressedTargetKeyCodes: Set<UInt16> = []
    private var armedKeyCode: UInt16?
    private var invalidated = false

    init(targetKeyCodes: Set<UInt16> = []) {
        self.targetKeyCodes = targetKeyCodes
    }

    mutating func configure(targetKeyCodes: Set<UInt16>) {
        guard self.targetKeyCodes != targetKeyCodes else { return }
        self.targetKeyCodes = targetKeyCodes
        reset()
    }

    mutating func handleTargetKeyChange(keyCode: UInt16) -> Bool {
        guard targetKeyCodes.contains(keyCode) else {
            cancel()
            return false
        }

        if pressedTargetKeyCodes.contains(keyCode) {
            pressedTargetKeyCodes.remove(keyCode)
            let shouldToggle =
                !invalidated
                && armedKeyCode == keyCode
                && pressedTargetKeyCodes.isEmpty
            if pressedTargetKeyCodes.isEmpty {
                resetSequence()
            }
            return shouldToggle
        }

        pressedTargetKeyCodes.insert(keyCode)
        if pressedTargetKeyCodes.count == 1 && armedKeyCode == nil && !invalidated {
            armedKeyCode = keyCode
        } else {
            armedKeyCode = nil
            invalidated = true
        }
        return false
    }

    mutating func cancel() {
        if pressedTargetKeyCodes.isEmpty {
            resetSequence()
        } else {
            armedKeyCode = nil
            invalidated = true
        }
    }

    mutating func reset() {
        pressedTargetKeyCodes.removeAll()
        resetSequence()
    }

    private mutating func resetSequence() {
        armedKeyCode = nil
        invalidated = false
    }
}
