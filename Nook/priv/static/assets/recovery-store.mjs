import {openDraftStore} from './collaboration-model.mjs';

// Large strokes need the browser's file-sized storage, rather than its tiny text quota.
// A per-page pointer preserves isolation between tabs and restores drafts after refresh.
export async function openRecoveryStore(code,pageId,navigationType='navigate'){
  if(!globalThis.indexedDB)return fallback(code,pageId,navigationType);
  const db=await new Promise((resolve,reject)=>{
    const request=indexedDB.open('nook-recovery',1);
    request.onupgradeneeded=()=>request.result.createObjectStore('pages');
    request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);
    request.onblocked=()=>reject(Error('Recovery storage is busy.'));
  });
  db.onversionchange=()=>db.close();
  const pointer=`nook-recovery:${code}`,previous=sessionStorage.getItem(pointer),key=`${pointer}:${pageId}`;
  const read=key=>new Promise((resolve,reject)=>{const request=db.transaction('pages').objectStore('pages').get(key);request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);});
  let value=previous?await read(previous):null;
  const oldPointer=sessionStorage.getItem(`nook-draft:${code}`),oldKey=oldPointer||`nook-pending:${code}`;
  if(!value){let pending;try{pending=JSON.parse(localStorage.getItem(oldKey)||'[]');}catch{pending=[];}value={pending:Array.isArray(pending)?pending:[],history:sessionStorage.getItem(`nook-history:${code}`)||''};}
  const write=()=>new Promise((resolve,reject)=>{
    const tx=db.transaction('pages','readwrite');tx.objectStore('pages').put({...value,updatedAt:Date.now()},key);
    tx.oncomplete=()=>resolve();tx.onabort=tx.onerror=()=>reject(tx.error||Error('Recovery storage unavailable.'));
  });
  await write();sessionStorage.setItem(pointer,key);
  // Only retire the predecessor after its replacement has committed successfully.
  if(previous&&navigationType==='reload'){
    const tx=db.transaction('pages','readwrite');tx.objectStore('pages').delete(previous);
  }
  if(!oldPointer||navigationType==='reload')localStorage.removeItem(oldKey);
  sessionStorage.removeItem(`nook-history:${code}`);sessionStorage.removeItem(`nook-draft:${code}`);
  const cleanup=db.transaction('pages','readwrite').objectStore('pages').openCursor();
  cleanup.onsuccess=()=>{const cursor=cleanup.result;if(!cursor)return;if(cursor.value.updatedAt<Date.now()-30*86400000)cursor.delete();cursor.continue();};
  return {pending:value.pending,history:value.history,
    save(ops){value={...value,pending:structuredClone(ops)};return write();},
    saveHistory(history){value={...value,history};return write();},
    close(){db.close();}};
}

function fallback(code,pageId,navigationType){
  const draft=openDraftStore(code,localStorage,sessionStorage,pageId,navigationType);
  return {...draft,history:sessionStorage.getItem(`nook-history:${code}`)||'',saveHistory(raw){sessionStorage.setItem(`nook-history:${code}`,raw);}};
}
