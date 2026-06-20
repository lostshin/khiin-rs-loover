<script lang="ts">
    // macOS System-Settings-style segmented control for settings with a small
    // number of choices (e.g. 自動/自由). Mirrors the look of the reference
    // panel's 自動/°C/°F control. Used on macOS in place of a <select>.
    export let value: string;
    export let options: { value: string; label: string }[] = [];
    export let disabled: boolean = false;
    export let onChange: (value: string) => void = () => {};

    function select(v: string) {
        if (disabled || v === value) return;
        value = v;
        onChange(v);
    }
</script>

<div
    class="inline-flex rounded-lg bg-gray-100 p-0.5 {disabled
        ? 'opacity-50'
        : ''}"
    role="radiogroup"
>
    {#each options as opt}
        <button
            type="button"
            role="radio"
            aria-checked={value === opt.value}
            {disabled}
            class="rounded-md px-3 py-1 text-sm transition-colors {value ===
            opt.value
                ? 'bg-white font-medium text-green-600 shadow-sm'
                : 'text-gray-500 hover:text-gray-700'} {disabled
                ? 'cursor-not-allowed'
                : 'cursor-pointer'}"
            on:click={() => select(opt.value)}
        >
            {opt.label}
        </button>
    {/each}
</div>
