<script>
	import '@evidence-dev/tailwind/fonts.css';
	import '../app.css';
	import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
	import SiteHeader from '$lib/SiteHeader.svelte';
	import SiteFooter from '$lib/SiteFooter.svelte';
	export let data;
</script>

<svelte:head>
	<link rel="icon" href="/logo.svg" type="image/svg+xml" />
	<link rel="preconnect" href="https://fonts.googleapis.com" />
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
	<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Manrope:wght@500;600;700;800&display=swap" />
</svelte:head>

<!-- The website's header and footer wrap every dashboard page, so the reports read as part of the site. -->
<SiteHeader />

<EvidenceDefaultLayout
	{data}
	title="Arctic Analytics"
	logo="/logo.svg"
	homePageName="Mælaborð"
	builtWithEvidence={false}
	hideTOC={true}
	hideHeader={true}
>
	<slot slot="content" />
</EvidenceDefaultLayout>

<SiteFooter />

<style>
	/* Evidence title-cases navigation labels ("Verðbólga Á Íslandi"); Icelandic keeps sentence case. */
	:global(.capitalize) {
		text-transform: none !important;
	}

	/* Website typography: Inter for text, Manrope for headings and titles. */
	:global(body) {
		font-family: Inter, system-ui, -apple-system, 'Segoe UI', sans-serif;
	}
	:global(h1), :global(h2), :global(h3), :global(.tile-title) {
		font-family: Manrope, Inter, system-ui, sans-serif;
	}
	/* Logo colours (components/Logo.svelte), as on the website */
	:global(:root) { --logo-a: #0e5a8a; --logo-b: #0d9488; --logo-core: #e0f7ff; }
	:global(html[data-theme='dark']) { --logo-a: #7cc4ef; --logo-b: #5eead4; }
	:global(.logo-on-dark) { --logo-a: #a5dcff; --logo-b: #5eead4; --logo-core: #ffffff; }

	/* Report tiles styled like the website's frosted "ice" cards. */
	:global(.tile) {
		border: 1px solid rgb(186 230 253 / 0.8);
		border-radius: 0.75rem;
		padding: 0.65rem 0.95rem 0.35rem;
		min-width: 0;
		background: linear-gradient(180deg, rgb(240 249 255) 0%, rgb(255 255 255) 55%);
		box-shadow: 0 1px 2px rgb(14 90 138 / 0.06);
		transition: box-shadow 0.3s, border-color 0.3s;
	}
	:global(.tile:hover) {
		border-color: rgb(94 234 212 / 0.7);
		box-shadow: 0 14px 40px -18px rgb(13 148 136 / 0.45);
	}
	:global(html[data-theme='dark'] .tile) {
		border-color: rgb(125 211 252 / 0.12);
		background: linear-gradient(180deg, rgb(56 189 248 / 0.07) 0%, rgb(11 22 34 / 0) 60%);
	}
	:global(.tile-title) {
		font-size: 0.8rem;
		font-weight: 600;
		letter-spacing: 0.01em;
		opacity: 0.8;
		margin: 0 0 0.1rem;
	}
	:global(.report-grid) {
		display: grid;
		gap: 0.75rem;
		grid-template-columns: repeat(1, minmax(0, 1fr));
		margin-bottom: 0.75rem;
	}
	@media (min-width: 1024px) {
		:global(.report-grid) {
			grid-template-columns: repeat(12, minmax(0, 1fr));
		}
		:global(.span-2) { grid-column: span 2 / span 2; }
		:global(.span-3) { grid-column: span 3 / span 3; }
		:global(.span-4) { grid-column: span 4 / span 4; }
		:global(.span-5) { grid-column: span 5 / span 5; }
		:global(.span-6) { grid-column: span 6 / span 6; }
		:global(.span-7) { grid-column: span 7 / span 7; }
		:global(.span-8) { grid-column: span 8 / span 8; }
		:global(.span-9) { grid-column: span 9 / span 9; }
		:global(.span-10) { grid-column: span 10 / span 10; }
		:global(.span-11) { grid-column: span 11 / span 11; }
		:global(.span-12) { grid-column: span 12 / span 12; }
	}
	/* Tighter vertical rhythm inside tiles */
	:global(.tile .mt-2),
	:global(.tile .mb-4) {
		margin-top: 0.25rem;
		margin-bottom: 0.25rem;
	}
</style>
