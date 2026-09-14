// node tests/web/prepare-probe.mjs --source arenic-game --destination .tmp/web-probe-project
// Only creates an isolated project. The clean production export never imports this autoload.
import { cp, mkdir, readFile, writeFile, access } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const option = name => args[args.indexOf(name) + 1];
if (!args.includes('--source') || !args.includes('--destination')) throw new Error('Specify --source and --destination');
const source = path.resolve(option('--source'));
const destination = path.resolve(option('--destination'));
if (source === destination || destination.startsWith(source + path.sep)) throw new Error('Probe destination must be outside the source project');
try { await access(destination); throw new Error('Probe destination already exists; choose a fresh isolated directory'); }
catch (error) { if (error.code !== 'ENOENT') throw error; }
await cp(source, destination, { recursive: true, filter: entry => !path.relative(source, entry).split(path.sep).some(part => ['.godot', '.git', '.mcp.json'].includes(part)) });
let project = await readFile(path.join(destination, 'project.godot'), 'utf8');
if (!project.includes('[autoload]')) throw new Error('Expected existing autoload section');
project = project.replace('[autoload]', '[autoload]\n\nWebCIProbe="*res://__ci__/web_probe.gd"');
await mkdir(path.join(destination, '__ci__'), { recursive: true });
await cp(fileURLToPath(new URL('./probe.gd', import.meta.url)), path.join(destination, '__ci__/web_probe.gd'));
await cp(fileURLToPath(new URL('./prepare-fixtures.gd', import.meta.url)), path.join(destination, '__ci__/prepare_fixtures.gd'));
await writeFile(path.join(destination, 'project.godot'), project);
console.log(JSON.stringify({ source, destination, probe: 'res://__ci__/web_probe.gd', productionModified: false }));
