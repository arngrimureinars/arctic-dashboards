<!-- Footer matching the website: polar-night band with logo, tagline and main links. -->
<script>
	import Logo from './Logo.svelte';
	const site = 'https://prismatic-blini-161853.netlify.app';
	const links = [['Heim', '/'], ['Þjónusta', '/thjonusta'], ['Mælaborð', '/maelabord'], ['Blogg', '/blogg'], ['Um okkur', '/um-okkur']];
</script>

<footer class="aa-footer logo-on-dark">
	<div class="aa-footer-inner">
		<div>
			<div class="aa-brand"><Logo size={30} id="ftr" /><span><b>Arctic</b> Analytics</span></div>
			<p class="aa-tag">Íslensk gagnaráðgjöf · Mælaborð byggð á opnum gögnum, uppfærð daglega</p>
		</div>
		<nav>
			{#each links as [label, href]}<a href={site + href}>{label}</a>{/each}
			<a href="/lineage/index.html">Gagnaflæði</a>
		</nav>
	</div>
	<div class="aa-copy">© {new Date().getFullYear()} Arctic Analytics</div>
</footer>

<style>
	.aa-footer { background: #0b1d2e; color: #e6f1f8; margin-top: 2.5rem; }
	.aa-footer-inner { max-width: 1400px; margin: 0 auto; padding: 2.2rem 1.5rem 1.5rem; display: flex; flex-wrap: wrap; gap: 1.5rem; justify-content: space-between; }
	.aa-brand { display: flex; align-items: center; gap: 0.55rem; font-family: Manrope, Inter, system-ui, sans-serif; font-size: 1.1rem; }
	.aa-brand b { font-weight: 800; }
	.aa-tag { opacity: 0.65; font-size: 0.85rem; margin-top: 0.5rem; }
	nav { display: flex; flex-wrap: wrap; gap: 0.4rem 1.4rem; align-items: flex-start; font-size: 0.9rem; }
	nav a { opacity: 0.8; }
	nav a:hover { opacity: 1; color: #99f6e4; }
	.aa-copy { border-top: 1px solid rgb(255 255 255 / 0.1); max-width: 1400px; margin: 0 auto; padding: 0.9rem 1.5rem; font-size: 0.75rem; opacity: 0.55; }
</style>
