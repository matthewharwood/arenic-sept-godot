import http from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import path from 'node:path';

const root = path.resolve(process.env.ARENIC_WEB_ROOT ?? '.tmp/site-qa');
const basePath = `/${(process.env.ARENIC_WEB_BASE_PATH ?? 'arenic-sept-godot').replace(/^\/+|\/+$/g, '')}/`;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon' };
const server = http.createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    if (!pathname.startsWith(basePath)) throw new Error('Use the repository Pages prefix');
    let file = path.resolve(root, pathname.slice(basePath.length));
    if (file !== root && !file.startsWith(root + path.sep)) throw new Error('Outside static root');
    if ((await stat(file)).isDirectory()) file = path.join(file, 'index.html');
    const info = await stat(file);
    if (!info.isFile()) throw new Error('Not a file');
    response.writeHead(200, { 'Content-Type': types[path.extname(file)] ?? 'application/octet-stream', 'Content-Length': info.size, 'Cache-Control': 'no-store' });
    if (request.method === 'HEAD') return response.end();
    createReadStream(file).pipe(response);
  } catch { response.writeHead(404); response.end('Not found'); }
});
server.listen(Number(process.env.ARENIC_WEB_PORT ?? 4174), '127.0.0.1');
