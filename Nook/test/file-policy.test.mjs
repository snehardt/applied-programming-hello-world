import {test} from 'node:test';import assert from 'node:assert/strict';import {fileError} from '../priv/static/assets/file-policy.mjs';
test('file chooser and drop allow supported files and reject oversize/active content',()=>{for(const type of ['image/png','image/jpeg','image/webp','application/pdf','text/plain'])assert.equal(fileError({size:123,type,name:'file'}),null);assert.equal(fileError({size:123,type:'',name:'plan.md'}),null);assert.match(fileError({size:10000001,type:'image/png',name:'big.png'}),/10 MB/);for(const type of ['image/svg+xml','text/html','application/javascript'])assert.ok(fileError({size:50,type,name:'file'}));});

test('empty files and names beyond the storage limit are caught before placement',()=>{assert.match(fileError({size:0,type:'text/plain',name:'empty.txt'}),/empty/);assert.match(fileError({size:4,type:'text/plain',name:'x'.repeat(256)}),/name/);});


test('clipboard images support browser image items and file fallback without duplicating them',async()=>{
 const {clipboardImages}=await import('../priv/static/assets/file-policy.mjs');const file={type:'image/png',name:'image.png',size:100};
 assert.deepEqual(clipboardImages({items:[{kind:'file',type:'image/png',getAsFile:()=>file}],files:[file]}),[file]);
 assert.deepEqual(clipboardImages({items:[{kind:'string',type:'text/html'}],files:[file]}),[file]);
 assert.deepEqual(clipboardImages({items:[{kind:'string',type:'text/plain'}],files:[]}),[]);
 assert.deepEqual(clipboardImages({items:[{kind:'file',type:'image/png',getAsFile:()=>null}],files:[file]}),[file]);
});
test('image cards preserve their aspect ratio within a practical canvas size',async()=>{
 const {imageCardSize}=await import('../priv/static/assets/file-policy.mjs');assert.deepEqual(imageCardSize(800,400),{w:320,h:160});assert.deepEqual(imageCardSize(400,800),{w:130,h:260});assert.deepEqual(imageCardSize(0,0),{w:280,h:220});assert.deepEqual(imageCardSize(30,30),{w:50,h:50});
});
