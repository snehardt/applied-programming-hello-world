import {test} from 'node:test';
import assert from 'node:assert/strict';
import {applyOperation,screenToWorld,zoomAt,connectionPath,shapeMarkup,shapeTypes} from '../priv/static/assets/canvas-model.mjs';
import {outlinePoint,connectionEndpoints,selectionBounds,intersects,expandGroups,taskItems,smoothWheelFactor} from '../priv/static/assets/canvas-model.mjs';
import {placementAnchor,edgePanVelocity} from '../priv/static/assets/canvas-model.mjs';
import {creationDefaults,draftHeight} from '../priv/static/assets/canvas-model.mjs';

test('new text and notes start wider with readable smaller text',()=>{
  assert.equal(creationDefaults.text.w,360);assert.equal(creationDefaults.text.font_size,18);
  assert.equal(creationDefaults.note.w,320);assert.equal(creationDefaults.note.font_size,16);
});
test('live draft height expands to fit new lines without shrinking during typing',()=>{
  assert.equal(draftHeight(80,132),132);assert.equal(draftHeight(132,70),132);
  assert.equal(draftHeight(200,15000),10000);
});

test('edge panning accelerates toward each edge and stays still in the center',()=>{
  assert.deepEqual(edgePanVelocity(500,300,1000,600),{x:0,y:0});
  assert.equal(edgePanVelocity(0,300,1000,600).x,800);
  assert.equal(edgePanVelocity(1000,300,1000,600).x,-800);
  assert.equal(edgePanVelocity(500,0,1000,600).y,800);
  assert.equal(edgePanVelocity(500,600,1000,600).y,-800);
  assert.ok(edgePanVelocity(20,300,1000,600).x>edgePanVelocity(40,300,1000,600).x);
  assert.deepEqual(edgePanVelocity(2000,2000,1000,600),{x:-800,y:-800});
});
test('tool placement anchors the text caret rather than the outer box at every zoom',()=>{
  for(const type of ['text','note','shape','task','idea','file']){
    const el={type,w:230,h:200,font_size:type==='text'?24:16};const anchor=placementAnchor(el);
    for(const z of [.2,1,3]){const view={x:120,y:-80,z},pointer={x:450,y:280},world=screenToWorld(pointer.x,pointer.y,view);const origin={x:world.x-anchor.x,y:world.y-anchor.y};
      assert.ok(Math.abs((origin.x+anchor.x)*z+view.x-pointer.x)<1e-8);
      assert.ok(Math.abs((origin.y+anchor.y)*z+view.y-pointer.y)<1e-8);
    }
    assert.ok(anchor.x>0&&anchor.y>0);
  }
});
test('stationary edge pan keeps a dragged object under its grab point as the viewport moves',()=>{
  const view={x:0,y:0,z:.5},pointer={x:990,y:300};const before=screenToWorld(pointer.x,pointer.y,view),velocity=edgePanVelocity(pointer.x,pointer.y,1000,600);
  const next={...view,x:view.x+velocity.x*.5},after=screenToWorld(pointer.x,pointer.y,next);
  assert.ok(after.x>before.x);assert.equal(after.x*next.z+next.x,pointer.x);
});

test('connection outlines follow circles, diamonds and triangles with finite reversed and vertical curves',()=>{
  const circle={x:0,y:0,w:200,h:100,shape:'circle'};
  const p=outlinePoint(circle,{x:300,y:150});
  assert.ok(Math.abs(((p.x-100)/100)**2+((p.y-50)/50)**2-1)<1e-8);
  const d=outlinePoint({...circle,shape:'diamond'},{x:300,y:150});
  assert.ok(Math.abs(Math.abs(d.x-100)/100+Math.abs(d.y-50)/50-1)<1e-8);
  const t=outlinePoint({...circle,shape:'triangle'},{x:100,y:-100});assert.equal(t.y,0);
  for(const other of [{x:-400,y:10,w:200,h:100},{x:0,y:400,w:200,h:100},circle])assert.doesNotMatch(connectionPath(circle,other),/NaN|Infinity/);
  const ends=connectionEndpoints(circle,{x:300,y:0,w:100,h:100},{from_anchor:{x:.5,y:1}});assert.deepEqual(ends.start,{x:100,y:100});
});
test('marquee intersections expand persisted groups without selecting unrelated objects',()=>{
  const elements={a:{id:'a',x:0,y:0,w:100,h:100,group_id:'g'},b:{id:'b',x:300,y:0,w:100,h:100,group_id:'g'},c:{id:'c',x:700,y:0,w:100,h:100}};
  const hit=Object.values(elements).filter(el=>intersects(el,{x:20,y:20,w:10,h:10})).map(el=>el.id);
  assert.deepEqual([...expandGroups(elements,hit)],['a','b']);assert.deepEqual(selectionBounds([elements.a,elements.b]),{x:0,y:0,w:400,h:100});
});
test('fine wheel zoom is proportional and small while legacy checklists remain readable',()=>{
  assert.ok(smoothWheelFactor(-1)>1&&smoothWheelFactor(-1)<1.001);
  assert.ok(smoothWheelFactor(-100)<1.07);assert.equal(smoothWheelFactor(0),1);
  assert.deepEqual(taskItems({text:'Keep old task',done:true}),[{id:'legacy',text:'Keep old task',done:true}]);
});
test('zoom stays anchored under the pointer, even at limits',()=>{
  const before={x:130,y:-75,z:.8},point={x:420,y:360};
  for(const factor of [.1,.8,1.5,100]){
    const next=zoomAt(before,point.x,point.y,factor);
    const a=screenToWorld(point.x,point.y,before),b=screenToWorld(point.x,point.y,next);
    assert.ok(Math.abs(a.x-b.x)<1e-9&&Math.abs(a.y-b.y)<1e-9);assert.ok(next.z>=.2&&next.z<=3);
  }
});
test('deleting a node removes only its connections; patches preserve other fields',()=>{
  const board={elements:{a:{id:'a',text:'Keep me',x:0},b:{id:'b'},c:{id:'c',from:'a',to:'b'}}};
  applyOperation(board,{type:'patch',id:'a',changes:{x:42}});assert.equal(board.elements.a.text,'Keep me');
  applyOperation(board,{type:'delete',id:'b'});assert.deepEqual(Object.keys(board.elements),['a']);
});
test('connections meet element boundaries and remain finite for aligned elements',()=>{
  const a={x:0,y:0,w:200,h:100},b={x:400,y:0,w:200,h:100};
  assert.match(connectionPath(a,b),/^M 200 50 C .* 400 50$/);
  assert.doesNotMatch(connectionPath(a,{...b,x:0,y:300}),/NaN|Infinity/);
});
test('shapes use a fixed SVG vocabulary and never interpolate arbitrary markup',()=>{
  for(const kind of shapeTypes)assert.match(shapeMarkup(kind),/^<(rect|ellipse|polygon) /);
  assert.equal(shapeMarkup('<script>'),shapeMarkup('rounded'));
});
test('appearance, task details, sizes and layers survive serializing the board',()=>{
  const board={elements:{}};
  applyOperation(board,{type:'put',element:{id:'a',type:'shape',shape:'triangle',w:200,h:160,z:3}});
  applyOperation(board,{type:'patch',id:'a',changes:{color:'mint',w:320,z:4}});
  const saved=JSON.parse(JSON.stringify(board));
  assert.deepEqual(saved.elements.a,{id:'a',type:'shape',shape:'triangle',w:320,h:160,z:4,color:'mint'});
});


