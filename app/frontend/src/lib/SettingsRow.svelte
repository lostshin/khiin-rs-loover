<script lang="ts">
    // A single row inside a <SettingsGroup>: label + optional description/example
    // on the left, the control passed via the default slot on the right.
    export let label: string;
    export let description: string = "";
    export let example: string = "";
</script>

<div class="flex items-center justify-between gap-4 px-4 py-3">
    <div class="min-w-0">
        <div class="text-sm text-gray-800">{label}</div>
        {#if description}
            <div class="mt-0.5 text-xs leading-snug text-gray-400">
                {description}
            </div>
        {/if}
        {#if example}
            <div
                class="mt-1 inline-block rounded bg-gray-50 px-1.5 py-0.5 font-mono text-xs text-gray-500"
            >
                {example}
            </div>
        {/if}
    </div>
    <div class="flex-none">
        <slot />
    </div>
</div>
