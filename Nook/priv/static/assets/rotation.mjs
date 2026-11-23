export function rotatePoint(point,center,degrees){
  const angle=(degrees%360)*Math.PI/180,c=Math.cos(angle),s=Math.sin(angle),x=point.x-center.x,y=point.y-center.y;
  return {x:center.x+x*c-y*s,y:center.y+x*s+y*c};
}
export const itemCenter=el=>({x:el.x+el.w/2,y:el.y+el.h/2});
export function rotatedBounds(el){
  if(!el.rotation)return el;
  const center=itemCenter(el),points=[[0,0],[1,0],[1,1],[0,1]].map(([x,y])=>rotatePoint({x:el.x+x*el.w,y:el.y+y*el.h},center,el.rotation));
  const x=Math.min(...points.map(p=>p.x)),y=Math.min(...points.map(p=>p.y));
  return {...el,rotation:0,x,y,w:Math.max(...points.map(p=>p.x))-x,h:Math.max(...points.map(p=>p.y))-y};
}
export function rotationChanges(el,center,degrees){
  const next=rotatePoint(itemCenter(el),center,degrees);
  return {x:next.x-el.w/2,y:next.y-el.h/2,rotation:(el.rotation||0)+degrees};
}
// Unwrap each pointer step so crossing ±180° never reverses a full-turn gesture.
export const angleStep=(previous,next)=>((next-previous+540)%360)-180;
