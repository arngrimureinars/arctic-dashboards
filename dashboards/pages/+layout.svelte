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
</style>
