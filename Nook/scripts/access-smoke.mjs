import {BoardHistory} from '../priv/static/assets/history.mjs';
import {prepareOperation,wireOperation} from '../priv/static/assets/collaboration-model.mjs';
// Real HTTP sessions and encrypted, short-lived Phoenix Socket credentials.
import assert from 'node:assert/strict';
import {Socket} from '../priv/static/assets/phoenix.mjs';
const base = 'http://127.0.0.1:4000';
class BrowserSession {
  cookies = new Map(); csrf = '';
  async request(path, method = 'GET', body) {
    const headers = {cookie: [...this.cookies].map(([k,v]) => `${k}=${v}`).join('; ')};
    if (method !== 'GET') Object.assign(headers, {'content-type':'application/json','x-csrf-token':this.csrf});
    const response = await fetch(base + path, {method, headers, redirect:'manual', ...(body ? {body:JSON.stringify(body)} : {})});
    for (const cookie of response.headers.getSetCookie()) {
      const [name,value] = cookie.split(';')[0].split('='); this.cookies.set(name,value);
    }
    return response;
  }
  async init() {
    const html = await (await this.request('/')).text();
    this.csrf = html.match(/name="csrf-token" content="([^"]+)"/)[1];
  }
  async json(path, method='GET', body) {
    const r = await this.request(path,method,body); assert.equal(r.status,200, `${method} ${path}`); return r.json();
  }
}
const waitPush = p => new Promise((resolve,reject) => p.receive('ok',resolve).receive('error',reject).receive('timeout',()=>reject(Error('Push timeout'))));
async function within(promise) {
  let timer; try {return await Promise.race([promise,new Promise((_,reject)=>timer=setTimeout(()=>reject(Error('Event timeout')),5000))]);} finally {clearTimeout(timer);}
}
const sockets=[];
async function connect(session) {
  const {token} = await session.json('/api/socket-token');
  const socket = new Socket(`${base}/socket`,{transport:WebSocket,params:{socket_token:token}});
  sockets.push(socket); socket.connect(); return socket;
}
try {
  const owner=new BrowserSession(), guest=new BrowserSession(); await Promise.all([owner.init(),guest.init()]);
  const forged=await fetch(`${base}/api/boards`,{method:'POST',headers:{'content-type':'application/json'},body:'{}'});
  assert.equal(forged.status,403,'CSRF-less writes must be rejected');
  const board=await owner.json('/api/boards','POST',{});
  assert.equal(board.kind,'guest'); assert.ok(board.expires_at);
  assert.equal((await guest.request(`/api/boards/${board.code}`)).status,404,'Room code alone must not grant access');
  const outsider=await connect(guest);
  await assert.rejects(waitPush(outsider.channel(`board:${board.code}`).join())); outsider.disconnect();
  const {path}=await owner.json(`/api/boards/${board.code}/invitations`,'POST',{});
  const redemption=await guest.request(path); assert.equal(redemption.headers.get('location'),`/b/${board.code}`);
  const ownerSocket=await connect(owner), guestSocket=await connect(guest);
  const a=ownerSocket.channel(`board:${board.code}`), b=guestSocket.channel(`board:${board.code}`);
  await Promise.all([waitPush(a.join()),waitPush(b.join())]);
  const received=new Promise(resolve=>b.on('operation',resolve));
  const element={id:'access-smoke-note',type:'note',x:40,y:50,w:230,h:200,text:'Two authorized clients, one Nook',color:'lilac'};
  await waitPush(a.push('operation',{type:'put',element,op_id:'smoke-put-once'})); assert.equal((await within(received)).op.element.text,element.text);
  await waitPush(b.push('operation',{type:'patch',id:element.id,base_revision:1,base:{x:40},changes:{x:175}}));
  const saved=await guest.json(`/api/boards/${board.code}`); assert.equal(saved.elements[element.id].x,175);
  // A stale independent text change merges, but a competing position must stop.
  await waitPush(a.push('operation',{type:'patch',id:element.id,base_revision:1,base:{text:element.text},changes:{text:'Merged text'}}));
  await assert.rejects(waitPush(a.push('operation',{type:'patch',id:element.id,base_revision:1,base:{x:40},changes:{x:999}})),e=>e.reason==='conflict'&&e.snapshot.elements[element.id].x===175);
  // A fresh connection sees canonical versions and a lost-ACK replay cannot restore stale text.
  const resumedSocket=await connect(guest),resumed=resumedSocket.channel(`board:${board.code}`);
  const resumedBoard=await waitPush(resumed.join());assert.equal(resumedBoard.elements[element.id].revision,3);
  const replay=await waitPush(resumed.push('operation',{type:'put',element,op_id:'smoke-put-once'}));
  assert.equal(replay.snapshot.elements[element.id].text,'Merged text');assert.equal(replay.revision,3);
  const races=await Promise.allSettled([
    waitPush(a.push('operation',{type:'patch',id:element.id,base_revision:3,base:{text:'Merged text'},changes:{text:'Alice'}})),
    waitPush(resumed.push('operation',{type:'patch',id:element.id,base_revision:3,base:{text:'Merged text'},changes:{text:'Bob'}}))
  ]);
  assert.equal(races.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(races.find(r=>r.status==='rejected').reason.reason,'conflict');
  // Atomic diagram operations and ephemeral cursors share the authorized channel.
  const diagram=[
    {id:'advanced-a',type:'note',x:10,y:20,w:120,h:80,text:'Launch',color:'white',font_size:32,auto_width:true},
    {id:'advanced-b',type:'shape',shape:'circle',x:300,y:20,w:180,h:180,text:'Together'},
    {id:'advanced-task',type:'task',x:500,y:20,w:320,h:220,text:'Plan',items:[{id:'step-one',text:'Sketch',done:true},{id:'step-two',text:'Build',done:false}]},
    {id:'advanced-edge',type:'connection',x:0,y:0,from:'advanced-a',to:'advanced-b'}
  ];
  const batchReceived=new Promise(resolve=>b.on('operation',p=>{if(p.op.type==='batch')resolve(p);}));
  const created=await waitPush(a.push('operation',{type:'batch',op_id:'advanced-create',ops:diagram.map(element=>({type:'put',element}))}));
  assert.equal((await within(batchReceived)).op.ops.length,4);
  const moved=await waitPush(a.push('operation',{type:'batch',op_id:'advanced-group',ops:['advanced-a','advanced-b'].map(id=>({type:'patch',id,base_revision:1,changes:{x:created.snapshot.elements[id].x+50,group_id:'diagram-group'}}))}));
  assert.equal(moved.snapshot.elements['advanced-a'].x,60);assert.equal(moved.snapshot.elements['advanced-b'].group_id,'diagram-group');
  assert.equal(moved.snapshot.elements['advanced-task'].items[0].done,true);
  const previewReceived=new Promise(resolve=>b.on('previews',resolve));a.push('previews',{elements:[{id:'advanced-a',changes:{x:99,y:50}},{id:'advanced-b',changes:{x:450,y:50}}]});assert.equal((await within(previewReceived)).elements.length,2);assert.equal((await owner.json(`/api/boards/${board.code}`)).elements['advanced-a'].x,60);
  // Drawing previews stay transient; a finished stroke is one persisted operation.
  const drawPreview=new Promise(resolve=>b.on('drawing',resolve));
  a.push('drawing',{visible:true,color:'#ad7bfa',width:5,points:[[10,20],[50,80]],id:'forged'});
  const drawingPreview=await within(drawPreview);assert.notEqual(drawingPreview.id,'forged');assert.equal(drawingPreview.points.length,2);
  a.push('drawing',{visible:false});
  const ink={id:'smoke-stroke',type:'stroke',x:10,y:20,w:100,h:100,text:'',color:'#ad7bfa',stroke_width:5,points:[[.1,.2],[.5,.8]]};
  const inkReceived=new Promise(resolve=>b.on('operation',p=>{if(p.op.element?.id===ink.id)resolve(p);}));
  await waitPush(a.push('operation',{type:'put',element:ink}));assert.deepEqual((await within(inkReceived)).op.element.points,ink.points);
  assert.deepEqual((await owner.json(`/api/boards/${board.code}`)).elements[ink.id].points,ink.points);
  const cleanedInk=new Promise(resolve=>b.on('operation',p=>{if(p.op.id===ink.id&&p.op.changes?.linear)resolve(p);}));
  await waitPush(a.push('operation',{type:'patch',id:ink.id,base_revision:1,changes:{points:[[.1,.2],[.7,.8]],linear:true}}));
  assert.equal((await within(cleanedInk)).op.changes.linear,true);
  await waitPush(a.push('operation',{type:'patch',id:ink.id,base_revision:2,changes:{points:ink.points,linear:false}}));
  assert.deepEqual((await owner.json(`/api/boards/${board.code}`)).elements[ink.id].points,ink.points);
  await waitPush(a.push('operation',{type:'delete',id:ink.id,base_revision:3}));
  const cursorReceived=new Promise(resolve=>b.on('cursor',resolve));
  a.push('cursor',{visible:true,x:123,y:-90,name:'Forged identity'});
  const cursor=await within(cursorReceived);assert.equal(cursor.x,123);assert.notEqual(cursor.name,'Forged identity');assert.ok(cursor.id);
  const hiddenCursor=new Promise(resolve=>b.on('cursor',p=>{if(!p.visible)resolve(p);}));a.push('cursor',{visible:false});await within(hiddenCursor);
  // A disconnected client resumes from a fresh snapshot and safely replays an independent offline edit.
  const droppedSocket=await connect(guest), dropped=droppedSocket.channel(`board:${board.code}`);
  const beforeDrop=await waitPush(dropped.join()); droppedSocket.disconnect();
  const offlineBase=beforeDrop.elements['advanced-a'];
  await waitPush(a.push('operation',{type:'patch',id:'advanced-a',base_revision:offlineBase.revision,base:{font_size:offlineBase.font_size},changes:{font_size:30}}));
  const recoveredSocket=await connect(guest), recovered=recoveredSocket.channel(`board:${board.code}`);
  const recoveredState=await waitPush(recovered.join());assert.equal(recoveredState.elements['advanced-a'].font_size,30);
  const offlineEdit={type:'patch',id:'advanced-a',op_id:'milestone-six-offline',base_revision:offlineBase.revision,base:{y:offlineBase.y},changes:{y:85}};
  const recoveredEdit=await waitPush(recovered.push('operation',offlineEdit));
  assert.equal(recoveredEdit.snapshot.elements['advanced-a'].y,85);assert.equal(recoveredEdit.snapshot.elements['advanced-a'].font_size,30);
  const retriedEdit=await waitPush(recovered.push('operation',offlineEdit));assert.equal(retriedEdit.revision,recoveredEdit.revision);
  // Four additional isolated visitors receive the same atomic board revision, then edit independently.
  const crowd=[];
  for(let i=0;i<4;i++){
    const visitor=new BrowserSession();await visitor.init();await visitor.request(path);
    const connection=await connect(visitor),room=connection.channel(`board:${board.code}`,{name:`Load visitor ${i+1}`});await waitPush(room.join());crowd.push(room);
  }
  const fanout=crowd.map(room=>within(new Promise(resolve=>room.on('operation',payload=>{if(payload.op.op_id==='milestone-six-fanout')resolve(payload);}))));
  const stressElements=Array.from({length:40},(_,i)=>({id:`m6-load-${i}`,type:'note',x:i*20,y:600,w:180,h:100,text:`Shared item ${i}`}));
  const broadcast=await waitPush(a.push('operation',{type:'batch',op_id:'milestone-six-fanout',ops:stressElements.map(element=>({type:'put',element}))}));
  for(const event of await Promise.all(fanout))assert.equal(event.revision,broadcast.revision);
  await Promise.all(crowd.map((room,i)=>waitPush(room.push('operation',{type:'patch',id:`m6-load-${i}`,base_revision:1,changes:{text:`Visitor ${i+1} edit`}}))));
  const crowdSaved=await owner.json(`/api/boards/${board.code}`);
  for(let i=0;i<4;i++)assert.equal(crowdSaved.elements[`m6-load-${i}`].text,`Visitor ${i+1} edit`);
  // Visit-local Undo/Redo plans also pass real server revision and atomicity checks.
  const history=new BoardHistory(), historyItems=[
    {id:'m7-a',type:'note',x:50,y:800,w:180,h:100,text:'Original'},
    {id:'m7-b',type:'shape',shape:'rectangle',x:350,y:800,w:180,h:100,text:'Fixed shape'},
    {id:'m7-edge',type:'connection',x:0,y:0,from:'m7-a',to:'m7-b'}
  ];
  const initialHistory=(await waitPush(a.push('operation',{type:'batch',ops:historyItems.map(element=>({type:'put',element}))}))).snapshot;
  const movedHistory=(await waitPush(a.push('operation',{type:'batch',ops:['m7-a','m7-b'].map(id=>({type:'patch',id,base_revision:1,changes:{x:initialHistory.elements[id].x+60,group_id:'m7-group'}}))}))).snapshot;
  history.record(initialHistory,movedHistory,'move selection');
  await waitPush(b.push('operation',{type:'patch',id:'m7-a',base_revision:2,changes:{text:'Collaborator words'}}));
  async function useHistory(direction){const current=await owner.json(`/api/boards/${board.code}`),plan=history.plan(current,direction);assert.equal(plan.error,undefined);const result=await waitPush(a.push('operation',{type:'batch',ops:plan.ops.map(op=>wireOperation(prepareOperation(op,current.elements[op.id||op.element?.id])))}));history.accept(direction,plan);return result.snapshot;}
  const undoneMove=await useHistory('undo');assert.equal(undoneMove.elements['m7-a'].x,50);assert.equal(undoneMove.elements['m7-a'].text,'Collaborator words');
  const redoneMove=await useHistory('redo');assert.equal(redoneMove.elements['m7-b'].x,410);
  const deletedHistory=(await waitPush(a.push('operation',{type:'delete',id:'m7-a',base_revision:redoneMove.elements['m7-a'].revision}))).snapshot;
  history.record(redoneMove,deletedHistory,'delete item');
  const restoredHistory=await useHistory('undo');assert.equal(restoredHistory.elements['m7-edge'].to,'m7-b');
  const reDeleted=await useHistory('redo');assert.equal(reDeleted.elements['m7-a'],undefined);assert.equal(reDeleted.elements['m7-edge'],undefined);
  // New visual metadata travels through the real channel and persists in JSONB.
  const symbol={id:'visual-symbol',type:'icon',icon:'lightbulb',text:'',color:'#ad7bfa',x:20,y:1200,w:80,h:80};
  await waitPush(a.push('operation',{type:'put',element:symbol}));
  const symbolEvent=within(new Promise(resolve=>b.on('operation',payload=>{if(payload.op.op_id==='visual-update')resolve(payload);} )));
  await waitPush(a.push('operation',{type:'patch',op_id:'visual-update',id:symbol.id,base_revision:1,changes:{icon:'document',color:'#123456',locked:true}}));
  const visualBroadcast=await symbolEvent;assert.equal(visualBroadcast.op.changes.locked,true);
  const visualSaved=(await owner.json(`/api/boards/${board.code}`)).elements[symbol.id];
  assert.equal(visualSaved.icon,'document');assert.equal(visualSaved.color,'#123456');assert.equal(visualSaved.locked,true);
  // Owner-approved code admission uses a third isolated browser identity.
  const requester=new BrowserSession();await requester.init();
  assert.equal((await requester.request('/api/room-requests','POST',{code:board.code,name:'Sam'})).status,404);
  await owner.json(`/api/boards/${board.code}/requests/open`,'POST',{open:true});
  const request=await requester.json('/api/room-requests','POST',{code:board.code,name:'Sam'});
  assert.equal(request.status,'pending');assert.equal(request.title,undefined);
  assert.equal((await requester.request(`/api/boards/${board.code}`)).status,404);
  assert.equal((await guest.request(`/api/room-requests/${request.id}`)).status,404);
  await owner.json(`/api/boards/${board.code}/requests/${request.id}`,'POST',{decision:'approved'});
  assert.equal((await requester.json(`/api/room-requests/${request.id}`)).status,'approved');
  const third=await connect(requester),c=third.channel(`board:${board.code}`,{name:'Sam'});
  const presence=new Promise(resolve=>c.on('presence_state',resolve));
  const joined=await waitPush(c.join());assert.equal(joined.self.name,'Sam');assert.equal(joined.self.role,'Editor');
  const people=await within(presence);assert.ok(Object.values(people).some(p=>p.metas.some(m=>m.name==='Sam'&&m.role==='Editor')));
  await waitPush(c.push('set_name',{name:'Sam renamed'}));
  // Same session in another tab is represented by one person with two metas.
  const twinSocket=await connect(requester),twin=twinSocket.channel(`board:${board.code}`,{name:'Sam renamed'});
  const twinPresence=new Promise(resolve=>twin.on('presence_state',resolve));await waitPush(twin.join());
  assert.equal((await within(twinPresence))[joined.self.id].metas.length,2);
  const thirdLost=new Promise(resolve=>c.on('access_lost',resolve));
  const lost=new Promise(resolve=>b.on('access_lost',resolve));
  await owner.json(`/api/boards/${board.code}/invitations`,'DELETE'); await within(lost);await within(thirdLost);
  assert.equal((await guest.request(`/api/boards/${board.code}`)).status,404);
  assert.equal((await guest.request(path)).headers.get('location'),'/');
  assert.equal((await owner.json(`/api/boards/${board.code}`)).elements[element.id].x,175);
  assert.equal((await requester.request(`/api/boards/${board.code}`)).status,404);
  console.log('PASS: icons, custom colors and locks broadcast and persist; server-verified Undo/Redo with collaborator preservation and connection restoration; disconnect/rejoin offline recovery, idempotent replay, four-visitor atomic fanout and concurrent independent editing; atomic diagrams/groups/checklists, authenticated live cursors, room approvals, grouped named Presence, stale-edit merge/conflict checks, simultaneous competing writes, reconnect replay recovery, real browser sessions, CSRF protection, code-only denial, secure invitations, two-client editing, persisted state and immediate live revocation');
} finally { sockets.forEach(socket=>socket.disconnect()); }
