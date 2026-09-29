<!--
  Report-style page tabs shared by the pension pages (/lifeyrissjodir, /lifeyrissjodir/skrad-felog
  and the per-fund pages), so every page shows that the others exist.
-->
<script>
	/** 'overview' | 'ownership' | 'fund' */
	export let active = 'overview';
	/** Name of the fund when active = 'fund' */
	export let fundName = undefined;

	const tabs = [
		{ key: 'overview', href: '/lifeyrissjodir', label: 'Yfirlit', hint: 'Eignir allra sjóða' },
		{ key: 'ownership', href: '/lifeyrissjodir/skrad-felog', label: 'Eignarhald í skráðum félögum', hint: 'Hver á hvað í Kauphöllinni' }
	];
</script>

<nav class="pension-tabs" aria-label="Síður um lífeyrissjóði">
	{#each tabs as tab}
		<a href={tab.href} class:active={active === tab.key} aria-current={active === tab.key ? 'page' : undefined}>
			<span class="label">{tab.label}</span>
			<span class="hint">{tab.hint}</span>
		</a>
	{/each}
	{#if active === 'fund' && fundName}
		<span class="tab active fund" aria-current="page">
			<span class="label">{fundName}</span>
			<span class="hint">Einstakur sjóður</span>
		</span>
	{:else}
		<a href="/lifeyrissjodir#sjodir" class="more">
			<span class="label">Einstakir sjóðir</span>
			<span class="hint">Veldu sjóð í töflunni</span>
		</a>
	{/if}
</nav>

<style>
	.pension-tabs {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
		border-bottom: 1px solid rgb(125 196 239 / 0.35);
		margin: 0 0 0.9rem;
	}
	.pension-tabs a,
	.pension-tabs .tab {
		display: flex;
		flex-direction: column;
		padding: 0.45rem 0.9rem 0.5rem;
		border: 1px solid transparent;
		border-bottom: none;
		border-radius: 0.5rem 0.5rem 0 0;
		margin-bottom: -1px;
		text-decoration: none;
		color: inherit;
		opacity: 0.75;
		transition: opacity 0.15s, background-color 0.15s;
	}
	.pension-tabs a:hover {
		opacity: 1;
		background: rgb(125 196 239 / 0.1);
	}
	.pension-tabs .active {
		opacity: 1;
		border-color: rgb(125 196 239 / 0.35);
		background: var(--base-100, transparent);
		box-shadow: inset 0 3px 0 #14b8a6;
	}
	.label {
		font-weight: 600;
		font-size: 0.9rem;
	}
	.hint {
		font-size: 0.7rem;
		opacity: 0.65;
	}
	.fund .label {
		color: #14b8a6;
	}
</style>
