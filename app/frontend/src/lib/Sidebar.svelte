<script>
    import { _ } from "svelte-i18n";
    import { page } from "$app/stores";
    import SidebarItem from "./SidebarItem.svelte";
    import { isMac } from "./platform";

    // macOS-only information architecture: the overloaded Input page is split
    // into Input (modes) + Keys (Telex remapping). Windows keeps its old nav.
    const macNav = [
        { route: "/appearance", icon: "bx-cog", key: "global.nav.general" },
        { route: "/input", icon: "bx-edit", key: "global.nav.input" },
        { route: "/keys", icon: "bx-keyboard", key: "global.nav.keys" },
    ];

    $: pathname = $page.url.pathname;
</script>

<div class="w-56 flex-none" />
<nav
    class="
        fixed
        flex-none
        h-screen
        w-56
        flex
        flex-col
        overflow-hidden
        rounded-tl-lg
        bg-slate-100
        "
>
    <h1 class="flex pl-4 pt-5 pb-3 text-xl">Khíín</h1>

    {#if $isMac}
        <ul class="flex flex-1 flex-col gap-1 px-2">
            {#each macNav as item}
                <li>
                    <a
                        href={item.route}
                        class="flex h-10 items-center gap-3 rounded-lg px-3 text-sm transition-colors
                        {pathname === item.route
                            ? 'bg-white text-gray-900 shadow-sm'
                            : 'text-gray-500 hover:bg-white/60 hover:text-gray-800'}"
                    >
                        <i class="bx {item.icon} text-lg" />
                        <span class="font-medium">{$_(item.key)}</span>
                    </a>
                </li>
            {/each}
            <li class="mt-auto">
                <a
                    href="/about"
                    class="flex h-10 items-center gap-3 rounded-lg px-3 text-sm transition-colors
                    {pathname === '/about'
                        ? 'bg-white text-gray-900 shadow-sm'
                        : 'text-gray-500 hover:bg-white/60 hover:text-gray-800'}"
                >
                    <i class="bx bx-info-circle text-lg" />
                    <span class="font-medium">{$_("global.nav.about")}</span>
                </a>
            </li>
            <li class="mb-2">
                <a
                    href="https://github.com/OMAMA-Taioan/khiin-rs"
                    target="_blank"
                    rel="noreferrer"
                    class="flex h-10 items-center gap-3 rounded-lg px-3 text-sm text-gray-500 transition-colors hover:bg-white/60 hover:text-gray-800"
                >
                    <i class="bx bxl-github text-lg" />
                    <span class="font-medium">{$_("global.nav.github")}</span>
                </a>
            </li>
        </ul>
    {:else}
        <ul class="flex flex-col flex-1">
            <li>
                <SidebarItem
                    route="/appearance"
                    iconClass="bx-font-family"
                    label={$_("global.nav.appearance")}
                />
            </li>
            <li>
                <SidebarItem
                    route="/input"
                    iconClass="bx-edit"
                    label={$_("global.nav.input-settings")}
                />
            </li>
            <li class="mt-auto">
                <SidebarItem
                    route="/about"
                    iconClass="bx-info-circle"
                    label={$_("global.nav.about")}
                />
            </li>
            <li>
                <SidebarItem
                    target="_blank"
                    route="https://github.com/OMAMA-Taioan/khiin-rs"
                    iconClass="bxl-github"
                    label={$_("global.nav.github")}
                />
            </li>
        </ul>
    {/if}
</nav>
