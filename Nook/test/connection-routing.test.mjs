import test from 'node:test';
import assert from 'node:assert/strict';
import {connectionGeometry,segmentBlocked} from '../priv/static/assets/canvas-model.mjs';
const pointsOnPath=path=>{let cursor,points=[];for(const [,command,args]of path.matchAll(/([MLQC])([^MLQC]+)/g)){const n=args.match(/-?\d+(?:\.\d+)?(?:e[+-]?\d+)?/gi).map(Number),end={x:n.at(-2),y:n.at(-1)};if(command==='M'){cursor=end;points.push(end);continue;}for(let i=1;i<=40;i++){const t=i/40,u=1-t;points.push(command==='L'?{x:cursor.x*u+end.x*t,y:cursor.y*u+end.y*t}:command==='Q'?{x:u*u*cursor.x+2*u*t*n[0]+t*t*end.x,y:u*u*cursor.y+2*u*t*n[1]+t*t*end.y}:{x:u**3*cursor.x+3*u*u*t*n[0]+3*u*t*t*n[2]+t**3*end.x,y:u**3*cursor.y+3*u*u*t*n[1]+3*u*t*t*n[3]+t**3*end.y});}cursor=end;}return points;};
test('floating connections can approach diagonally with their final tangent aimed at the object',()=>{
 const a={x:0,y:0,w:100,h:100},b={x:600,y:300,w:180,h:120},route=connectionGeometry(a,b),samples=pointsOnPath(route.path),p=samples.at(-2),tip=samples.at(-1),center={x:b.x+b.w/2,y:b.y+b.h/2};
 assert.ok(Math.abs((tip.x-p.x)*(center.y-tip.y)-(tip.y-p.y)*(center.x-tip.x))<1e-6);assert.notEqual(route.end.y,b.y);assert.notEqual(route.end.y,b.y+b.h);assert.doesNotMatch(route.path,/NaN|Infinity/);
});
test('broad rounded detours avoid objects and keep an inward-pointing final segment',()=>{
 const a={x:0,y:0,w:100,h:100},b={x:700,y:0,w:100,h:100},obstacles=[{x:270,y:-50,w:170,h:220}],route=connectionGeometry(a,b,{},obstacles),samples=pointsOnPath(route.path);
 assert.match(route.path,/ Q /);for(let i=1;i<samples.length;i++)for(const box of obstacles)assert.equal(segmentBlocked(samples[i-1],samples[i],box),false);
 const p=samples.at(-2),tip=samples.at(-1),center={x:750,y:50};assert.ok(Math.abs((tip.x-p.x)*(center.y-tip.y)-(tip.y-p.y)*(center.x-tip.x))<1e-6);
});

test('an obstacle close to the starting card is still avoided',()=>{
 const a={x:0,y:0,w:100,h:100},b={x:700,y:0,w:100,h:100},obstacle={x:120,y:-50,w:200,h:200},points=pointsOnPath(connectionGeometry(a,b,{},[obstacle]).path);
 for(let i=1;i<points.length;i++)assert.equal(segmentBlocked(points[i-1],points[i],obstacle),false);
});
