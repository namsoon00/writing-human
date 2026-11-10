import test from 'node:test';
import assert from 'node:assert/strict';
const base = process.env.WRITING_HUMAN_TEST_ORIGIN ?? 'http://127.0.0.1:4173';
if (!['127.0.0.1','localhost'].includes(new URL(base).hostname)) throw new Error('Synthetic fixtures may only be sent to loopback preview.');
const call = (cookie, method='GET', body) => fetch(base+'/api/sync/library', {method, headers: {'Cookie':cookie,'Origin':base,'Content-Type':'application/json','X-Writing-Human-Sync':'1','X-Writing-Human-Account':cookie.includes('local-other')?'local-other':'local-writer'}, ...(body ? {body:JSON.stringify(body)} : {})});

test('Real local Worker/D1: independent HTTP sessions sync, stale write is rejected, accounts are isolated', async()=>{
  const root = await fetch(base+'/'); assert.equal(root.status,200); assert.match(await root.text(),/flutter_bootstrap/);
  const login = await fetch(base+'/signin-with-chatgpt', {redirect:'manual'});
  assert.equal(login.status,302);
  const cookie = login.headers.get('set-cookie').split(';')[0];
  const session = await (await fetch(base+'/api/sync/session',{headers:{Cookie:cookie}})).json();
  assert.equal(session.userId,'local-writer');
  const initial = await (await call(cookie)).json();
  const library = initial.library ?? {version:1,books:[],records:[],pages:[],activePageId:null,writing:false,style:{paperIndex:0,penIndex:0,fontIndex:1,guides:false,favoriteBookIds:[]}};
  const id = 'qa-'+crypto.randomUUID(), r=id+'-record', p=id+'-page';
  library.books.push({id,title:'HTTP 동기화 검증',author:'로컬 테스트'});
  library.records.push({id:r,bookId:id,title:'필사 1',source:'합성 검증 문장'});
  library.pages.push({id:p,recordId:r,number:1,text:'PC에서 쓴 문장을 모바일 세션에서 읽습니다.',base:2,extent:5,scroll:33});
  library.activePageId=p; library.writing=true;
  const accepted=await call(cookie,'PUT',{baseRevision:initial.revision,library});
  assert.equal(accepted.status,200);
  const cloud=await accepted.json();
  // Independent request/session with the same test identity.
  const mobile=await (await call(cookie)).json();
  assert.equal(mobile.library.pages.find(v=>v.id===p).text,library.pages.at(-1).text);
  assert.equal(mobile.library.pages.find(v=>v.id===p).extent,5);
  const stale=await call(cookie,'PUT',{baseRevision:initial.revision,library});
  assert.equal(stale.status,409);
  assert.equal((await stale.json()).revision,cloud.revision);
  const otherLogin=await fetch(base+'/signin-with-chatgpt?account=other',{redirect:'manual'});
  const otherCookie=otherLogin.headers.get('set-cookie').split(';')[0];
  const other=await (await call(otherCookie)).json();
  assert.equal(other.library?.books.some(v=>v.id===id) ?? false,false);
  const spoof=await fetch(base+'/api/sync/library',{headers:{'oai-authenticated-user-id':'local-writer'}});
  assert.equal(spoof.status,401);
  const evil=await fetch(base+'/api/sync/library',{method:'PUT',headers:{Cookie:cookie,Origin:'https://evil.test','Content-Type':'application/json','X-Writing-Human-Sync':'1'},body:JSON.stringify({baseRevision:cloud.revision,library})});
  assert.equal(evil.status,403);
});
