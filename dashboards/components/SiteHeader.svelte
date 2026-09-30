<!-- Header matching the Arctic Analytics website: dark top strip, frosted bar with logo and
     the site's main menu (Mælaborð active), aurora line underneath. -->
<script>
	import Logo from './Logo.svelte';
	// The website's address – update when the site gets its own domain.
	const site = 'https://prismatic-blini-161853.netlify.app';
	const nav = [
		{ label: 'Heim', href: '/' },
		{ label: 'Þjónusta', href: '/thjonusta' },
		{ label: 'Mælaborð', href: '/maelabord', active: true },
		{ label: 'Blogg', href: '/blogg' },
		{ label: 'Um okkur', href: '/um-okkur' }
	];
	let open = false;
</script>

<div class="aa-strip">
	<div class="aa-wrap aa-strip-inner">
		<a href="/">Mælaborð Arctic Analytics</a>
		<a href={site} class="aa-pill">Aðalvefur ↗</a>
	</div>
</div>
<header class="aa-header">
	<div class="aa-wrap aa-header-inner">
		<a href={site} class="aa-brand" aria-label="Arctic Analytics">
			<Logo size={34} id="hdr" />
			<span><b>Arctic</b> Analytics</span>
		</a>
		<nav class="aa-nav" class:open>
			{#each nav as item}
				<a href={item.active ? '/' : site + item.href} class:active={item.active}>{item.label}</a>
			{/each}
		</nav>
		<button class="aa-menu" aria-label="Valmynd" on:click={() => (open = !open)}>☰</button>
	</div>
	<div class="aa-aurora-line" />
</header>

<style>
	.aa-wrap { max-width: 1400px; margin: 0 auto; padding: 0 1.5rem; }
	.aa-strip { background: #06121c; color: #94a3b8; font-size: 0.75rem; }
	.aa-strip-inner { display: flex; justify-content: space-between; align-items: center; height: 2.1rem; }
	.aa-strip a:hover { color: #99f6e4; }
	.aa-pill { border: 1px solid rgb(255 255 255 / 0.15); border-radius: 999px; padding: 0.15rem 0.7rem; color: #e2e8f0; }
	.aa-header { position: sticky; top: 0; z-index: 40; backdrop-filter: blur(10px) saturate(1.5); background: rgb(255 255 255 / 0.85); }
	:global(html[data-theme='dark']) .aa-header { background: rgb(11 22 34 / 0.85); }
	.aa-header-inner { display: flex; align-items: center; justify-content: space-between; height: 4rem; }
	.aa-brand { display: flex; align-items: center; gap: 0.6rem; font-family: Manrope, Inter, system-ui, sans-serif; font-size: 1.15rem; letter-spacing: -0.01em; }
	.aa-brand b { font-weight: 800; }
	.aa-brand span { font-weight: 500; }
	.aa-nav { display: flex; gap: 0.25rem; }
	.aa-nav a { padding: 0.45rem 0.9rem; border-radius: 0.5rem; font-weight: 500; font-size: 0.95rem; opacity: 0.85; }
	.aa-nav a:hover { opacity: 1; color: #0e5a8a; }
	.aa-nav a.active { background: rgb(14 90 138 / 0.1); color: #0e5a8a; font-weight: 600; opacity: 1; }
	:global(html[data-theme='dark']) .aa-nav a.active, :global(html[data-theme='dark']) .aa-nav a:hover { color: #7cc4ef; background: rgb(124 196 239 / 0.12); }
	.aa-menu { display: none; font-size: 1.3rem; background: none; border: none; cursor: pointer; color: inherit; }
	.aa-aurora-line { height: 1px; background: linear-gradient(90deg, transparent, rgb(45 212 191 / 0.6), transparent); }
	@media (max-width: 900px) {
		.aa-menu { display: block; }
		.aa-nav { display: none; position: absolute; top: 4rem; right: 1rem; flex-direction: column; background: #fff; border: 1px solid rgb(125 196 239 / 0.35); border-radius: 0.75rem; padding: 0.5rem; box-shadow: 0 10px 30px -10px rgb(0 0 0 / 0.3); }
		.aa-nav.open { display: flex; }
		:global(html[data-theme='dark']) .aa-nav { background: #0b1622; }
	}
</style>
