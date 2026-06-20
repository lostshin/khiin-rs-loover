<script lang="ts">
    import { _, locale } from "svelte-i18n"
    import { settings } from "../store";
    import { invoke } from "@tauri-apps/api/core";
    import { isMac } from "$lib/platform";
    import { showToast } from "$lib/toast";
    import SettingsGroup from "$lib/SettingsGroup.svelte";
    import SettingsRow from "$lib/SettingsRow.svelte";

    const sel =
        "rounded-md border border-gray-300 bg-white py-1 pl-2 pr-7 text-sm focus:border-gray-400 focus:outline-none focus:ring-1 focus:ring-gray-300";

    async function updateLanguage(event: Event) {
        const target = event.target as HTMLSelectElement;
        locale.set(target.value);
        $settings.appearance.locale = target.value;
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

{#if $isMac}
    <h1 class="mb-6 text-2xl font-semibold text-gray-800">
        {$_("global.nav.general")}
    </h1>
    <SettingsGroup>
        <SettingsRow
            label={$_("page.appearance.language")}
            description={$_("page.appearance.language-desc")}
        >
            <select
                class={sel}
                bind:value={$settings.appearance.locale}
                on:change={updateLanguage}
            >
                <option value="en">English</option>
                <option value="oan_Han">漢羅</option>
                <option value="oan_Latn">Lômájī</option>
            </select>
        </SettingsRow>
        <SettingsRow
            label={$_("page.appearance.font-size")}
            description={$_("page.appearance.font-size-desc")}
        >
            <select
                class={sel}
                bind:value={$settings.candidates.font_size}
                on:change={updateSettings}
            >
                <option value={20}>{$_("page.appearance.lg")}</option>
                <option value={16}>{$_("page.appearance.sm")}</option>
            </select>
        </SettingsRow>
    </SettingsGroup>
{:else}
    <h1 class="text-3xl mb-3">{$_('page.appearance.title')}</h1>

    <div class="mt-8 max-w-md">
        <div class="grid grid-cols-1 gap-6">
            <label class="block">
              <span class="text-gray-700">{$_('page.appearance.language')}</span>
              <select class="block w-full mt-1 rounded-md border-slate-300 shadow-sm focus:border-slate-300 focus:ring focus:ring-slate-200 focus:ring-opacity-50" bind:value={$settings.appearance.locale} on:change={updateLanguage}>
                <option value="en">English</option>
                <option value="oan_Han">漢羅</option>
                <option value="oan_Latn">Lômájī</option>
              </select>
            </label>
            <label class="block">
              <span class="text-gray-700">{$_('page.appearance.font-size')}</span>
              <select class="block w-full mt-1 rounded-md border-slate-300 shadow-sm focus:border-slate-300 focus:ring focus:ring-slate-200 focus:ring-opacity-50" bind:value={$settings.candidates.font_size} on:change={updateSettings}>
                <option value={20}>{$_('page.appearance.lg')}</option>
                <option value={16}>{$_('page.appearance.sm')}</option>
              </select>
            </label>
        </div>
    </div>
{/if}
