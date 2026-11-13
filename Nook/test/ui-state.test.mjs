import {test} from 'node:test';
import assert from 'node:assert/strict';
import {saveState,loadFailure,readBoardView,writeBoardView} from '../priv/static/assets/ui-state.mjs';

test('board cameras round-trip independently without changing shared content',()=>{
 const values=new Map(),storage={getItem:key=>values.get(key)||null,setItem:(key,value)=>values.set(key,value)};
 writeBoardView(storage,'first',{x:-2700,y:123,z:.65});
 writeBoardView(storage,'second',{x:22,y:-12,z:2});
 assert.deepEqual(readBoardView(storage,'first'),{x:-2700,y:123,z:.65});
 assert.deepEqual(readBoardView(storage,'second'),{x:22,y:-12,z:2});
 assert.deepEqual(readBoardView(storage,'new'),{x:0,y:0,z:1});
});
test('invalid or unavailable camera storage preserves usable default navigation',()=>{
 for(const raw of ['broken','null','{}','{"x":0,"y":0,"z":0}','{"x":"4","y":0,"z":1}','{"x":1e100,"y":0,"z":1}'])
  assert.deepEqual(readBoardView({getItem:()=>raw},'board'),{x:0,y:0,z:1});
 const denied={getItem(){throw Error('blocked');},setItem(){throw Error('quota');}};
 assert.deepEqual(readBoardView(denied,'board'),{x:0,y:0,z:1});
 assert.doesNotThrow(()=>writeBoardView(denied,'board',{x:0,y:0,z:1}));
 assert.deepEqual(readBoardView(undefined,'board'),{x:0,y:0,z:1});
});
test('save feedback never claims offline or conflicting drafts are saved',()=>{
 assert.equal(saveState({ready:true}).kind,'saved');
 assert.equal(saveState({ready:true,pending:2}).kind,'saving');
 assert.equal(saveState({pending:2}).text,'Offline · changes on this device');
 assert.equal(saveState({ready:true,conflict:true,pending:1}).kind,'conflict');
 assert.equal(saveState({loading:true}).kind,'loading');
});
test('unavailable and network errors offer recovery without revealing private board details',()=>{
 assert.match(loadFailure(404).detail,/invitation/);
 assert.match(loadFailure(503).detail,/try again/);
 assert.match(loadFailure().detail,/drafts are kept/);
});
