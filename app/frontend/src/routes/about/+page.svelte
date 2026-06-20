<script lang="ts">
    import { _ } from "svelte-i18n";
    import { invoke } from "@tauri-apps/api/core";
</script>

<h1 class="text-3xl mb-3">{$_("page.about.title")}</h1>

<div class="mt-8 flex flex-col items-center text-center">
    <img src="/logo_128.png" class="w-24 h-24 mb-4" alt="Khíín" />
    <h2 class="text-2xl">Khíín</h2>
    <p class="text-gray-500 mb-4">{$_("page.about.description")}</p>
    <p class="text-gray-700">
        {$_("page.about.version")}:
        {#await invoke("app_version") then version}
            <span class="font-medium">v{version}</span>
        {/await}
    </p>
    <a
        href="https://github.com/OMAMA-Taioan/khiin-rs"
        target="_blank"
        class="mt-4 inline-flex items-center text-gray-500 hover:text-gray-800"
    >
        <i class="bx bxl-github mr-1 text-lg" />
        <span class="text-sm">{$_("global.nav.github")}</span>
    </a>
</div>
