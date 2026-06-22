<script lang="ts">
    import { _ } from "svelte-i18n";
    import { onDestroy } from "svelte";
    import {
        MODIFIER_CODES,
        validateShortcut,
    } from "$lib/ShortcutPolicy.js";

    type ModifierName = "Control" | "Alt" | "Shift" | "Meta";

    // Records an arbitrary key / key-combo for the switch-mode shortcut. Keys are
    // stored as W3C UI Events `code` names (physical-position based) so the macOS
    // IME can map them to virtual key codes regardless of layout. See the Swift
    // `ModeShortcut` parser for the accepted formats.
    export let value: string = "default";
    export let onChange: (v: string) => void = () => {};

    let recording = false;
    let heldMods = new Set<ModifierName>();
    let loneCandidate: string | null = null;
    let sawNonModifier = false;
    let errorKey: string | null = null;

    function modName(code: string): ModifierName | null {
        if (code.startsWith("Shift")) return "Shift";
        if (code.startsWith("Control")) return "Control";
        if (code.startsWith("Alt")) return "Alt";
        if (code.startsWith("Meta")) return "Meta";
        return null;
    }

    function startRecording() {
        recording = true;
        heldMods = new Set();
        loneCandidate = null;
        sawNonModifier = false;
        errorKey = null;
        window.addEventListener("keydown", onKeyDown, true);
        window.addEventListener("keyup", onKeyUp, true);
    }

    function stopRecording() {
        recording = false;
        errorKey = null;
        window.removeEventListener("keydown", onKeyDown, true);
        window.removeEventListener("keyup", onKeyUp, true);
    }

    function finalize(token: string) {
        stopRecording();
        value = token;
        onChange(token);
    }

    function onKeyDown(e: KeyboardEvent) {
        if (!recording) return;
        e.preventDefault();
        e.stopPropagation();
        if (e.code === "Escape") {
            stopRecording();
            return;
        }
        if (MODIFIER_CODES.has(e.code)) {
            // Only the very first modifier, pressed alone, can become a lone tap.
            loneCandidate = !sawNonModifier && heldMods.size === 0 ? e.code : null;
            const n = modName(e.code);
            if (n) heldMods.add(n);
            return;
        }
        // A normal key: require at least one modifier so the shortcut can't
        // hijack a plain typing key.
        sawNonModifier = true;
        loneCandidate = null;
        const mods: ModifierName[] = [];
        if (e.ctrlKey) mods.push("Control");
        if (e.altKey) mods.push("Alt");
        if (e.shiftKey) mods.push("Shift");
        if (e.metaKey) mods.push("Meta");
        if (mods.length === 0) return;
        const result = validateShortcut(mods, e.code);
        if (!result.ok) {
            errorKey =
                result.reason === "unsupported"
                    ? "page.input.shortcut-unsupported"
                    : "page.input.shortcut-conflict";
            return;
        }
        finalize(result.token);
    }

    function onKeyUp(e: KeyboardEvent) {
        if (!recording) return;
        e.preventDefault();
        e.stopPropagation();
        if (MODIFIER_CODES.has(e.code)) {
            const n = modName(e.code);
            if (n) heldMods.delete(n);
            // A modifier released on its own (nothing else pressed) is a lone tap.
            if (loneCandidate === e.code && !sawNonModifier) {
                finalize(e.code);
            }
            loneCandidate = null;
            if (heldMods.size === 0) {
                sawNonModifier = false;
            }
        }
    }

    function resetDefault() {
        if (recording) stopRecording();
        value = "default";
        onChange("default");
    }

    onDestroy(() => {
        if (recording) stopRecording();
    });

    // --- display helpers ---
    const MOD_SYMBOL: Record<string, string> = {
        Control: "⌃", Alt: "⌥", Shift: "⇧", Meta: "⌘",
    };
    const CODE_LABEL: Record<string, string> = {
        Backquote: "`", Minus: "-", Equal: "=", BracketLeft: "[",
        BracketRight: "]", Backslash: "\\", Semicolon: ";", Quote: "'",
        Comma: ",", Period: ".", Slash: "/",
        Space: "Space", Enter: "Enter", Tab: "Tab",
    };

    function codeLabel(code: string): string {
        if (code.startsWith("Key")) return code.slice(3);
        if (code.startsWith("Digit")) return code.slice(5);
        if (MODIFIER_CODES.has(code)) {
            const side = code.endsWith("Left") ? "L" : "R";
            return side + " " + MOD_SYMBOL[modName(code)!];
        }
        return CODE_LABEL[code] ?? code;
    }

    function pretty(v: string): string {
        if (!v || v === "default") return "⌥ + `";
        if (v === "shift") return "⇧";
        const parts = v.split("+");
        const code = parts.pop()!;
        const mods = parts.map((m) => MOD_SYMBOL[m] ?? m);
        return [...mods, codeLabel(code)].join(" + ");
    }

    $: display = recording ? $_("page.input.recording") : pretty(value);
</script>

<div>
    <div class="flex items-center gap-2">
        <span
            class="min-w-[64px] rounded-md border px-2 py-1 text-center text-sm {recording
                ? 'border-blue-400 text-blue-600'
                : 'border-gray-300 text-gray-800'}"
        >
            {display}
        </span>
        <button
            type="button"
            class="rounded-md border border-gray-300 px-2 py-1 text-sm hover:bg-gray-50"
            on:click={() => (recording ? stopRecording() : startRecording())}
        >
            {recording ? $_("page.input.recording-cancel") : $_("page.input.record")}
        </button>
        <button
            type="button"
            class="text-sm text-gray-400 hover:text-gray-600"
            on:click={resetDefault}
        >
            {$_("page.input.reset-shortcut")}
        </button>
    </div>
    {#if errorKey}
        <p class="mt-1 max-w-xs text-xs text-red-600" role="alert">
            {$_(errorKey)}
        </p>
    {/if}
</div>
