// Post-build step: serve DuckDB-WASM from jsDelivr instead of from our own site.
//
// Evidence bundles duckdb-eh.wasm and duckdb-mvp.wasm (~33 MB and ~38 MB), which is
// over Cloudflare Pages' 25 MiB per-file limit. jsDelivr hosts the identical files for
// the exact package version we have installed, so we point the build at those and drop
// the local copies. Fails if any file in the build is still too large.
import { readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const BUILD = "build";
const MAX_BYTES = 25 * 1024 * 1024;

const PKG = "node_modules/@duckdb/duckdb-wasm";
const { version } = JSON.parse(readFileSync(`${PKG}/package.json`, "utf8"));
const cdn = (file) => `https://cdn.jsdelivr.net/npm/@duckdb/duckdb-wasm@${version}/dist/${file}`;

function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(join(dir, e.name)) : [join(dir, e.name)],
  );
}

const files = walk(BUILD);
const wasm = files.filter((f) => /duckdb-(eh|mvp)\.[\w-]+\.wasm$/.test(f));
if (wasm.length === 0) throw new Error("No DuckDB wasm files found in the build – did Evidence change how it bundles DuckDB?");

for (const file of wasm) {
  const flavour = file.match(/duckdb-(eh|mvp)\./)[1];
  // Make sure the bundled file is the one from the installed package (and so on the CDN).
  if (statSync(file).size !== statSync(`${PKG}/dist/duckdb-${flavour}.wasm`).size) {
    throw new Error(`${file} does not match ${PKG}/dist/duckdb-${flavour}.wasm`);
  }
  const publicPath = "/" + file.slice(BUILD.length + 1).split("\\").join("/");
  let replaced = 0;
  for (const f of files.filter((f) => /\.(js|html|json)$/.test(f))) {
    const text = readFileSync(f, "utf8");
    if (text.includes(publicPath)) {
      writeFileSync(f, text.split(publicPath).join(cdn(`duckdb-${flavour}.wasm`)));
      replaced++;
    }
  }
  if (replaced === 0) throw new Error(`No references to ${publicPath} found`);
  rmSync(file);
  console.log(`duckdb-${flavour}.wasm → jsDelivr (@${version}), ${replaced} reference(s) updated`);
}

const tooBig = walk(BUILD).filter((f) => statSync(f).size > MAX_BYTES);
if (tooBig.length) throw new Error(`Files over 25 MiB: ${tooBig.join(", ")}`);
console.log("All files are under Cloudflare's 25 MiB limit.");
