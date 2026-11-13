import {test} from 'node:test';
import assert from 'node:assert/strict';
import {makeStroke,strokePath,MAX_STROKE_POINTS,simplifyStroke} from '../priv/static/assets/drawing.mjs';
import {BoardHistory} from '../priv/static/assets/history.mjs';
import {applyOperation} from '../priv/static/assets/canvas-model.mjs';

test('dots and negative-coordinate strokes have padded selectable geometry',()=>{
 const dot=makeStroke([{x:-20,y:50}],'#210a3b',4,'dot',1);
 assert.equal(dot.w,50);assert.equal(dot.h,50);
 assert.equal(dot.x+dot.points[0][0]*dot.w,-20);
 assert.match(strokePath(dot.points,dot.w,dot.h),/l .01 .01/);
 const stroke=makeStroke([{x:0,y:1},{x:30,y:50},{x:80,y:10}],'#ffffff',12,'line',2);
 assert.match(strokePath(stroke.points,stroke.w,stroke.h),/ Q /);
 assert.ok(stroke.points.every(p=>p.every(v=>v>=0&&v<=1)));
 assert.equal(makeStroke([{x:0,y:0},{x:10001,y:2}],'#210a3b',4,'big',1),null);
 assert.equal(makeStroke(Array.from({length:3000},(_,x)=>({x,y:0})),'#210a3b',1,'bounded',1).points.length,MAX_STROKE_POINTS);
});

test('a completed stroke uses existing board operations without losing its point data',()=>{
 const board={elements:{}},stroke=makeStroke([{x:5,y:8},{x:50,y:60}],'#ad7bfa',4,'s',1);
 applyOperation(board,{type:'put',element:stroke});
 applyOperation(board,{type:'patch',id:'s',changes:{x:20,w:200}});
 assert.deepEqual(board.elements.s.points,stroke.points);
 assert.deepEqual(JSON.parse(JSON.stringify(board)).elements.s.points,stroke.points);
 applyOperation(board,{type:'delete',id:'s'});assert.equal(Object.keys(board.elements).length,0);
});

test('simplifying removes redundant samples but keeps corners and one-stroke history',()=>{
 const points=[{x:0,y:0},{x:1,y:0},{x:2,y:0},{x:2,y:10}];
 assert.deepEqual(simplifyStroke(points),[points[0],points[2],points[3]]);
 const stroke=makeStroke(simplifyStroke(points),'#210a3b',4,'s',1),before={elements:{}},after={elements:{s:stroke}},history=new BoardHistory();
 history.begin('draw stroke');history.record(before,after);history.end();assert.equal(history.undo.length,1);
 const undo=history.plan(after,'undo');assert.equal(undo.ops.length,1);applyOperation(after,undo.ops[0]);history.accept('undo',undo);assert.deepEqual(after.elements,{});
 const redo=history.plan(after,'redo');applyOperation(after,redo.ops[0]);assert.deepEqual(after.elements.s.points,stroke.points);
});
