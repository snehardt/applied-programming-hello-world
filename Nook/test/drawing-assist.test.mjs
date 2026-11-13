import {test} from 'node:test';
import assert from 'node:assert/strict';
import {recognizeStroke,cleanedStrokes,worldPoints} from '../priv/static/assets/drawing-shapes.mjs';
import {makeStroke,enclosedStrokes,scheduleLineHold} from '../priv/static/assets/drawing.mjs';
import {BoardHistory} from '../priv/static/assets/history.mjs';
import {applyOperation} from '../priv/static/assets/canvas-model.mjs';
import {standardColors} from '../priv/static/assets/color-palette.mjs';
const p=(x,y)=>({x,y});
const stroke=(points,id='s')=>makeStroke(points,'#210a3b',4,id,1);
const circle=Array.from({length:65},(_,i)=>p(100+90*Math.cos(i*Math.PI/32),100+90*Math.sin(i*Math.PI/32)));

test('holding straightens once, retains the rough sketch and permits endpoint adjustment',async()=>{
 const original=[p(0,0),p(40,12),p(90,10)],draft={points:original};let straightened=0;
 scheduleLineHold(()=>draft,()=>straightened++,10);
 await new Promise(resolve=>setTimeout(resolve,30));
 assert.equal(straightened,1);assert.deepEqual(draft.raw,original);assert.equal(draft.points.length,2);
 draft.points=[draft.points[0],p(120,50)];assert.deepEqual(draft.raw,original);
 const cancelled=scheduleLineHold(()=>draft,()=>straightened++,10);clearTimeout(cancelled);
 scheduleLineHold(()=>null,()=>straightened++,10);
 await new Promise(resolve=>setTimeout(resolve,30));assert.equal(straightened,1);
});

test('recognizes boxes, triangles, ovals, diamonds, lines and a continuous arrow',()=>{
 for(const [kind,points]of [
  ['box',[p(0,0),p(100,3),p(103,100),p(-2,102),p(0,0)]],
  ['triangle',[p(50,0),p(102,99),p(0,102),p(50,0)]],
  ['diamond',[p(50,0),p(101,51),p(49,100),p(0,49),p(50,0)]],
  ['ellipse',circle],['line',[p(0,0),p(50,2),p(100,0)]],
  ['arrow',[p(0,50),p(100,50),p(75,25),p(100,50),p(75,75)]]
 ])assert.equal(recognizeStroke(points)?.kind,kind,kind);
 assert.equal(recognizeStroke([p(0,0),p(0,80),p(90,15),p(20,25),p(100,100)]),null);
});

test('a selected face and separate box sides clean up while preserving IDs and colors',()=>{
 const face=[stroke(circle,'face'),stroke([p(65,70)],'eye-left'),stroke([p(135,70)],'eye-right'),stroke([p(50,110),p(70,145),p(100,150),p(130,145),p(150,110)],'mouth')];
 const smile=cleanedStrokes(face);assert.equal(smile?.kind,'smiley face');assert.equal(smile.elements.length,4);assert.deepEqual(smile.elements.map(e=>e.id),face.map(e=>e.id));
 const corners=[p(0,0),p(100,0),p(100,100),p(0,100),p(0,0)];
 const box=cleanedStrokes(corners.slice(0,4).map((v,i)=>stroke([v,corners[i+1]],`side-${i}`)));
 assert.equal(box?.kind,'box');assert.equal(new Set(box.elements.map(e=>e.id)).size,4);
 assert.equal(cleanedStrokes([{...face[0],locked:true}]),null);
 const arrow=cleanedStrokes([stroke([p(0,50),p(100,50)],'shaft'),stroke([p(100,50),p(75,25)],'wing1'),stroke([p(100,50),p(75,75)],'wing2')]);assert.equal(arrow?.kind,'arrow');
});

test('undo first restores the original sketch, then removes its creation',()=>{
 const rough=stroke([p(0,0),p(50,2),p(100,0)]),perfect=cleanedStrokes([rough]).elements[0],history=new BoardHistory();
 const empty={elements:{}},raw={elements:{s:rough}},clean={elements:{s:perfect}};
 history.begin('draw stroke');history.record(empty,raw);history.end();history.begin('clean up shape');history.record(raw,clean);history.end();
 const undo=history.plan(clean,'undo');assert.equal(undo.ops[0].type,'patch');applyOperation(clean,undo.ops[0]);history.accept('undo',undo);assert.deepEqual(clean.elements.s.points,rough.points);
 const erase=history.plan(clean,'undo');applyOperation(clean,erase.ops[0]);assert.deepEqual(clean.elements,{});
});

test('draw grouping encloses complete unlocked strokes and leaves notes untouched',()=>{
 const a=stroke([p(10,10),p(30,30)],'a'),b=stroke([p(10,10),p(120,20)],'b');
 assert.deepEqual(enclosedStrokes([a,b,{...a,id:'locked',locked:true},{...a,id:'note',type:'note'}],{x:0,y:0,w:100,h:100}).map(e=>e.id),['a']);
 assert.ok(worldPoints(a).every(p=>p.x>=10&&p.y>=10));
 assert.equal(standardColors.length,60);assert.equal(new Set(standardColors).size,60);assert.ok(standardColors.every(c=>/^#[0-9a-f]{6}$/.test(c)));
});
