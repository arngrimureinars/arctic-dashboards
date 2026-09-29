<script>
	import '@evidence-dev/tailwind/fonts.css';
	import '../app.css';
	import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
	export let data;
</script>

<svelte:head>
	<link rel="icon" href="/logo.svg" type="image/svg+xml" />
</svelte:head>

<EvidenceDefaultLayout
	{data}
	title="Arctic Analytics"
	logo="/logo.svg"
	homePageName="Mælaborð"
	builtWithEvidence={false}
	hideTOC={true}
>
	<slot slot="content" />
</EvidenceDefaultLayout>

<style>
	/* Evidence title-cases navigation labels ("Verðbólga Á Íslandi"); Icelandic keeps sentence case. */
	:global(.capitalize) {
		text-transform: none !important;
	}

	/* Report-style tiles for dashboard pages (lifeyrissjodir): charts sit in bordered cards on a grid. */
	:global(.tile) {
		border: 1px solid rgb(125 196 239 / 0.35);
		border-radius: 0.6rem;
		padding: 0.6rem 0.9rem 0.3rem;
		min-width: 0;
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
