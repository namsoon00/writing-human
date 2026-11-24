// Build with: flutter build web -t tool/writing_audio_probe.dart --output build/writing-audio-probe
// Run with Node 22+: node tool/check_writing_audio_probe.mjs [build directory] [report directory]
import {createServer} from 'node:http';
import {readFile, writeFile, mkdir, mkdtemp, rm} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join, resolve, sep, extname} from 'node:path';
const root = resolve(process.argv[2] ?? 'build/writing-audio-probe');
const out = resolve(process.argv[3] ?? 'output/writing-audio-probe');
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
const profile = await mkdtemp(join(tmpdir(),'writing-app-pencil-timing-browser-'));
const state = {path:profile,purpose:'real Dart PaperSound timing and output probe',status:'running'};
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
  const instrumentation = `
    window.audioProbe={starts:[],stops:[],contexts:[]};
    const Base=window.AudioContext;
    window.AudioContext=class extends Base {
      constructor(...args){super(...args);window.audioProbe.contexts.push(this);}
      decodeAudioData(...args){return super.decodeAudioData(...args).then(b=>{this.probeDecoded=true;return b;});}
      createBufferSource(){const node=super.createBufferSource(),context=this,start=node.start,stop=node.stop;
        node.start=function(...args){window.audioProbe.starts.push({wall:performance.now(),audio:context.currentTime,offset:args[1]??0});return start.apply(this,args);};
        node.stop=function(...args){window.audioProbe.stops.push({wall:performance.now(),audio:context.currentTime});return stop.apply(this,args);};return node;
      }
    };
  `;
  await send('Page.navigate',{url:`http://127.0.0.1:${server.address().port}/`});
  for(let i=0;i<300;i++){if(await evaluate('!!window.pencilReady'))break;if(i===299)throw Error('Fixture did not load');await wait(100);}
  await evaluate(instrumentation + ';true');
  // Real browser input unlocks the production isTrusted activation listener.
  await send('Input.dispatchKeyEvent',{type:'keyDown',key:'a',code:'KeyA',windowsVirtualKeyCode:65,text:'a'});
  await send('Input.dispatchKeyEvent',{type:'keyUp',key:'a',code:'KeyA',windowsVirtualKeyCode:65});
  for(let i=0;i<100;i++){if(await evaluate('audioProbe.contexts[0]?.probeDecoded && audioProbe.contexts[0].state==="running"'))break;if(i===99)throw Error('Audio did not unlock/decode');await wait(100);}
  const pulse=()=>evaluate('window.pencilPulse();true');
  await pulse();await wait(350);
  let trace=await evaluate('({starts:audioProbe.starts,stops:audioProbe.stops})');
  if(trace.starts.length!==1||trace.stops.length!==1)throw Error('Single input did not stop: '+JSON.stringify(trace));
  const singleMs=trace.stops[0].wall-trace.starts[0].wall;
  if(singleMs>320||Math.abs(trace.starts[0].offset-.6)>.001)throw Error('Single gesture too long or quiet lead-in repeated');
  await pulse();await wait(350);trace=await evaluate('({starts:audioProbe.starts,stops:audioProbe.stops})');
  if(trace.starts.length!==2||trace.stops.length!==2||trace.starts[1].offset<=trace.starts[0].offset+.08)throw Error('Resume trace: '+JSON.stringify(trace)+' context='+await evaluate('({state:audioProbe.contexts[0].state,time:audioProbe.contexts[0].currentTime})'));
  await pulse();await wait(70);await pulse();await wait(70);await pulse();await wait(350);
  trace=await evaluate('({starts:audioProbe.starts,stops:audioProbe.stops})');
  if(trace.starts.length!==3||trace.stops.length!==3)throw Error('Fast input multiplied sources');
  await pulse();await wait(140);await pulse();await wait(350);
  trace=await evaluate('({starts:audioProbe.starts,stops:audioProbe.stops})');
  if(trace.starts.length!==4||trace.stops.length!==4)throw Error('Fade cancellation restarted or leaked a source');
  await pulse();await wait(25);await evaluate('window.pencilClose()');await pulse();await wait(250);
  const final=await evaluate('({starts:audioProbe.starts,stops:audioProbe.stops,context:audioProbe.contexts[0].state})');
  if(final.starts.length!==5||final.context!=='closed')throw Error('Exit allowed a late replay');
  const result={single_input_ms:singleMs,single_input_upper_bound_ms:320,initial_offset_seconds:final.starts[0].offset,resumed_offset_seconds:final.starts[1].offset,fast_inputs:3,fast_input_sources:1,fade_resume_sources:1,starts:final.starts,stops:final.stops,after_close:final.context,scope:'Actual compiled Dart controller and web output with a trusted CDP key event. Not production app UI or physical-device listening.'};
  await writeFile(join(out,'browser-timing-verification.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
} finally {await cleanup();process.removeListener('SIGINT',cancel);process.removeListener('SIGTERM',cancel);}
