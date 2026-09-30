<!-- Polar-night title band with northern lights and a mountain ridge, like the website's
     page headers. Filters go in the "filters" slot, shown on the right. -->
<script>
	export let title;
	export let subtitle = '';
	export let eyebrow = '';
</script>

<section class="aa-hero">
	<div class="aa-sky" aria-hidden="true">
		<div class="aur a1" /><div class="aur a2" /><div class="aur a3" />
	</div>
	<div class="aa-hero-inner">
		<div>
			{#if eyebrow}<p class="aa-eyebrow">{eyebrow}</p>{/if}
			<h1 class="aa-title">{title}</h1>
			{#if subtitle}<p class="aa-sub">{subtitle}</p>{/if}
		</div>
		<div class="aa-filters"><slot name="filters" /></div>
	</div>
	<svg class="aa-ridge" viewBox="0 0 1440 60" preserveAspectRatio="none" aria-hidden="true">
		<path d="M0 60V38l120-15 110 19 140-31 150 29 120-17 160 22 140-35 170 30 110-13 120 17 100-10V60Z" fill="rgb(186 230 253 / 0.18)" />
		<path d="M0 60V48l160-17 130 15 170-23 150 22 180-20 140 19 170-25 150 22 90-7 100 10V60Z" class="ridge-front" />
	</svg>
</section>

<style>
	.aa-hero { position: relative; overflow: hidden; background: radial-gradient(ellipse at top, #0c2436 0%, #06121c 65%); color: #f1f5f9; border-radius: 0.9rem; margin: 0.25rem 0 0.9rem; }
	.aa-sky { position: absolute; inset: 0; pointer-events: none; }
	.aur { position: absolute; border-radius: 100%; filter: blur(40px); }
	.a1 { left: -10%; top: -60%; width: 70%; height: 150%; background: linear-gradient(90deg, transparent, rgb(52 211 153 / 0.28), transparent); transform: rotate(-6deg); }
	.a2 { left: 25%; top: -40%; width: 60%; height: 120%; background: linear-gradient(90deg, transparent, rgb(94 234 212 / 0.2), rgb(14 165 233 / 0.12)); transform: rotate(4deg); }
	.a3 { right: -10%; top: -70%; width: 40%; height: 160%; background: rgb(139 92 246 / 0.12); }
	.aa-hero-inner { position: relative; display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-end; gap: 1rem; padding: 1.4rem 1.6rem 2.6rem; }
	.aa-eyebrow { font-size: 0.7rem; letter-spacing: 0.2em; text-transform: uppercase; color: #5eead4; font-weight: 600; margin-bottom: 0.2rem; }
	.aa-title { font-family: Manrope, Inter, system-ui, sans-serif; font-weight: 800; font-size: 1.9rem; line-height: 1.15; background: linear-gradient(135deg, #fff, #e0f2fe 55%, #99f6e4); -webkit-background-clip: text; background-clip: text; color: transparent; margin: 0; }
	.aa-sub { color: #cbd5e1; font-size: 0.8rem; margin-top: 0.35rem; opacity: 0.85; }
	/* Filters sit on a frosted light panel so Evidence's inputs keep their normal contrast. */
	.aa-filters { display: flex; flex-wrap: wrap; gap: 0.6rem; align-items: flex-end; }
	.aa-filters:not(:empty) { background: rgb(255 255 255 / 0.93); color: #0b1d2e; border-radius: 0.7rem; padding: 0.45rem 0.7rem 0.55rem; box-shadow: 0 8px 24px -12px rgb(0 0 0 / 0.5); }
	:global(html[data-theme='dark']) .aa-filters:not(:empty) { background: rgb(11 22 34 / 0.9); color: #e2e8f0; border: 1px solid rgb(125 211 252 / 0.2); }
	.ridge-front { fill: #fff; }
	:global(html[data-theme='dark']) .ridge-front { fill: #0b1622; }
	.aa-ridge { position: absolute; bottom: -1px; left: 0; width: 100%; height: 28px; }
</style>
