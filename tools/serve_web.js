// Serves the built Flutter web app for local development.
// Node, rather than `python3 -m http.server`, because the app launcher starts
// servers in a directory Python can't read, which breaks it before it starts.
import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const root = new URL('../neighborhand/build/web/', import.meta.url).pathname;
const port = Number(process.env.PORT) || 8000;

const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.css': 'text/css', '.json': 'application/json', '.wasm': 'application/wasm',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon', '.otf': 'font/otf', '.ttf': 'font/ttf', '.woff2': 'font/woff2',
};

createServer(async (req, res) => {
  const requested = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  let file = join(root, normalize(requested).replace(/^(\.\.[/\\])+/, ''));
  try {
    if ((await stat(file)).isDirectory()) file = join(file, 'index.html');
  } catch {
    file = join(root, 'index.html'); // single-page app: unknown paths load the app
  }
  res.writeHead(200, {
    'Content-Type': types[extname(file)] ?? 'application/octet-stream',
    'Cache-Control': 'no-cache',
  });
  createReadStream(file).on('error', () => res.end()).pipe(res);
}).listen(port, '127.0.0.1', () => console.log(`Serving ${root} on http://localhost:${port}`));