test('text-centered ports meet the box border and retain explicit anchors',()=>{
  const a={x:0,y:0,w:200,h:180,text_center:{x:40,y:30}},b={x:500,y:0,w:200,h:180,text_center:{x:550,y:45}};
  assert.deepEqual(connectionEndpoints(a,b),{start:{x:200,y:30},end:{x:500,y:45}});
  assert.deepEqual(connectionEndpoints(a,b,{from_anchor:{x:1,y:.5}}).start,{x:200,y:90});
  assert.deepEqual(connectionEndpoints(a,{...b,x:0,y:500,text_center:{x:50,y:530}}).start,{x:40,y:180});
});

test('rounded connections detour around multiple obstacles in either direction',async()=>{
  const {routePoints,segmentBlocked}=await import('../priv/static/assets/canvas-model.mjs');
  const obstacles=[{x:200,y:-50,w:120,h:180},{x:400,y:-100,w:100,h:140}];
  for(const [start,end] of [[{x:100,y:0},{x:650,y:0}],[{x:650,y:0},{x:100,y:0}],[{x:250,y:-200},{x:250,y:300}]]){
    const points=routePoints(start,end,obstacles);assert.deepEqual(points[0],start);assert.deepEqual(points.at(-1),end);assert.ok(points.length>2);
    for(let i=1;i<points.length;i++)for(const box of obstacles)assert.equal(segmentBlocked(points[i-1],points[i],box),false);
  }
  const a={x:0,y:-50,w:100,h:100},b={x:650,y:-50,w:100,h:100};
  assert.match(connectionPath(a,b,{},obstacles),/ Q /);assert.doesNotMatch(connectionPath(a,b,{},obstacles),/NaN|Infinity/);
  assert.match(connectionPath(a,b,{},[{x:250,y:500,w:100,h:100}]),/ C /);
});

test('manual card resizing fits wrapped content while shape dimensions stay deliberate',async()=>{const {fitResizedCard}=await import('../priv/static/assets/canvas-model.mjs');assert.deepEqual(fitResizedCard({type:'task'},{w:180,h:160},242),{w:180,h:242});assert.deepEqual(fitResizedCard({type:'note'},{w:320,h:100},100),{w:320,h:100});assert.deepEqual(fitResizedCard({type:'shape'},{w:120,h:80},242),{w:120,h:80});});

test('connection ports follow actual shape outlines including sloped triangle edges',async()=>{const {connectionPorts}=await import('../priv/static/assets/canvas-model.mjs');const triangle={x:0,y:0,w:200,h:180,shape:'triangle'};for(const p of connectionPorts(triangle)){assert.ok(Number.isFinite(p.x)&&Number.isFinite(p.y));if(p.side==='left')assert.ok(Math.abs(p.x-(1-p.y)/2)<1e-8);if(p.side==='right')assert.ok(Math.abs(p.x-(1+p.y)/2)<1e-8);}const circle={x:0,y:0,w:200,h:100,shape:'circle',text_center:{x:70,y:35}};for(const p of connectionPorts(circle))assert.ok(Math.abs(((p.x-.5)/.5)**2+((p.y-.5)/.5)**2-1)<1e-8);});


test('connection targets exclude loose text and stale one-item groups',async()=>{
 const {canConnectElement}=await import('../priv/static/assets/canvas-model.mjs');
 const text={id:'t',type:'text',group_id:'g'},note={id:'n',type:'note',group_id:'g'};
 assert.equal(canConnectElement({...text,group_id:null},{t:text,n:note}),false);
 assert.equal(canConnectElement(text,{t:text}),false);
 assert.equal(canConnectElement(text,{t:text,n:note}),true);
 assert.equal(canConnectElement(note,{n:note}),true);
 assert.equal(canConnectElement({id:'c',type:'connection'},{}),false);
 const drawing={id:'s',type:'stroke',group_id:'g'};assert.equal(canConnectElement(drawing,{s:drawing,n:note}),false);
});
