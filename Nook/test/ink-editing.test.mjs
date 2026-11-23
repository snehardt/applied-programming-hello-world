import test from 'node:test';
import assert from 'node:assert/strict';
import {eraseInk,inkPoints,lassoStrokes,readDrawingSettings,writeDrawingSettings,drawingDefaults} from '../priv/static/assets/ink-editing.mjs';
import {makeStroke} from '../priv/static/assets/drawing.mjs';
const p=(x,y)=>({x,y});
const close=(a,b)=>assert.ok(Math.abs(a-b)<1e-6,`${a} != ${b}`);
test('precise erasing splits a crossing segment at the eraser boundary',()=>{
 const result=eraseInk([p(0,0),p(100,0)],p(50,-10),p(50,10),5);
 assert.equal(result.changed,true);assert.equal(result.parts.length,2);close(result.parts[0].at(-1).x,45);close(result.parts[1][0].x,55);
});
test('fast erasing sweeps between events and preserves untouched geometry',()=>{
 const points=[p(0,0),p(100,0)],result=eraseInk(points,p(20,0),p(80,0),4);assert.equal(result.parts.length,2);close(result.parts[0].at(-1).x,16);close(result.parts[1][0].x,84);
 const miss=eraseInk(points,p(20,50),p(80,50),4);assert.equal(miss.changed,false);assert.equal(miss.parts[0],points);
 assert.deepEqual(eraseInk([p(5,5)],p(0,0),p(10,10),2).parts,[]);
});
test('repeated cuts preserve separate fragments without reconnecting erased ink',()=>{
 const first=eraseInk([p(0,0),p(100,0)],p(30,0),p(30,0),5);
 const second=first.parts.flatMap(part=>eraseInk(part,p(70,0),p(70,0),5).parts);assert.equal(second.length,3);close(second[1][0].x,35);close(second[1].at(-1).x,65);
});
test('eraser geometry follows rotated ink and legacy quadratic paths',()=>{
 const el={...makeStroke([p(0,0),p(50,50),p(100,0)],'#210a3b',4,'s',1),rotation:90,linear:false};
 const points=inkPoints(el);assert.ok(points.length>3);const center=points[Math.floor(points.length/2)];assert.equal(eraseInk(points,center,center,8).changed,true);
});
test('lasso selects fully enclosed ink and rejects strokes crossing a concave gap',()=>{
 const polygon=[p(0,0),p(100,0),p(100,100),p(70,100),p(70,30),p(30,30),p(30,100),p(0,100)],stroke=(points,id)=>makeStroke(points,'#210a3b',4,id,1);
 const a=stroke([p(10,10),p(90,10)],'a'),b=stroke([p(10,60),p(90,60)],'b'),c={...stroke([p(5,5)],'c'),type:'note'};
 assert.deepEqual(lassoStrokes([a,b,c],polygon),['a']);assert.deepEqual(lassoStrokes([a],[p(0,0)]),[]);
});
test('pen, eraser, smoothing, touch and favorite settings survive reload safely',()=>{
 let raw;const storage={getItem:()=>raw,setItem:(_,value)=>raw=value},settings={...drawingDefaults(),mode:'eraser',color:'#123456',width:7,eraserSize:42,eraserType:'partial',smooth:true};writeDrawingSettings(storage,settings);assert.deepEqual(readDrawingSettings(storage),settings);
 raw=JSON.stringify({color:'red',width:-8,mode:'bad',eraserSize:1000,presets:[{color:'javascript:bad'}]});assert.deepEqual(readDrawingSettings(storage),drawingDefaults());raw='{bad';assert.deepEqual(readDrawingSettings(storage),drawingDefaults());assert.doesNotThrow(()=>writeDrawingSettings({setItem(){throw Error();}},settings));
});
import {BoardHistory} from '../priv/static/assets/history.mjs';
import {applyOperation} from '../priv/static/assets/canvas-model.mjs';
test('precise erasing is one undoable action and preserves highlighter appearance',()=>{
 const original={...makeStroke([p(0,0),p(100,0)],'#e7b52b',18,'s',1),opacity:.3},before={elements:{s:original}},board=structuredClone(before),history=new BoardHistory(),parts=eraseInk(inkPoints(original),p(50,-20),p(50,20),10).parts;
 const fragments=parts.map((points,i)=>({...original,...makeStroke(points,original.color,original.stroke_width,i?'piece':'s',original.z),rotation:0}));
 const changes=Object.fromEntries(['x','y','w','h','points','linear','rotation'].map(key=>[key,fragments[0][key]]));history.begin('erase ink');applyOperation(board,{type:'batch',ops:[{type:'patch',id:'s',changes},{type:'put',element:fragments[1]}]});history.record(before,board);history.end();assert.equal(history.undo.length,1);assert.equal(board.elements.piece.opacity,.3);
 const plan=history.plan(board,'undo');for(const op of plan.ops)applyOperation(board,op);assert.deepEqual(board,before);
});
