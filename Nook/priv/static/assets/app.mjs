import {installStudioSettings} from './studio-settings.mjs?v=0.12.2';
import {openRecoveryStore} from './recovery-store.mjs?v=0.12.2';
import {BoardHistory,actionLabel,guardedHistoryPlan} from './history.mjs?v=0.12.2';
import {saveState,loadFailure} from './ui-state.mjs';
import {createCanvasUI} from './canvas-ui.mjs?v=0.12.2';
import {Socket, Presence} from './phoenix.mjs';
import {prepareOperation, optimisticBoard, wireOperation, resolveConflict, describeElement} from './collaboration-model.mjs';
import {uid, applyOperation} from './canvas-model.mjs';
export function mountNook(hook) {
const $ = s => hook.el.querySelector(s);
const lifecycle = new AbortController();
const listen = (target,type,handler) => target.addEventListener(type,handler,{signal:lifecycle.signal});
const icons = {
 text:'<path d="M5 5h22M16 5v23M11 28h10M5 5v4M27 5v4"/>',
 note:'<path d="M7 3h18a3 3 0 0 1 3 3v17l-6 6H7a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3Z"/><path d="M22 29v-6h6"/>',
 shape:'<rect x="3" y="3" width="19" height="19" rx="2"/><circle cx="22" cy="22" r="8"/>',
 task:'<rect x="4" y="3" width="24" height="26" rx="5"/><path d="m10 16 4 4 9-10"/>',
 connection:'<rect x="1" y="9" width="9" height="14" rx="2"/><rect x="23" y="9" width="9" height="14" rx="2"/><path d="M12 16h9m-4-4 4 4-4 4"/>',
 file:'<path d="M8 3h12l7 7v17a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Zm12 0v8h7M11 17h11M11 22h11"/>',
 idea:'<path d="M11 24h10m-9 4h8M11 24v-3a10 10 0 1 1 10 0v3M16 1v-1M4 5 2 3m26 2 2-2M1 15h-2m32 0h2"/>',
 room:'<circle cx="11" cy="8" r="5"/><circle cx="24" cy="8" r="5"/><path d="M1 27v-4a10 10 0 0 1 20 0v4Zm20 0h11v-4a9 9 0 0 0-10-9"/>'
};
icons.icon=icons.idea;
const tools = [['text','Text'],['note','Note'],['shape','Shapes'],['task','Task'],['connection','Connect'],['file','File'],['icon','Icons'],['room','Room']];
const toolDescriptions={text:'Write directly on the canvas',note:'Add a colored note',shape:'Add a shape or labeled diagram item',task:'Add a checklist',connection:'Link two items',file:'Add a file or image',icon:'Add a visual symbol (document icons are not uploaded files)',room:'See people and manage room access'};
$('#toolbar').innerHTML = tools.map(([key,label]) => `<button class="tool" data-tool="${key}" aria-label="${label}" aria-pressed="false" title="${label}: ${toolDescriptions[key]}"><svg viewBox="0 0 34 34" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[key]}</svg><span>${label}</span></button>`).join('');
const history=new BoardHistory(50);let replayingHistory=false,historyRequest=null;
let savedHistoryRevision=-1;let draftStore;
let serverBoard, conflict = false, admissionTimer;
let board,channel,socket,ui;

let pending = [], sending = false, ready = false, presence = {}, toastTimer,retrySaveAt=0,retrySaveTimer;
const canvas = $('#canvas'), elements = $('#elements');

function toast(message) { $('#toast').textContent = message; $('#toast').hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(() => $('#toast').hidden = true, 4200); }
function status() { for(const direction of ['undo','redo']){const button=$(`#${direction}`);button.disabled=!board||conflict||!history[direction].length;button.title=conflict?'Review the conflicting change first':history[direction].length?`${direction==='undo'?'Undo':'Redo'} ${history[direction].at(-1).label}`:`Nothing to ${direction}`;}saveHistory();if(historyRequest&&(!pending.length||!ready)&&!conflict){const request=historyRequest;historyRequest=null;queueMicrotask(()=>requestHistory(request));}const state=saveState({ready,pending:pending.length,editing:ui?.isEditing(),conflict});const label=$('#save-status');if(label.textContent!==state.text)label.textContent=state.text;label.dataset.state=state.kind;$('#connection-notice').hidden=ready||!board; if($('#claim-board'))$('#claim-board').disabled=pending.length>0; }
function saveHistory(){if(!board||!draftStore||savedHistoryRevision===history.revision)return;savedHistoryRevision=history.revision;try{Promise.resolve(draftStore.saveHistory(history.serialize())).catch(()=>historyNotice('Undo history could not be kept through refresh on this device. Your board still saves normally.'));}catch{historyNotice('Undo history could not be kept through refresh on this device. Your board still saves normally.');}}
function historyNotice(message){if($('#history-feedback').textContent!==message)$('#history-feedback').textContent=message;$('#history-notice').hidden=!message;}
function backup() { try { Promise.resolve(draftStore?.save(pending)).catch(()=>toast('Device backup is full. Keep this tab open until changes save.')); } catch { toast('Device backup is full. Keep this tab open until changes save.'); } }
function rebuild() { board=optimisticBoard(serverBoard,pending); render(); status(); }
function commit(op, original) { const before={...board,elements:{...board.elements}};op=prepareOperation(op,original || board.elements[op.id || op.element?.id]);op.op_id ||= uid();pending.push(op);const children=op.type==='batch'?op.ops:[op];for(const child of children)if(child.recovery_element)before.elements[child.id||child.element?.id]=child.recovery_element;applyOperation(board,op);if(!replayingHistory){historyNotice('');historyRequest=null;const affected=new Set(children.map(child=>child.id||child.element?.id));for(const child of children)if(child.type==='delete')for(const element of Object.values(before.elements))if(element.from===child.id||element.to===child.id)affected.add(element.id);history.record(before,board,actionLabel(op),affected);}backup();render();status();flush(); }
function acceptSnapshot(snapshot) {
  if(!serverBoard || snapshot.revision>=serverBoard.revision){preserveRemovedDrafts(snapshot);serverBoard=snapshot;}
  rememberBoard(snapshot);rebuild();if(conflict&&$('#conflict-dialog').open){const op=pending[0];$('#conflict-current').textContent=op.type==='batch'?conflictDescription(serverBoard,op.ops):describeElement(serverBoard.elements[op.id||op.element?.id]);}
}
function preserveRemovedDrafts(snapshot){ui?.preserveDrafts(snapshot);}
function prepareBatch(ops,originals){return {type:'batch',ops:ops.map(op=>prepareOperation(op,originals?.get(op.id)||board.elements[op.id||op.element?.id]))};}
function commitBatch(ops,originals,historyGuard){if(!ops.length)return false;const batch=prepareBatch(ops,originals);if(historyGuard)batch.history_guard=historyGuard;if(new Blob([JSON.stringify(wireOperation(batch))]).size>12_000_000){toast('This selection is too large to save at once. Try a smaller selection.');return false;}commit(batch);return true;}
function conflictDescription(snapshot,ops){return ops.map((op,index)=>{const id=op.id||op.element?.id;return `${index+1}. ${describeElement(snapshot.elements[id])}`;}).join('\n\nâ”€â”€â”€â”€â”€â”€â”€â”€\n\n');}
function showConflict(snapshot, reason='conflict') {
  conflict=true;sending=false;history.clear();historyRequest=null;
  if(snapshot)acceptSnapshot(snapshot);
  const op=pending[0],id=op.id||op.element?.id,current=serverBoard.elements[id];
  if(op.type==='batch'){const local=optimisticBoard({...serverBoard,elements:{...serverBoard.elements,...Object.fromEntries(op.ops.filter(p=>p.recovery_element).map(p=>[p.id,p.recovery_element]))}},[op]);$('#conflict-current').textContent=conflictDescription(serverBoard,op.ops);$('#conflict-draft').textContent=conflictDescription(local,op.ops);$('#conflict-message').textContent='Part of this selection changed while you were working. Nothing in this action was partially saved. Review the whole selection before choosing.';$('#conflict-keep').disabled=reason!=='conflict';$('#conflict-keep').textContent='Keep selected changes';if(!$('#conflict-dialog').open)$('#conflict-dialog').showModal();status();return;}
  const proposed=optimisticBoard({elements:{[id]:op.recovery_element||current||op.element}},pending.filter(p=>(p.id||p.element?.id)===id)).elements[id];
  $('#conflict-current').textContent=describeElement(current);
  $('#conflict-draft').textContent=proposed?describeElement(proposed):'Delete this element';
  $('#conflict-message').textContent=reason==='conflict'?'Someone changed this element while you were editing. Your draft is saved on this device.':'This change could not be saved. Review your draft or use the current board.';
  $('#conflict-keep').disabled=reason!=='conflict'||(!current&&(!proposed||proposed.type==='connection'));
  $('#conflict-keep').textContent=current?'Keep my version':'Keep as a new element';
  if(!$('#conflict-dialog').open)$('#conflict-dialog').showModal();status();
}
for(const [selector,keep] of [['#conflict-current-button',false],['#conflict-keep',true]])$(selector).onclick=()=>{pending=resolveConflict(serverBoard,pending,keep,uid());conflict=false;$('#conflict-dialog').close();backup();rebuild();flush();};
$('#conflict-dialog').oncancel=e=>e.preventDefault();
function flush() {
  if (!ready || sending || conflict || !pending.length || Date.now()<retrySaveAt) return;
  sending = true;
  if(serverBoard.recent_operations?.includes(pending[0].op_id)){pending.shift();sending=false;backup();rebuild();flush();return;}
  if(pending[0].history_guard){const operation=pending[0],plan=guardedHistoryPlan(serverBoard,operation.history_guard);if(plan.error){sending=false;historyNotice(plan.error);showConflict(serverBoard,'history_blocked');return;}if(!plan.ops.length){pending.shift();sending=false;backup();rebuild();flush();return;}const prepared={type:'batch',ops:plan.ops.map(op=>prepareOperation(op,serverBoard.elements[op.id||op.element?.id]))};pending[0]={...prepared,op_id:operation.op_id,history_guard:operation.history_guard};backup();}
  const operation=pending[0],activeChannel=channel;
  channel.push('operation',wireOperation(operation),15000).receive('ok', ({snapshot}) => {
    if(pending[0]?.op_id!==operation.op_id||activeChannel!==channel)return;
    pending.shift();sending=false;if(operation.history_guard&&ready&&!pending.length)historyNotice('');if(snapshot)acceptSnapshot(snapshot);backup();status();flush();
  }).receive('error', ({reason,snapshot,retry_after_ms}) => {
    if(pending[0]?.op_id!==operation.op_id||activeChannel!==channel)return;
    sending=false;
    if(reason==='rate_limited'){const wait=Math.min(60000,Math.max(1000,Number(retry_after_ms)||1000));retrySaveAt=Date.now()+wait;historyNotice('Saving is paused briefly. Your changes are kept on this device.');clearTimeout(retrySaveTimer);retrySaveTimer=setTimeout(()=>{retrySaveAt=0;historyNotice('');flush();},wait);status();return;}
    if(reason==='not_found'){loseAccess('This board expired, was deleted, or your access changed. Sign in or ask its owner for a new invitation.');return;}
    showConflict(snapshot,reason);
  }).receive('timeout', () => { sending=false;ready=false;status();socket.disconnect();socket.connect(); });
}
$('#join-open').onclick = () => $('#join-dialog').showModal();
$('#close-join').onclick = () => $('#join-dialog').close();
hook.handleEvent('nook:toast',({message})=>{if($('#join-dialog').open)$('#join-error').textContent=message;else toast(message);});
let inviteRequest=null,selfParticipantId;
function roomFeedback(message){$('#invite-feedback').textContent=message;$('#invite-feedback').hidden=!message;}
async function prepareInvitation(){
  if(!board?.can_manage)return;
  if(inviteRequest)return inviteRequest;
  $('#copy-link').disabled=true;$('#room-link').placeholder='Preparing your link…';
  inviteRequest=(async()=>{try{const result=await api(`/api/boards/${board.code}/invitations/reuse`,{});$('#room-link').value=`${location.origin}${result.path}`;$('#copy-link').disabled=false;}catch{$('#room-link').placeholder='Link unavailable';roomFeedback('Could not prepare the link. Reopen this room to try again.');}finally{inviteRequest=null;}})();
  return inviteRequest;
}
function share(){if(!board)return;$('#name-form').hidden=true;refreshRequests();roomFeedback('');$('#room-open').checked=!!board.room_open;$('#room-owner-controls').hidden=!board.can_manage;$('#advanced-sharing').hidden=!board.can_manage;$('#room-code').value=board.room_code||board.code;$('#room-link').placeholder=board.can_manage?'Preparing your link…':'Ask the owner for an invitation link';$('#copy-link').disabled=!$('#room-link').value;if(!$('#room-dialog').open)$('#room-dialog').showModal();if(board.can_manage)prepareInvitation();}
let sharingAction;
for(const [selector,action,title]of [['#create-invite','create_invite','Replace this invitation?'],['#disable-sharing','disable_sharing','Disable sharing?']])if($(selector))$(selector).onclick=()=>{sharingAction=action;$('#sharing-confirm-title').textContent=title;$('#sharing-confirm-dialog').showModal();};
$('#sharing-cancel').onclick=()=>$('#sharing-confirm-dialog').close();
$('#sharing-confirm').onclick=()=>{$('#sharing-confirm-dialog').close();hook.pushEvent(sharingAction,{});};
hook.handleEvent('nook:invite',({path})=>{$('#room-link').value=path?`${location.origin}${path}`:'';$('#copy-link').disabled=!path;toast(path?'Invitation replaced. Previous guests need the new link.':'Sharing disabled. Previous invitations no longer work.');});
for (const [button, input] of [['#copy-code','#room-code'],['#copy-link','#room-link']]) $(button).onclick = async () => {
  try { await navigator.clipboard.writeText($(input).value); const text = $(button).textContent; $(button).textContent='Copied!'; setTimeout(() => $(button).textContent=text,1400); } catch { $(input).select(); toast('Select and copy the highlighted text.'); }
};
$('#share-button').onclick=share;
$('#help').onclick = () => $('#help-dialog').showModal();
$('#retry-load').onclick=()=>location.reload();
ui=createCanvasUI({beginAction:label=>history.begin(label),endAction:()=>{history.end();status();},requestHistory,root:hook.el,getBoard:()=>board,commit,commitBatch,send:(event,payload)=>{if(ready)channel.push(event,payload);},toast,openRoom:share,tools,icons,onDirty:status});
const studioSettings=installStudioSettings(hook.el);
function requestHistory(direction){ui.finishEditing();if(conflict){historyNotice('Review the conflicting change before using Undo or Redo.');return;}if(ready&&pending.length){historyRequest=direction;historyNotice('Waiting for your last change to saveâ€¦');return;}const plan=history.plan(board,direction);if(plan.error){historyNotice(plan.error);return;}if(!plan.ops.length)return;const {group,...entry}=plan.entry;const guard={direction,entry:structuredClone(entry)};replayingHistory=true;try{if(commitBatch(plan.ops,undefined,guard)!==false){history.accept(direction,plan);historyNotice(ready?'':`${direction==='undo'?'Undone':'Redone'} on this device. It will sync when you reconnect.`);}}finally{replayingHistory=false;status();}}
$('#history-dismiss').onclick=()=>historyNotice('');
for(const direction of ['undo','redo']){$(`#${direction}`).onpointerdown=e=>e.preventDefault();$(`#${direction}`).onclick=()=>requestHistory(direction);}
function render(){ui.render();}
function transform(){ui.transform();}
listen(window,'beforeunload',e=>{ui.finishEditing();if(pending.length){e.preventDefault();e.returnValue='';}});
async function start(){
  const code=location.pathname.match(/^\/b\/([A-Z2-7]{12,13})\/?$/)?.[1];if(!location.pathname.startsWith('/b/'))return;
  $('#landing').hidden=true;$('#workspace').hidden=false;$('#board-load-state').hidden=false;canvas.inert=true;$('#toolbar').inert=true;$('#share-button').disabled=true;$('#collaborators').disabled=true;
  if(!code){showLoadFailure(404);return;}
  try{
    const r=await fetch(`/api/boards/${code}`,{signal:AbortSignal.timeout(15000)});if(!r.ok){showLoadFailure(r.status);return;}serverBoard=await r.json();board=structuredClone(serverBoard);
    try{draftStore=await openRecoveryStore(code,uid(),performance.getEntriesByType('navigation')[0]?.type);pending=draftStore.pending;history.restore(draftStore.history);}catch{pending=[];toast('Device backup is unavailable. Keep this tab open until changes save.');}
    pending.forEach(op=>applyOperation(board,op));$('#board-load-state').hidden=true;canvas.inert=false;$('#toolbar').inert=false;$('#share-button').disabled=false;$('#collaborators').disabled=false;render();transform();
    rememberBoard(board);$('#board-title').readOnly=!board.can_manage;
    socket=new Socket('/socket',{params:{_csrf_token:document.querySelector('meta[name=csrf-token]').content}});socket.connect();channel=socket.channel(`board:${code}`,()=>({name:localStorage.getItem('nook-name')||''}));
    channel.on('operation',({op,revision})=>{if(revision<=serverBoard.revision)return;if(revision!==serverBoard.revision+1){refreshSnapshot();return;}const next={...serverBoard,elements:{...serverBoard.elements}};applyOperation(next,op);next.revision=revision;acceptSnapshot(next);});
    channel.on('preview',({id,changes})=>{if(board.elements[id]&&!ui.isDragging(id)){board.elements[id]={...board.elements[id],...changes};render();}});
    channel.on('previews',({elements:updates})=>{for(const {id,changes}of updates)if(board.elements[id]&&!ui.isDragging(id))board.elements[id]={...board.elements[id],...changes};render();});
    channel.on('drawing',payload=>ui.receiveDrawing(payload));
    channel.on('cursor',cursor=>ui.receiveCursor(cursor));
    channel.on('access_lost',({message})=>loseAccess(message));
    channel.on('access_changed',()=>{refreshAccess();refreshRequests();});channel.on('room_requests_changed',()=>refreshRequests());
    channel.on('presence_state',state=>{presence=Presence.syncState(presence,state);updatePresence();});
    channel.on('presence_diff',diff=>{presence=Presence.syncDiff(presence,diff);updatePresence();});
    const joined=channel.join();
    joined.receive('ok',snapshot=>{ui.setSelfCursor(snapshot.cursor_id);ready=true;sending=false;acceptSnapshot(snapshot);selfParticipantId=snapshot.self?.id;$('#participant-name').value=snapshot.self?.name||'';updatePresence();refreshRequests();status();flush();});
    joined.receive('error',()=>{ready=false;status();toast('Could not reconnect. Your drafts stay on this device. Try reloading.');refreshAccess();});
    joined.receive('timeout',()=>{ready=false;status();});
    channel.onClose(()=>{ready=false;sending=false;status();});
    channel.onError(()=>{ui.resetCursors();ready=false;sending=false;status();refreshAccess();});
  }catch{showLoadFailure();}
}
function showLoadFailure(code){const failure=loadFailure(code);$('#board-load-state').hidden=false;$('#load-title').textContent=failure.title;$('#load-detail').textContent=failure.detail;$('#load-actions').hidden=false;$('#board-load-state').setAttribute('aria-busy','false');$('#save-status').textContent='Unable to load';}
function updatePresence(){
  ui.syncPresence(presence);
  $('#collaborators').textContent=`${Object.keys(presence).length} here`;
  $('#participants').replaceChildren();$('#room-people-count').textContent=String(Object.keys(presence).length);
  for(const {metas} of Object.values(presence)){
    const profile=metas.at(-1),row=document.createElement('li'),dot=document.createElement('span');
    dot.className=`participant-dot ${profile.color}`;dot.textContent=profile.name.trim().charAt(0).toUpperCase();dot.setAttribute('aria-hidden','true');const name=document.createElement('span');name.className='participant-name';name.textContent=profile.name;const role=document.createElement('small');role.className='participant-role';role.textContent=profile.id===selfParticipantId?'You':profile.role;row.append(dot,name,role);if(profile.id===selfParticipantId){const edit=document.createElement('button');edit.type='button';edit.className='participant-edit';edit.setAttribute('aria-label','Edit your name');edit.title='Edit your name';edit.innerHTML='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><path d="m5 16-1 4 4-1L20 7l-3-3Zm10-10 3 3"/></svg>';edit.onclick=()=>{$('#name-form').hidden=!$('#name-form').hidden;if(!$('#name-form').hidden){$('#participant-name').focus();$('#participant-name').select();}};row.append(edit);}$('#participants').append(row);
  }
}
$('#collaborators').onclick=share;
$('#name-form').onsubmit=e=>{e.preventDefault();const name=$('#participant-name').value.trim();channel.push('set_name',{name}).receive('ok',profile=>{try{localStorage.setItem('nook-name',profile.name);}catch{}$('#participant-name').value=profile.name;$('#name-form').hidden=true;roomFeedback('Name updated.');});};
async function api(path,body){const r=await fetch(path,{method:body?'POST':'GET',headers:{'content-type':'application/json','x-csrf-token':document.querySelector('meta[name=csrf-token]').content},...(body?{body:JSON.stringify(body)}:{})});if(!r.ok)throw Error('unavailable');return r.json();}
async function refreshRequests(){
  if(!board?.can_manage){$('#room-requests').hidden=true;return;}
  try{const requests=await api(`/api/boards/${board.code}/requests`);$('#requests').replaceChildren();$('#request-count').textContent=requests.length?`${requests.length} waiting`:'';$('#room-requests').hidden=!requests.length;
    for(const request of requests){const row=document.createElement('li'),name=document.createElement('span');name.textContent=request.name;row.append(name);for(const [label,decision]of [['Admit','approved'],['Decline','denied']]){const b=document.createElement('button');b.className=decision==='approved'?'primary':'secondary';b.textContent=label;b.onclick=async()=>{try{await api(`/api/boards/${board.code}/requests/${request.id}`,{decision});refreshRequests();}catch{toast('This request is no longer available.');refreshRequests();}};row.append(b);}$('#requests').append(row);}
  }catch{/* Access changes are handled by the board channel. */}
}
$('#room-open').onchange=async()=>{try{const result=await api(`/api/boards/${board.code}/requests/open`,{open:$('#room-open').checked});board.room_open=result.room_open;serverBoard.room_open=result.room_open;toast(result.room_open?'Room-code requests are open. You approve each visitor.':'Room-code requests are closed.');refreshRequests();}catch{$('#room-open').checked=!!board.room_open;toast('Only the owner can change room admission.');}};
function waitForAdmission(request){
  clearTimeout(admissionTimer);sessionStorage.setItem('nook-admission',request.id);$('#join-error').textContent='Waiting for the owner to approve your requestâ€¦';
  const poll=async()=>{try{const result=await api(`/api/room-requests/${request.id}`);if(result.status==='approved'&&result.path){sessionStorage.removeItem('nook-admission');location.assign(result.path);return;}if(result.status!=='pending'){sessionStorage.removeItem('nook-admission');$('#join-error').textContent=result.status==='denied'?'The owner declined this request. Ask for an invitation link.':'This request expired. Ask the owner to open room-code requests, then try again.';return;}}catch{$('#join-error').textContent='Unable to check the request. Retryingâ€¦';}admissionTimer=setTimeout(poll,2000);};poll();
}
hook.handleEvent('nook:admission',request=>{localStorage.setItem('nook-name',$('#join-name').value.trim());waitForAdmission(request);});
const waiting=sessionStorage.getItem('nook-admission');if(waiting&&!location.pathname.startsWith('/b/')){$('#join-dialog').showModal();waitForAdmission({id:waiting});}
async function refreshSnapshot(){try{const snapshot=await api(`/api/boards/${board.code}`);acceptSnapshot(snapshot);}catch{refreshAccess();}}
function loseAccess(message){ready=false;$('#connection-notice').hidden=true;$('#board-load-state').hidden=true;ui.resetCursors();$('#conflict-dialog').close();$('#room-dialog').close();$('#sharing-confirm-dialog').close();canvas.inert=true;$('#toolbar').inert=true;$('#selection-bar').hidden=true;$('#access-message').hidden=false;$('#access-reason').textContent=message;elements.replaceChildren();$('#connections').replaceChildren();$('#save-status').textContent='Access unavailable';channel?.leave();}
async function refreshAccess(){try{const r=await fetch(`/api/boards/${board.code}`);if(r.status===404){loseAccess('This board expired, was deleted, or your permission changed. Sign in or ask its owner for a new invitation.');return;}if(r.ok){const info=await r.json();for(const key of ['kind','can_manage','can_claim','sharing_enabled','sharing_active','room_open','expires_at'])board[key]=serverBoard[key]=info[key];$('#room-open').checked=!!board.room_open;$('#board-title').readOnly=!board.can_manage;const label=$('.board-lifecycle>span');if(label&&board.kind==='permanent')label.textContent=`Saved board Â· ${board.sharing_active?'shared with guests':'private'}`;}}catch{/* A network interruption keeps unsaved operations queued. */}}
function rememberBoard(info){if(!info?.code)return;try{let list=JSON.parse(localStorage.getItem('nook-recent-boards')||'[]');if(!Array.isArray(list))list=[];list=[{code:info.code,title:info.title||'Untitled board',kind:info.kind,expires_at:info.expires_at,opened:Date.now()},...list.filter(item=>item.code!==info.code)].slice(0,12);localStorage.setItem('nook-recent-boards',JSON.stringify(list));}catch{/* Browsing stays possible with storage disabled. */}}
function showRecentBoards(){try{
  const list=JSON.parse(localStorage.getItem('nook-recent-boards')||'[]');if(!Array.isArray(list))return;
  const valid=list.slice(0,12).filter(item=>item&&/^[A-Z2-7]{12,13}$/.test(item.code));if(!valid.length)return;
  $('#recent-boards').hidden=false;$('#recent-list').replaceChildren();
  const today=new Date();today.setHours(0,0,0,0);const yesterday=new Date(today);yesterday.setDate(yesterday.getDate()-1);
  for(const item of valid){
    const li=document.createElement('li'),link=document.createElement('a'),thumb=document.createElement('span'),label=document.createElement('div'),title=document.createElement('strong'),meta=document.createElement('p');
    link.className='recent-item';link.href=`/b/${item.code}`;thumb.className='thumb';thumb.setAttribute('aria-hidden','true');
    thumb.innerHTML='<svg viewBox="0 0 80 48"><rect x="4" y="9" width="27" height="31" fill="#e9dcf5" stroke="none"/><path d="M9 18h16M9 24h12M9 30h13M35 24h17m-5-4 5 4-5 4"/><ellipse cx="66" cy="22" rx="11" ry="8"/></svg>';
    title.textContent=item.title||'Untitled board';const opened=new Date(item.opened),validDate=Number.isFinite(opened.getTime());
    meta.textContent=item.expires_at&&Date.parse(item.expires_at)<Date.now()?'May have expired':validDate?(opened>=today?'Opened today':opened>=yesterday?'Opened yesterday':`Opened ${opened.toLocaleDateString(undefined,{month:'short',day:'numeric'})}`):item.kind==='permanent'?'Saved board':'Quick board';
    label.append(title,meta);link.append(thumb,label);li.append(link);$('#recent-list').append(li);
  }
}catch{/* Opening the home page does not require device storage. */}}

if(!location.pathname.startsWith('/b/'))showRecentBoards();
start();
return () => { studioSettings.dispose();ui.dispose();draftStore?.close?.();lifecycle.abort();clearTimeout(admissionTimer);clearTimeout(retrySaveTimer);socket?.disconnect(); clearTimeout(toastTimer); };
}
