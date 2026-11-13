import test from 'node:test';
import assert from 'node:assert/strict';
import {iconPaths,validHex,contrast,snapMove,overlappingItems,selectionBarPosition} from '../priv/static/assets/visual-tools.mjs';
test('custom colors reject CSS and support six digit hex',()=>{assert.ok(validHex('#AD7BFA'));for(const value of ['red','#fff','url(x)',null,'#ffffff;'])assert.equal(validHex(value),false);assert.equal(contrast('white','white'),1);assert.equal(contrast('#000000','white'),21);});
test('snapping uses screen tolerance and preserves group offsets',()=>{const box={x:0,y:0,w:100,h:100},other={x:200,y:300,w:100,h:100};const s=snapMove(box,[other],98,100);assert.equal(s.dx,100);assert.equal(s.dy,100);assert.deepEqual(s.guides,[{axis:'x',at:200}]);assert.equal(snapMove(box,[other],98,100,3).dx,98);assert.equal(snapMove(box,[],98,100).dx,98);});
test('icons are a small fixed vocabulary of safe SVG paths',()=>{assert.equal(Object.keys(iconPaths).length,8);for(const svg of Object.values(iconPaths)){assert.match(svg,/<(path|circle)/);assert.doesNotMatch(svg,/script|onload|href/);}});

test('covered items remain selectable in canvas stacking order without mutation',()=>{
 const note={id:'note',type:'note',x:10,y:10,w:100,h:100,z:1},icon={id:'icon',type:'icon',x:0,y:0,w:200,h:200,z:5},top={...note,id:'top',z:5},far={...note,id:'far',x:400},touch={...note,id:'touch',x:200},edge={id:'edge',type:'connection',x:0,y:0,w:200,h:200};
 const all=[note,icon,top,far,touch,edge],before=JSON.stringify(all);
 assert.deepEqual(overlappingItems(all,['icon']).map(el=>el.id),['top','note']);
 assert.deepEqual(overlappingItems(all,['note','top']).map(el=>el.id),['icon']);
 assert.deepEqual(overlappingItems(all,[]),[]);assert.equal(JSON.stringify(all),before);
});

test('selection controls follow screen-space items above the box, flipping and clamping near edges',()=>{
 const size={width:300,height:48},view={width:800,height:700,top:76};
 assert.deepEqual(selectionBarPosition({x:200,y:300,w:200,h:100},size,view),{x:150,y:240});
 assert.deepEqual(selectionBarPosition({x:0,y:300,w:100,h:100},size,view),{x:12,y:240});
 assert.deepEqual(selectionBarPosition({x:200,y:100,w:200,h:100},size,view),{x:150,y:212});
 const obstacle={x:0,y:90,w:700,h:100};
 assert.deepEqual(selectionBarPosition({x:200,y:210,w:200,h:100},size,view,[obstacle]),{x:150,y:322});
 const offscreen=selectionBarPosition({x:2000,y:-500,w:200,h:100},size,view,[obstacle]);assert.ok(offscreen.x<=488&&offscreen.y>=88&&offscreen.y<=640);
});

test('successive local covers expose all remaining overlapping layers without mutating items',()=>{
 const card=id=>({id,type:'note',x:0,y:0,w:200,h:100,text:id});
 const all=[card('bottom'),{...card('middle'),z:2},{...card('cover'),z:3},{...card('outside'),x:500}],snapshot=JSON.stringify(all);
 assert.deepEqual(overlappingItems(all,new Set(['cover'])).map(el=>el.id),['middle','bottom']);
 assert.deepEqual(overlappingItems(all,new Set(['cover','middle'])).map(el=>el.id),['bottom']);
 assert.deepEqual(overlappingItems(all,new Set(['cover','middle','bottom'])),[]);
 assert.equal(JSON.stringify(all),snapshot);
});
