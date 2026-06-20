import { writable } from "svelte/store";

// Transient "applied" confirmation shown after settings are saved.
export const toastMessage = writable<string>("");

let timer: ReturnType<typeof setTimeout> | undefined;

export function showToast(message: string, duration = 1600) {
    toastMessage.set(message);
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => toastMessage.set(""), duration);
}
