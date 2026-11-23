import test from 'node:test';
import assert from 'node:assert/strict';
import {rotatePoint,itemCenter,rotationChanges,angleStep} from '../priv/static/assets/rotation.mjs';
import {selectionBounds,connectionEndpoints,connectionPorts} from '../priv/static/assets/canvas-model.mjs';
const close=(a,b)=>assert.ok(Math.abs(a-b)<1e-7,`${a} != ${b}`);
test('rotation unwraps forward and backward through multiple full turns',()=>{
 let angle=-90,total=0;for(let i=1;i<=100;i++){const next=((-90+i*10+180)%360)-180;total+=angleStep(angle,next);angle=next;}close(total,1000);
 angle=90;total=0;for(let i=1;i<=100;i++){const next=((90-i*10+180)%360+360)%360-180;total+=angleStep(angle,next);angle=next;}close(total,-1000);
});
test('group rotation preserves distances and supports angles past 360',()=>{
 const a={x:0,y:0,w:100,h:60,rotation:20},b={x:200,y:100,w:50,h:80,rotation:-15},center=itemCenter(selectionBounds([a,b]));
 const aa={...a,...rotationChanges(a,center,810)},bb={...b,...rotationChanges(b,center,810)};
 close(Math.hypot(itemCenter(a).x-itemCenter(b).x,itemCenter(a).y-itemCenter(b).y),Math.hypot(itemCenter(aa).x-itemCenter(bb).x,itemCenter(aa).y-itemCenter(bb).y));
 assert.equal(aa.rotation,830);assert.equal(bb.rotation,795);
 const restored={...aa,...rotationChanges(aa,center,-810)};close(restored.x,a.x);close(restored.y,a.y);
});
test('selection and fit bounds include rotated corners',()=>{
 const box=selectionBounds([{x:0,y:0,w:200,h:100,rotation:90}]);close(box.x,50);close(box.y,-50);close(box.w,100);close(box.h,200);
});
test('connection anchors follow rotated item borders and local shape ports',()=>{
 const a={x:0,y:0,w:200,h:100,rotation:90},b={x:400,y:0,w:100,h:100};
 const {start}=connectionEndpoints(a,b,{from_anchor:{x:1,y:.5}});close(start.x,100);close(start.y,150);
 const auto=connectionEndpoints(a,b).start;close(auto.x,150);close(auto.y,50);
 const shape={...a,shape:'triangle'},port=connectionPorts(shape).find(p=>p.side==='right'),local=connectionPorts({...shape,rotation:0}).find(p=>p.side==='right');assert.deepEqual(port,local);
 const expected=rotatePoint({x:a.x+port.x*a.w,y:a.y+port.y*a.h},itemCenter(a),90),actual=connectionEndpoints(shape,b,{from_anchor:port}).start;close(expected.x,actual.x);close(expected.y,actual.y);
});
import {makeStroke,enclosedStrokes} from '../priv/static/assets/drawing.mjs';
import {cleanedStrokes,worldPoints} from '../priv/static/assets/drawing-shapes.mjs';
import {BoardHistory} from '../priv/static/assets/history.mjs';
import {applyOperation} from '../priv/static/assets/canvas-model.mjs';
test('rotated stroke grouping and cleanup use the visible ink',()=>{
 const stroke={...makeStroke([{x:0,y:0},{x:100,y:1},{x:200,y:0}],'#210a3b',4,'s',0),rotation:90};
 const points=worldPoints(stroke);close(points[0].x,points.at(-1).x);
 const cleaned=cleanedStrokes([stroke]).elements[0];assert.equal(cleaned.rotation,0);
 const cleanPoints=worldPoints(cleaned);close(cleanPoints[0].x,cleanPoints.at(-1).x);
 const box=selectionBounds([stroke]);assert.equal(enclosedStrokes([stroke],box).length,1);
 assert.equal(enclosedStrokes([stroke],{x:stroke.x,y:stroke.y,w:stroke.w,h:stroke.h}).length,0);
});
test('undo and redo restore a group rotation atomically, including legacy items',()=>{
 const original={elements:{a:{id:'a',type:'note',x:0,y:0,w:100,h:100,z:0},b:{id:'b',type:'icon',x:200,y:0,w:80,h:80,rotation:-45,z:0}}},board=structuredClone(original),history=new BoardHistory(),center=itemCenter(selectionBounds(Object.values(board.elements)));
 for(const el of Object.values(board.elements))applyOperation(board,{type:'patch',id:el.id,changes:rotationChanges(el,center,810)});
 const rotated=structuredClone(board);history.record(original,board,'rotate');const undo=history.plan(board,'undo');for(const op of undo.ops)applyOperation(board,op);history.accept('undo',undo);assert.deepEqual(board,original);
 const redo=history.plan(board,'redo');for(const op of redo.ops)applyOperation(board,op);assert.deepEqual(board,rotated);
});
