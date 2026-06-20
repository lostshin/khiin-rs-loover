<script lang="ts">
    import { _ } from "svelte-i18n";
    import { settings } from "../store.js";
    import { invoke } from "@tauri-apps/api/core";
    import { showToast } from "$lib/toast";
    import SettingsGroup from "$lib/SettingsGroup.svelte";
    import SettingsRow from "$lib/SettingsRow.svelte";

    const sel =
        "rounded-md border border-gray-300 bg-white py-1 pl-2 pr-7 text-sm focus:border-gray-400 focus:outline-none focus:ring-1 focus:ring-gray-300";

    let t2_key = $settings.input_settings.t2;
    let t3_key = $settings.input_settings.t3;
    let t5_key = $settings.input_settings.t5;
    let t6_key = $settings.input_settings.t6;
    let t7_t8_key = $settings.input_settings.t7;
    let t9_key = $settings.input_settings.t9;
    let hyphen_key = $settings.input_settings.hyphen;
    let khin_key = $settings.input_settings.khin;
    let done_key = $settings.input_settings.done;

    // Available keys for Telex: SFLJXW + DVR + YQZ
    const allKeys = ["s", "f", "l", "j", "x", "w", "d", "v", "r", "y", "q", "z"];

    $: currentAssignments = {
        t2: t2_key,
        t3: t3_key,
        t5: t5_key,
        t6: t6_key,
        t7_t8: t7_t8_key,
        t9: t9_key,
        hyphen: hyphen_key,
        khin: khin_key,
        done: done_key,
    };

    $: allUsedKeys = Object.values(currentAssignments).filter((k) => k);

    function getOptionsFor(fieldKey: string, _dependencies?: any) {
        const myCurrentValue = currentAssignments[fieldKey];
        return allKeys.filter((key) => {
            const isUsed = allUsedKeys.includes(key);
            const isMyValue = key === myCurrentValue;
            return !isUsed || isMyValue;
        });
    }

    async function keySettingChanged(field: string, event) {
        const newValue = event.target.value;
        settings.update((settings) => {
            switch (field) {
                case "t2":
                    settings.input_settings.t2 = newValue;
                    break;
                case "t3":
                    settings.input_settings.t3 = newValue;
                    break;
                case "t5":
                    settings.input_settings.t5 = newValue;
                    break;
                case "t6":
                    settings.input_settings.t6 = newValue;
                    break;
                case "t7_t8":
                    settings.input_settings.t7 = newValue;
                    settings.input_settings.t8 = newValue;
                    break;
                case "t9":
                    settings.input_settings.t9 = newValue;
                    break;
                case "hyphen":
                    settings.input_settings.hyphen = newValue;
                    break;
                case "khin":
                    settings.input_settings.khin = newValue;
                    break;
                case "done":
                    settings.input_settings.done = newValue;
                    break;
            }
            return settings;
        });
        await updateSettings();
    }

    async function updateSettings() {
        try {
            await invoke("update_settings", {
                settings: JSON.stringify($settings),
            });
            showToast($_("global.toast.saved"));
        } catch (error) {
            console.error("Failed to update settings:", error);
        }
    }
</script>

<h1 class="mb-1 text-2xl font-semibold text-gray-800">
    {$_("page.keys.title")}
</h1>
<p class="mb-6 text-sm text-gray-400">{$_("page.keys.desc")}</p>

<SettingsGroup title={$_("page.input.telex-key-settings")}>
    <SettingsRow label={$_("page.input.t2-key")}>
        <select class={sel} bind:value={t2_key} on:change={(e) => keySettingChanged("t2", e)}>
            {#each getOptionsFor("t2", allUsedKeys) as key}
                <option value={key}>{key.toUpperCase()}</option>
            {/each}
        </select>
    </SettingsRow>
    <SettingsRow label={$_("page.input.t3-key")}>
        <select class={sel} bind:value={t3_key} on:change={(e) => keySettingChanged("t3", e)}>
            {#each getOptionsFor("t3", allUsedKeys) as key}
                <option value={key}>{key.toUpperCase()}</option>
            {/each}
        </select>
    </SettingsRow>
    <SettingsRow label={$_("page.input.t5-key")}>
        <select class={sel} bind:value={t5_key} on:change={(e) => keySettingChanged("t5", e)}>
            {#each getOptionsFor("t5", allUsedKeys) as key}
                <option value={key}>{key.toUpperCase()}</option>
            {/each}
        </select>
    </SettingsRow>
    <SettingsRow label={$_("page.input.t6-key")}>
        <select class={sel} bind:value={t6_key} on:change={(e) => keySettingChanged("t6", e)}>
            {#each getOptionsFor("t6", allUsedKeys) as key}
                <option value={key}>{key.toUpperCase()}</option>
            {/each}
        </select>
    </SettingsRow>
    <SettingsRow label={$_("page.input.t7-t8-key")}>
        <select class={sel} bind:value={t7_t8_key} on:change={(e) => keySettingChanged("t7_t8", e)}>
            {#each getOptionsFor("t7_t8", allUsedKeys) as key}
                <option value={key}>{key.toUpperCase()}</option>
            {/each}
        </select>
    </SettingsRow>
    <SettingsRow label={$_("page.input.t9-key")}>
        <select class={sel} bind:value={t9_key} on:change={(e) => keySettingChanged("t9", e)}>
            {#each getOptionsFor("t9", allUsedKeys) as key}
                <option value={key}>{key.toUpperCase()}</option>
            {/each}
        </select>
    </SettingsRow>
    <SettingsRow label={$_("page.input.khin-key")}>
        <select class={sel} bind:value={khin_key} on:change={(e) => keySettingChanged("khin", e)}>
            {#each getOptionsFor("khin", allUsedKeys) as key}
                <option value={key}>{key.toUpperCase()}</option>
            {/each}
        </select>
    </SettingsRow>
</SettingsGroup>

<SettingsGroup>
    <SettingsRow label={$_("page.input.hyphen-key")}>
        <select class={sel} bind:value={hyphen_key} on:change={(e) => keySettingChanged("hyphen", e)}>
            {#each getOptionsFor("hyphen", allUsedKeys) as key}
                <option value={key}>{key.toUpperCase()}</option>
            {/each}
        </select>
    </SettingsRow>
    <SettingsRow label={$_("page.input.done-key")}>
        <select class={sel} bind:value={done_key} on:change={(e) => keySettingChanged("done", e)}>
            {#each getOptionsFor("done", allUsedKeys) as key}
                <option value={key}>{key.toUpperCase()}</option>
            {/each}
        </select>
    </SettingsRow>
</SettingsGroup>
