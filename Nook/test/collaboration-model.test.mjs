import {test} from 'node:test';
import assert from 'node:assert/strict';
import {prepareOperation, optimisticBoard, wireOperation, resolveConflict, describeElement, openDraftStore} from '../priv/static/assets/collaboration-model.mjs';
const note = {id:'a',type:'note',revision:1,x:10,y:20,w:230,h:200,text:'Original'};
test('typing immediately after placement uses the first persisted revision before creation is acknowledged',()=>{
  const fresh={...note};delete fresh.revision;
  const op=prepareOperation({type:'patch',id:'a',changes:{text:'Immediate draft'}},fresh);
  assert.equal(op.base_revision,1);assert.equal(op.base.text,'Original');
});
test('atomic selection drafts strip all recovery copies and can be explicitly rebased together',()=>{
  const a=prepareOperation({type:'patch',id:'a',changes:{x:90}},note),b=prepareOperation({type:'patch',id:'b',changes:{x:150}},{...note,id:'b'});
  const batch={type:'batch',ops:[a,b],op_id:'old'};
  assert.equal(wireOperation(batch).ops[0].recovery_element,undefined);
  const server={elements:{a:{...note,revision:4,x:40},b:{...note,id:'b',revision:2,x:30}}};
  const rebased=resolveConflict(server,[batch],true,'new');assert.equal(rebased[0].ops[0].base_revision,4);
  const result=optimisticBoard(server,rebased);assert.equal(result.elements.a.x,90);assert.equal(result.elements.b.x,150);assert.equal(server.elements.a.x,40);
  assert.deepEqual(resolveConflict(server,[batch],false,'discard'),[]);
});
test('large boards reuse untouched elements when replaying local patches',()=>{
  const elements=Object.fromEntries(Array.from({length:2000},(_,i)=>[String(i),{...note,id:String(i)}]));
  const board={elements};const next=optimisticBoard(board,[{type:'patch',id:'0',changes:{x:90}}]);
  assert.notEqual(next.elements['0'],elements['0']);assert.equal(next.elements['1999'],elements['1999']);assert.equal(elements['0'].x,10);
});
test('pending operations retain original values, keep recovery local, and never mutate authoritative state',()=>{
  const op=prepareOperation({type:'patch',id:'a',changes:{text:'Draft'}},note);
  const server={revision:2,elements:{a:{...note,revision:2,text:'Remote'}}};
  assert.equal(op.base.text,'Original');assert.equal(op.base_revision,1);
  assert.equal(optimisticBoard(server,[op]).elements.a.text,'Draft');
  assert.equal(server.elements.a.text,'Remote');assert.equal(wireOperation(op).recovery_element,undefined);
});
test('explicit keep rebases the combined local intent and preserves unrelated queued work',()=>{
  const pending=[prepareOperation({type:'patch',id:'a',changes:{text:'First'}},note),prepareOperation({type:'patch',id:'a',changes:{text:'Final'}},{...note,text:'First'}),{type:'rename',title:'My board'}];
  const server={elements:{a:{...note,revision:4,text:'Remote',x:80}}};
  const resolved=resolveConflict(server,pending,true,'resolution');
  assert.equal(resolved.length,2);assert.equal(resolved[0].changes.text,'Final');assert.equal(resolved[0].base_revision,4);
  assert.equal(resolved[0].base.text,'Remote');assert.equal(optimisticBoard(server,resolved).elements.a.x,80);
  assert.deepEqual(resolveConflict(server,pending,false,'discard'),[pending[2]]);
});
test('a deleted draft is recreated only by explicit choice with a new id',()=>{
  const op=prepareOperation({type:'patch',id:'a',changes:{text:'Unsaved idea'}},note);
  const resolved=resolveConflict({elements:{}},[op],true,'new-id');
  assert.equal(resolved[0].type,'put');assert.equal(resolved[0].element.id,'new-id');
  assert.equal(resolved[0].element.text,'Unsaved idea');assert.equal(resolved[0].element.revision,undefined);
});
test('canonical revisions apply before later offline edits are replayed',()=>{
  const server={elements:{a:{...note,revision:5,text:'Saved'}}};
  const view=optimisticBoard(server,[prepareOperation({type:'patch',id:'a',changes:{x:60}},note)]);
  assert.equal(view.elements.a.revision,5);assert.equal(view.elements.a.text,'Saved');assert.equal(view.elements.a.x,60);
});

test('conflict summaries explain content without exposing internal ids or attachment data',()=>{
  const summary=describeElement({...note,id:'private-id',revision:99,type:'file',name:'Plan.pdf',data:'base64-private'});
  assert.match(summary,/Plan.pdf/);assert.match(summary,/Position: 10, 20/);assert.doesNotMatch(summary,/private-id|99|base64/);
});

test('separate and duplicated tabs cannot clear each other backup; reload and legacy drafts recover',()=>{
  const memory=()=>{const m=new Map();return {getItem:k=>m.get(k)??null,setItem:(k,v)=>m.set(k,v),removeItem:k=>m.delete(k)}};
  const storage=memory(),session=memory();
  storage.setItem('nook-pending:ROOM',JSON.stringify([{type:'patch',id:'a',changes:{text:'Legacy'}}]));
  const first=openDraftStore('ROOM',storage,session,'first');assert.equal(first.pending.length,1);
  assert.equal(storage.getItem('nook-pending:ROOM'),null);
  const duplicateSession=memory();duplicateSession.setItem('nook-draft:ROOM',session.getItem('nook-draft:ROOM'));
  const duplicate=openDraftStore('ROOM',storage,duplicateSession,'duplicate');assert.equal(duplicate.pending.length,1);
  duplicate.save([]);assert.equal(JSON.parse(storage.getItem('nook-pending:ROOM:first')).length,1);
  const reloaded=openDraftStore('ROOM',storage,session,'reload','reload');assert.equal(reloaded.pending[0].changes.text,'Legacy');
  assert.equal(storage.getItem('nook-pending:ROOM:first'),null);
  first.save([{type:'rename',title:'Other active tab'}]);
  reloaded.save([]);assert.equal(JSON.parse(storage.getItem('nook-pending:ROOM:first'))[0].title,'Other active tab');
});

test('history guards stay on this device and never enter channel payloads',()=>{const guarded={type:'batch',op_id:'offline',history_guard:{direction:'undo',entry:{private:'local'}},ops:[{type:'patch',id:'a',changes:{x:0},recovery_element:{text:'draft'}}]};const wire=wireOperation(guarded);assert.equal(wire.history_guard,undefined);assert.equal(wire.ops[0].recovery_element,undefined);assert.ok(guarded.history_guard);});
