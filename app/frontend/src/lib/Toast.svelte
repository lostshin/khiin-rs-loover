<script lang="ts">
    import { fly } from "svelte/transition";
    import { toastMessage } from "./toast";
</script>

{#if $toastMessage}
    <div
        class="fixed bottom-6 right-6 z-50 flex items-center gap-2 rounded-lg bg-gray-800 px-4 py-2 text-sm text-white shadow-lg"
        transition:fly={{ y: 12, duration: 180 }}
    >
        <i class="bx bx-check text-base text-green-400" />
        <span>{$toastMessage}</span>
    </div>
{/if}
