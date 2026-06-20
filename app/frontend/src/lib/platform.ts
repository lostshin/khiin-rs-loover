import { invoke } from "@tauri-apps/api/core";
import { readable } from "svelte/store";

// Platform flags resolved once at startup from the Tauri backend.
// Used to gate the macOS-only redesign so Windows keeps its existing UI.
export const isWindows = readable(false, (set) => {
    invoke<boolean>("is_windows")
        .then(set)
        .catch(() => set(false));
});

export const isMac = readable(true, (set) => {
    invoke<boolean>("is_windows")
        .then((w) => set(!w))
        .catch(() => set(true));
});
