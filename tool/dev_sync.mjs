// Loopback-only preview. Production identity is exclusively Sites-owned.
import {createServer} from 'node:http';
import {spawn} from 'node:child_process';
const port = Number(process.env.WRITING_HUMAN_PREVIEW_PORT ?? 4173);
const workerPort = Number(process.env.WRITING_HUMAN_WORKER_PORT ?? 8787);
const localOrigin = `http://127.0.0.1:${port}`;
const target = `http://127.0.0.1:${workerPort}`;
const child = spawn(process.execPath, ['node_modules/wrangler/bin/wrangler.js', 'dev', '--local', '--config', 'wrangler.jsonc', '--ip', '127.0.0.1', '--port', String(workerPort), '--inspector-port', '0'], {stdio: 'inherit'});
let stopping = false;
const server = createServer(async (req, res) => {
  if (req.headers.host !== `127.0.0.1:${port}` || !['127.0.0.1','::ffff:127.0.0.1'].includes(req.socket.remoteAddress)) { res.writeHead(403).end(); return; }
  const url = new URL(req.url, localOrigin);
  if (url.pathname === '/signin-with-chatgpt' || url.pathname === '/signout-with-chatgpt') {
    if (req.method !== 'GET' || (req.headers.origin && req.headers.origin !== localOrigin)) { res.writeHead(403).end(); return; }
    const account = url.pathname === '/signout-with-chatgpt' ? '' : url.searchParams.get('account') === 'other' ? 'local-other' : 'local-writer';
    res.writeHead(302, {'set-cookie': `__writing_human_local_auth=${account}; Path=/; HttpOnly; SameSite=Lax${account ? '' : '; Max-Age=0'}`, 'location': '/', 'cache-control': 'no-store'}).end(); return;
  }
  if (req.headers.origin && req.headers.origin !== localOrigin) { res.writeHead(403).end(); return; }
  try {
    const headers = new Headers();
    for (const [k,v] of Object.entries(req.headers)) {
      if (k.startsWith('oai-authenticated-user-') || ['host','cookie','connection','content-length','origin'].includes(k)) continue;
      if (typeof v === 'string') headers.set(k,v);
    }
    const cookie = req.headers.cookie?.split(';').map(c=>c.trim()).find(c=>c.startsWith('__writing_human_local_auth='))?.split('=')[1];
    if (cookie === 'local-writer' || cookie === 'local-other') {
      headers.set('oai-authenticated-user-id',cookie);
      headers.set('oai-authenticated-user-email',`${cookie}@sites.test`);
    }
    if (req.headers.origin) headers.set('origin',target);
    const response = await fetch(target + url.pathname + url.search, {method: req.method, headers, ...(['GET','HEAD'].includes(req.method) ? {} : {body: req, duplex: 'half'}), redirect:'manual'});
    const outgoing = Object.fromEntries(response.headers);
    delete outgoing['content-encoding']; delete outgoing['content-length']; delete outgoing['transfer-encoding'];
    res.writeHead(response.status,outgoing); res.end(Buffer.from(await response.arrayBuffer()));
  } catch (_) { res.writeHead(503,{'content-type':'text/plain'}).end('Local sync worker is starting.'); }
});
server.listen(port,'127.0.0.1',()=>console.log(`Local: ${localOrigin} (preview identity only; production uses Sites sign-in)`));
function stop() { if (stopping) return; stopping=true; child.kill('SIGTERM'); server.close(()=>process.exit(0)); }
process.on('SIGINT',stop); process.on('SIGTERM',stop);
child.on('exit',code=>{ if (!stopping) { server.close(); process.exit(code ?? 1); } });
