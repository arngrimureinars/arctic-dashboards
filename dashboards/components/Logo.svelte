<!-- The Arctic Analytics mark (same geometry as the website's NeuronMark): a neuron whose
     dendrites branch like a snowflake. Colours follow --logo-a/--logo-b set in +layout.svelte. -->
<script>
	export let size = 34;
	export let id = 'aa-logo';
	const arms = 'M32 23.5V10.5M39.36 27.75 50.62 21.25M39.36 36.25 50.62 42.75M32 40.5V53.5M24.64 36.25 13.38 42.75M24.64 27.75 13.38 21.25';
	const barbs = 'M32 16.5 27.17 12.15M32 16.5 36.83 12.15M45.42 24.25 46.77 17.89M45.42 24.25 51.61 26.26M45.42 39.75 51.61 37.74M45.42 39.75 46.77 46.11M32 47.5 36.83 51.85M32 47.5 27.17 51.85M18.58 39.75 17.23 46.11M18.58 39.75 12.39 37.74M18.58 24.25 12.39 26.26M18.58 24.25 17.23 17.89';
	const nodes = [[32, 7], [53.65, 19.5], [53.65, 44.5], [32, 57], [10.35, 44.5], [10.35, 19.5]];
</script>

<svg viewBox="0 0 64 64" width={size} height={size} aria-hidden="true">
	<defs>
		<linearGradient id="{id}-s" gradientUnits="userSpaceOnUse" x1="8" y1="6" x2="56" y2="58">
			<stop offset="0" style="stop-color: var(--logo-a)" />
			<stop offset="1" style="stop-color: var(--logo-b)" />
		</linearGradient>
	</defs>
	<path d="M32 7 53.65 19.5V44.5L32 57 10.35 44.5V19.5Z" fill="none" stroke="url(#{id}-s)" stroke-width="1.1" stroke-dasharray="2 2.6" opacity="0.45" />
	<path d={arms} fill="none" stroke="url(#{id}-s)" stroke-width="2.6" stroke-linecap="round" />
	<path d={barbs} fill="none" stroke="url(#{id}-s)" stroke-width="1.9" stroke-linecap="round" />
	{#each nodes as [x, y]}<circle cx={x} cy={y} r="3.2" fill="url(#{id}-s)" />{/each}
	<circle cx="32" cy="32" r="7.2" fill="url(#{id}-s)" />
	<circle cx="32" cy="32" r="3.2" fill="var(--logo-core)" />
</svg>
