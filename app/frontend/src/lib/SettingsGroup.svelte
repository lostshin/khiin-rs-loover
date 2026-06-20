<script lang="ts">
    // macOS System Settings-style grouped card. Wrap <SettingsRow>s inside.
    export let title: string = "";
</script>

<section class="mb-7 max-w-xl">
    {#if title}
        <h2
            class="mb-2 px-1 text-xs font-semibold uppercase tracking-wide text-gray-400"
        >
            {title}
        </h2>
    {/if}
    <div
        class="divide-y divide-gray-100 overflow-hidden rounded-xl border border-gray-200 bg-white"
    >
        <slot />
    </div>
</section>
