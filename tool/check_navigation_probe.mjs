// Build: flutter build web -t tool/navigation_probe.dart --output build/navigation-probe
// Run with Node 22+: node tool/check_navigation_probe.mjs [build directory] [report directory]
import {createServer} from 'node:http';
import {readFile, writeFile, mkdir, mkdtemp, rm} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join, resolve, sep, extname} from 'node:path';
const root = resolve(process.argv[2] ?? 'build/navigation-probe');
const out = resolve(process.argv[3] ?? 'output/navigation-implementation-20261125');
await mkdir(out, {recursive: true});
const mime = {'.js':'text/javascript','.mjs':'text/javascript','.wasm':'application/wasm','.html':'text/html','.json':'application/json','.wav':'audio/wav','.ttf':'font/ttf'};
const server = createServer(async (req,res) => {
  const path = new URL(req.url,'http://localhost').pathname;
  const file = resolve(root, '.' + (path === '/' ? '/index.html' : path));
  if (!file.startsWith(root + sep)) {res.writeHead(403).end();return;}
  try {res.setHeader('Content-Type',mime[extname(file)]??'application/octet-stream');res.end(await readFile(file));}
  catch {res.writeHead(404).end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const profile = await mkdtemp(join(tmpdir(),'writing-app-navigation-browser-'));
const state = {path:profile,purpose:'actual Flutter navigation and browser history with synthetic records',status:'running'};
await writeFile(join(out,'browser-workspace.json'),JSON.stringify(state,null,2)+'\n');
let child, ws, cleaned = false;
async function cleanup() {
  if(cleaned)return;cleaned=true;
  ws?.close();
  if(child && child.exitCode===null){child.kill('SIGTERM');await new Promise(r=>{child.once('exit',r);setTimeout(r,2000);});}
  server.close();await rm(profile,{recursive:true,force:true,maxRetries:5,retryDelay:100});
  state.status='cleaned';await writeFile(join(out,'browser-workspace.json'),JSON.stringify(state,null,2)+'\n');
}
const cancel=()=>{cleanup().finally(()=>process.exit(1));};
process.once('SIGINT',cancel);process.once('SIGTERM',cancel);
const wait=ms=>new Promise(r=>setTimeout(r,ms));
try {
  let stderr='', readyResolve, readyReject;
  const ready=new Promise((a,b)=>{readyResolve=a;readyReject=b;});
  const chrome=process.env.CHROME_EXECUTABLE??(process.platform==='darwin'?'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome':'google-chrome');
  child=spawn(chrome,['--headless','--no-sandbox','--disable-gpu',`--user-data-dir=${profile}`,'--remote-debugging-port=0','about:blank']);
  child.stderr.on('data',x=>{stderr+=x;const m=stderr.match(/DevTools listening on ws:\/\/127\.0\.0\.1:(\d+)\//);if(m)readyResolve(Number(m[1]));});child.on('error',readyReject);
  const timeout=setTimeout(()=>readyReject(Error('Chrome startup timed out')),15000);const port=await ready;clearTimeout(timeout);
  const targets=await(await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  ws=new WebSocket(targets.find(x=>x.type==='page').webSocketDebuggerUrl);await new Promise((a,b)=>{ws.onopen=a;ws.onerror=b;});
  let serial=0;const pending=new Map();
  ws.onmessage=({data})=>{const x=JSON.parse(data);if(x.id){pending.get(x.id)?.(x);pending.delete(x.id);}};
  const send=(method,params={})=>new Promise(r=>{const id=++serial;pending.set(id,r);ws.send(JSON.stringify({id,method,params}));});
  const evaluate=async expression=>{
    const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});
    if(r.result?.exceptionDetails)throw Error(JSON.stringify(r.result.exceptionDetails));return r.result?.result?.value;
  };

  await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});
  await send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/`});
  const all = `function nodes(root=document){let out=[...root.querySelectorAll('*')];for(const e of [...out])if(e.shadowRoot)out.push(...nodes(e.shadowRoot));return out;}`;
  const labels = ()=>evaluate(`(()=>{${all};return nodes().filter(e=>e.getAttribute('role')==='button').map(e=>e.getAttribute('aria-label')||e.textContent||'')})()`);
  async function until(predicate,description) {
    for(let i=0;i<300;i++){if(await predicate())return;await wait(100);}
    throw Error('Timed out: '+description+'; labels='+JSON.stringify(await labels()));
  }
  async function click(label,partial=false) {
    const point=await evaluate(`(()=>{${all};const label=${JSON.stringify(label)};const e=nodes().filter(e=>e.getAttribute('role')==='button').find(e=>{const s=(e.getAttribute('aria-label')||e.textContent||'').trim();const r=e.getBoundingClientRect();return ${partial?'s.includes(label)':'s===label'}&&r.width>0&&r.height>0&&r.y>=0&&r.bottom<=innerHeight+2});if(!e)return null;const r=e.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};})()`);
    if(!point)throw Error('Button absent: '+label+'; labels='+JSON.stringify(await labels()));
    await send('Input.dispatchMouseEvent',{type:'mousePressed',...point,button:'left',clickCount:1});
    await send('Input.dispatchMouseEvent',{type:'mouseReleased',...point,button:'left',clickCount:1});
    await wait(450);
  }
  await until(async()=>await evaluate('typeof navigationSnapshot === "function"')&&(await labels()).includes('책장'),'initial writing');
  await wait(500);
  const initial=JSON.parse(await evaluate('navigationSnapshot()'));
  const initialUrl=await evaluate('location.href');
  await click('책장');
  await click('살펴볼 책',true);
  await click('원문');
  await click('다른 책의 문장을 읽습니다.',true);
  let snapshot=JSON.parse(await evaluate('navigationSnapshot()'));
  if(snapshot.activePageId!=='pa')throw Error('Browsing changed writing');
  await send('Page.captureScreenshot',{format:'png'}).then(x=>writeFile(join(out,'browser-original.png'),Buffer.from(x.result.data,'base64')));
  // Exercise the browser's real history, not a direct call to Navigator.pop.
  await evaluate('history.back();true');
  await until(async()=>{const current=await labels();return !current.includes('필사하기')&&current.some(x=>x.includes('다른 책의 문장을 읽습니다.'));},'browser back to original list');
  await click('다른 책의 문장을 읽습니다.',true);
  await click('쓰던 쪽');
  await until(async()=>(await labels()).includes('쓰기 도구'),'one-step writing return');
  snapshot=JSON.parse(await evaluate('navigationSnapshot()'));
  if(snapshot.activePageId!=='pa'||JSON.stringify(snapshot.pages)!==JSON.stringify(initial.pages)||snapshot.records.length!==2)throw Error('Return changed writing/cursor/records');
  await click('쓰기 도구');
  await until(async()=>(await labels()).includes('아래로 내려 돌아가기'),'tool panel');
  await click('아래로 내려 돌아가기');
  await until(async()=>!(await labels()).includes('아래로 내려 돌아가기'),'panel return');
  const final=JSON.parse(await evaluate('navigationSnapshot()'));
  const finalUrl=await evaluate('location.href');
  if(JSON.stringify(final.pages)!==JSON.stringify(initial.pages)||final.activePageId!=='pa'||finalUrl!==initialUrl)throw Error('Panel changed paper or history URL');
  const result={scope:'Actual compiled Flutter app in headless Chrome, synthetic in-memory records. Real browser history.back and CDP pointer input. Not physical-device or disk verification.',browser_back:'detail to source list',origin_shortcut:'deep source to original writing',panel_return:'same writing',pages_and_cursor_unchanged:true,record_count:final.records.length,url_unchanged:true};
  await writeFile(join(out,'browser-navigation.json'),JSON.stringify(result,null,2)+'\n');
  await send('Page.captureScreenshot',{format:'png'}).then(x=>writeFile(join(out,'browser-returned-writing.png'),Buffer.from(x.result.data,'base64')));
  console.log(JSON.stringify(result));
} finally {await cleanup();process.removeListener('SIGINT',cancel);process.removeListener('SIGTERM',cancel);}
