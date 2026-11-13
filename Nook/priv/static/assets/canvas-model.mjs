export const uid = () => crypto.randomUUID();
export const creationDefaults = {
  text:{w:360,h:80,font_size:18}, note:{w:320,h:200,font_size:16},
  shape:{w:230,h:180,font_size:16},task:{w:320,h:190,font_size:16},
  icon:{w:80,h:80,font_size:16},idea:{w:240,h:160,font_size:16},file:{w:230,h:120,font_size:16}
};
export function draftHeight(current, required) {return Math.min(10000,Math.max(current,required));}
export function placementAnchor(el) {
  const line=(el.font_size||(el.type==='text'?24:16))*1.55;
  if(el.type==='icon')return {x:el.w/2,y:el.h/2};
  if(el.type==='shape')return {x:el.w/2,y:el.h/2+(el.shape==='triangle'?17.5:0)};
  if(el.type==='task')return {x:66,y:29+Math.max(25,line)+line/2};
  if(el.type==='idea')return {x:el.w/2,y:21+line/2};
  const inset={text:[9,9],note:[23,24],task:[17,17],file:[13,13]}[el.type]||[0,0];
  return {x:inset[0],y:inset[1]+line/2};
}
export function edgePanVelocity(x,y,width,height,margin=64) {
  const axis=(p,size)=>{const band=Math.min(margin,size/3);if(p<band)return 800*Math.min(1,(band-p)/band)**2;if(p>size-band)return -800*Math.min(1,(p-size+band)/band)**2;return 0;};
  return {x:axis(x,width),y:axis(y,height)};
}
export const shapeTypes = ['rectangle', 'rounded', 'circle', 'triangle', 'diamond'];
export function shapeMarkup(kind = 'rounded') {
  const shapes = {
    rectangle: '<rect x="1" y="1" width="98" height="98"/>',
    rounded: '<rect x="1" y="1" width="98" height="98" rx="10"/>',
    circle: '<ellipse cx="50" cy="50" rx="49" ry="49"/>',
    triangle: '<polygon points="50,2 98,98 2,98"/>',
    diamond: '<polygon points="50,2 98,50 50,98 2,50"/>'
  };
  return shapes[kind] || shapes.rounded;
}
export function applyOperation(board, op) {
  if (op.type === 'batch') { for (const child of op.ops) applyOperation(board, child); return board; }
  if (op.type === 'put') board.elements[op.element.id] = structuredClone(op.element);
  if (op.type === 'patch' && board.elements[op.id]) board.elements[op.id] = {...board.elements[op.id], ...op.changes};
  if (op.element_revision && board.elements[op.id]) board.elements[op.id] = {...board.elements[op.id],revision:op.element_revision};
  if (op.type === 'delete') for (const [id, el] of Object.entries(board.elements)) {
    if (id === op.id || el.from === op.id || el.to === op.id) delete board.elements[id];
  }
  if (op.type === 'rename') board.title = op.title;
  return board;
}
export function screenToWorld(x, y, view) { return {x: (x - view.x) / view.z, y: (y - view.y) / view.z}; }
export function zoomAt(view, x, y, factor) {
  const p = screenToWorld(x, y, view);
  const z = Math.min(3, Math.max(.2, view.z * factor));
  return {x: x - p.x * z, y: y - p.y * z, z};
}
export function outlinePoint(box, toward, anchor) {
  if (anchor) return {x:box.x+box.w*anchor.x,y:box.y+box.h*anchor.y};
  const x=box.x+box.w/2,y=box.y+box.h/2,dx=toward.x-x,dy=toward.y-y;
  const rx=Math.max(1,box.w/2),ry=Math.max(1,box.h/2);
  let t;
  if(box.shape==='circle') t=1/Math.sqrt((dx/rx)**2+(dy/ry)**2||1);
  else if(box.shape==='diamond') t=1/(Math.abs(dx)/rx+Math.abs(dy)/ry||1);
  else if(box.shape==='triangle') {
    const vertices=[{x,y:box.y},{x:box.x+box.w,y:box.y+box.h},{x:box.x,y:box.y+box.h}];
    t=Infinity;
    for(let i=0;i<3;i++){
      const a=vertices[i],b=vertices[(i+1)%3],ex=b.x-a.x,ey=b.y-a.y,det=dx*ey-dy*ex;
      if(Math.abs(det)<1e-9)continue;
      const hit=((a.x-x)*ey-(a.y-y)*ex)/det,u=((a.x-x)*dy-(a.y-y)*dx)/det;
      if(hit>=0&&u>=0&&u<=1)t=Math.min(t,hit);
    }
    if(!Number.isFinite(t))t=0;
  } else t=Math.min(rx/(Math.abs(dx)||1e-9),ry/(Math.abs(dy)||1e-9));
  return {x:x+dx*t,y:y+dy*t};
}
export function connectionEndpoints(a,b,edge={}) {
  const center=box=>box.text_center||{x:box.x+box.w/2,y:box.y+box.h/2};
  const port=(box,other,anchor)=>{
    if(anchor||!box.text_center||box.shape)return outlinePoint(box,center(other),anchor);
    const c=center(box),t=center(other),dx=t.x-c.x,dy=t.y-c.y;
    return Math.abs(dx)/box.w>=Math.abs(dy)/box.h?
      {x:dx>=0?box.x+box.w:box.x,y:Math.max(box.y,Math.min(box.y+box.h,c.y))}:
      {x:Math.max(box.x,Math.min(box.x+box.w,c.x)),y:dy>=0?box.y+box.h:box.y};
  };
  return {start:port(a,b,edge.from_anchor),end:port(b,a,edge.to_anchor)};
}
export function curvePath(start,end) {
  const dx=end.x-start.x,dy=end.y-start.y;
  if(Math.abs(dx)>=Math.abs(dy)){
    const bend=Math.min(240,Math.abs(dx)*.45)*Math.sign(dx||1);
    return `M ${start.x} ${start.y} C ${start.x+bend} ${start.y}, ${end.x-bend} ${end.y}, ${end.x} ${end.y}`;
  }
  const bend=Math.min(240,Math.abs(dy)*.45)*Math.sign(dy||1);
  return `M ${start.x} ${start.y} C ${start.x} ${start.y+bend}, ${end.x} ${end.y-bend}, ${end.x} ${end.y}`;
}
// Visibility routing uses padded boxes; rounding stays inside that safety margin.
export function segmentBlocked(a,b,box) {
  let lo=0,hi=1;
  for(const [p,d,min,max] of [[a.x,b.x-a.x,box.x+1e-6,box.x+box.w-1e-6],[a.y,b.y-a.y,box.y+1e-6,box.y+box.h-1e-6]]){
    if(Math.abs(d)<1e-9){if(p<min||p>max)return false;continue;}
    const t1=(min-p)/d,t2=(max-p)/d;lo=Math.max(lo,Math.min(t1,t2));hi=Math.min(hi,Math.max(t1,t2));if(lo>hi)return false;
  }
  return hi>=0&&lo<=1;
}
export function routePoints(start,end,obstacles) {
  const inside=(p,r)=>p.x>r.x&&p.x<r.x+r.w&&p.y>r.y&&p.y<r.y+r.h;
  const boxes=obstacles.map(r=>({x:r.x-24,y:r.y-24,w:r.w+48,h:r.h+48})).filter(r=>!inside(start,r)&&!inside(end,r));
  const clear=(a,b)=>!boxes.some(r=>segmentBlocked(a,b,r));
  if(clear(start,end))return [start,end];
  const points=[start,end,...boxes.flatMap(r=>[{x:r.x,y:r.y},{x:r.x+r.w,y:r.y},{x:r.x+r.w,y:r.y+r.h},{x:r.x,y:r.y+r.h}]).filter(p=>!boxes.some(r=>inside(p,r)))];
  const cost=points.map(()=>Infinity),previous=[],visited=new Set();cost[0]=0;
  while(true){
    let next=-1,best=Infinity;for(let i=0;i<points.length;i++)if(!visited.has(i)&&cost[i]<Infinity){const score=cost[i]+Math.hypot(points[i].x-end.x,points[i].y-end.y);if(score<best){next=i;best=score;}}
    if(next<0)return [start,end];if(next===1)break;visited.add(next);
    for(let i=1;i<points.length;i++)if(!visited.has(i)&&clear(points[next],points[i])){const distance=cost[next]+Math.hypot(points[next].x-points[i].x,points[next].y-points[i].y);if(distance<cost[i]){cost[i]=distance;previous[i]=next;}}
  }
  const route=[];for(let i=1;i!==undefined;i=previous[i])route.push(points[i]);return route.reverse();
}
export function roundedRoute(points) {
  let d=`M ${points[0].x} ${points[0].y}`;
  for(let i=1;i<points.length-1;i++){
    const a=points[i-1],b=points[i],c=points[i+1],ab=Math.hypot(b.x-a.x,b.y-a.y),bc=Math.hypot(c.x-b.x,c.y-b.y),r=Math.min(12,ab/3,bc/3);
    const before={x:b.x+(a.x-b.x)*r/ab,y:b.y+(a.y-b.y)*r/ab},after={x:b.x+(c.x-b.x)*r/bc,y:b.y+(c.y-b.y)*r/bc};
    d+=` L ${before.x} ${before.y} Q ${b.x} ${b.y} ${after.x} ${after.y}`;
  }
  const end=points.at(-1);return d+` L ${end.x} ${end.y}`;
}
export function connectionPath(a,b,edge={},obstacles=[]) {
  const {start,end}=connectionEndpoints(a,b,edge),direct=curvePath(start,end);
  if(!obstacles.length)return direct;
  const numbers=direct.match(/-?\d+(?:\.\d+)?(?:e[+-]?\d+)?/gi).map(Number),samples=[];
  for(let i=0;i<=32;i++){const t=i/32,u=1-t;samples.push({x:u**3*numbers[0]+3*u*u*t*numbers[2]+3*u*t*t*numbers[4]+t**3*numbers[6],y:u**3*numbers[1]+3*u*u*t*numbers[3]+3*u*t*t*numbers[5]+t**3*numbers[7]});}
  const padded=obstacles.map(r=>({x:r.x-12,y:r.y-12,w:r.w+24,h:r.h+24}));
  if(!samples.slice(1).some((p,i)=>padded.some(r=>segmentBlocked(samples[i],p,r))))return direct;
  return roundedRoute(routePoints(start,end,obstacles));
}
export function selectionBounds(elements) {
  const boxes=elements.filter(e=>e&&e.type!=='connection');if(!boxes.length)return null;
  const x=Math.min(...boxes.map(e=>e.x)),y=Math.min(...boxes.map(e=>e.y));
  return {x,y,w:Math.max(...boxes.map(e=>e.x+e.w))-x,h:Math.max(...boxes.map(e=>e.y+e.h))-y};
}
export function intersects(a,b) {return a.x<=b.x+b.w&&a.x+a.w>=b.x&&a.y<=b.y+b.h&&a.y+a.h>=b.y;}
export function expandGroups(elements, ids) {
  const result=new Set(ids),groups=new Set(ids.map(id=>elements[id]?.group_id).filter(Boolean));
  for(const el of Object.values(elements))if(groups.has(el.group_id))result.add(el.id);
  return result;
}
export function taskItems(el) {return el.items||[{id:'legacy',text:el.text||'',done:!!el.done}];}
export function smoothWheelFactor(delta,mode=0,pinch=false) {
  const pixels=delta*(mode===1?16:mode===2?600:1);
  return Math.exp(-Math.max(-120,Math.min(120,pixels))*(pinch ? .008 : .0006));
}

export function fitResizedCard(original,changes,displayedHeight){
  if(original.type==='shape'||!('h' in changes))return changes;
  return {...changes,h:Math.min(10000,Math.max(changes.h,displayedHeight||0))};
}

export function connectionPorts(box){
 const center=box.text_center||{x:box.x+box.w/2,y:box.y+box.h/2},x=Math.max(0,Math.min(1,(center.x-box.x)/box.w)),y=Math.max(0,Math.min(1,(center.y-box.y)/box.h));
 return [['left',0,y],['right',1,y],['top',x,0],['bottom',x,1]].map(([side,ax,ay])=>{if(box.shape){const p=outlinePoint(box,{x:box.x+ax*box.w,y:box.y+ay*box.h});ax=(p.x-box.x)/box.w;ay=(p.y-box.y)/box.h;}return {side,x:ax,y:ay};});
}
