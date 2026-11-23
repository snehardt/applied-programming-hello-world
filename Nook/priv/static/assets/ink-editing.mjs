import {rotatePoint,itemCenter} from './rotation.mjs';

export const distanceToSegment=(p,a,b)=>{
  const dx=b.x-a.x,dy=b.y-a.y,t=Math.max(0,Math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/(dx*dx+dy*dy||1)));
  return Math.hypot(p.x-a.x-t*dx,p.y-a.y-t*dy);
};
// Match the rendered quadratic path for legacy/smoothed strokes; raw ink stays raw.
export function inkPoints(el){
  const points=el.points.map(([x,y])=>rotatePoint({x:el.x+x*el.w,y:el.y+y*el.h},itemCenter(el),el.rotation||0));
  if(el.linear||points.length<3)return points;
  const out=[points[0]];let start=points[0];
  for(let i=1;i<points.length-1;i++){
    const control=points[i],end={x:(control.x+points[i+1].x)/2,y:(control.y+points[i+1].y)/2};
    const count=Math.min(256,Math.max(4,Math.ceil((Math.hypot(control.x-start.x,control.y-start.y)+Math.hypot(end.x-control.x,end.y-control.y))/2)));
    for(let j=1;j<=count;j++){const t=j/count,u=1-t;out.push({x:u*u*start.x+2*u*t*control.x+t*t*end.x,y:u*u*start.y+2*u*t*control.y+t*t*end.y});}start=end;
  }
  out.push(points.at(-1));return out;
}
export function insideLasso(p,polygon){
  let inside=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){
    const a=polygon[j],b=polygon[i];if(distanceToSegment(p,a,b)<1e-6)return true;
    if((a.y>p.y)!==(b.y>p.y)&&p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x)inside=!inside;
  }return inside;
}
export function lassoStrokes(elements,polygon){
  if(polygon.length<3)return [];
  const segmentInside=(a,b)=>{const cuts=[0,1],dx=b.x-a.x,dy=b.y-a.y;
    for(let i=0;i<polygon.length;i++){const c=polygon[i],d=polygon[(i+1)%polygon.length],ex=d.x-c.x,ey=d.y-c.y,det=dx*ey-dy*ex;if(Math.abs(det)<1e-12)continue;const t=((c.x-a.x)*ey-(c.y-a.y)*ex)/det,u=((c.x-a.x)*dy-(c.y-a.y)*dx)/det;if(t>0&&t<1&&u>=0&&u<=1)cuts.push(t);}
    cuts.sort((a,b)=>a-b);return cuts.slice(1).every((end,i)=>{const t=(cuts[i]+end)/2;return insideLasso({x:a.x+dx*t,y:a.y+dy*t},polygon);});
  };
  return elements.filter(el=>{if(el.type!=='stroke')return false;const points=inkPoints(el);return points.every(p=>insideLasso(p,polygon))&&points.slice(1).every((p,i)=>segmentInside(points[i],p));}).map(el=>el.id);
}
function circleInterval(a,b,c,r){
  const dx=b.x-a.x,dy=b.y-a.y,x=a.x-c.x,y=a.y-c.y,A=dx*dx+dy*dy,B=2*(x*dx+y*dy),C=x*x+y*y-r*r;
  if(!A)return C<=0?[0,1]:null;
  const d=B*B-4*A*C;if(d<0)return null;const root=Math.sqrt(d),lo=Math.max(0,(-B-root)/(2*A)),hi=Math.min(1,(-B+root)/(2*A));return lo<=hi?[lo,hi]:null;
}
// Find where an ink segment enters the swept circular eraser (a capsule).
function erasedIntervals(a,b,start,end,r){
  const intervals=[circleInterval(a,b,start,r),circleInterval(a,b,end,r)].filter(Boolean),dx=end.x-start.x,dy=end.y-start.y,len=Math.hypot(dx,dy);
  if(len){let lo=0,hi=1;const ux=dx/len,uy=dy/len;
    for(const [origin,delta,min,max] of [[(a.x-start.x)*ux+(a.y-start.y)*uy,(b.x-a.x)*ux+(b.y-a.y)*uy,0,len],[-(a.x-start.x)*uy+(a.y-start.y)*ux,-(b.x-a.x)*uy+(b.y-a.y)*ux,-r,r]]){
      if(Math.abs(delta)<1e-12){if(origin<min||origin>max){hi=-1;break;}}
      else {const t1=(min-origin)/delta,t2=(max-origin)/delta;lo=Math.max(lo,Math.min(t1,t2));hi=Math.min(hi,Math.max(t1,t2));}
    }if(lo<=hi)intervals.push([lo,hi]);
  }
  const merged=[];for(const interval of intervals.sort((a,b)=>a[0]-b[0])){const last=merged.at(-1);if(last&&interval[0]<=last[1]+1e-9)last[1]=Math.max(last[1],interval[1]);else merged.push([...interval]);}return merged;
}
export function eraseInk(points,start,end,radius){
  if(points.length===1)return distanceToSegment(points[0],start,end)<=radius?{changed:true,parts:[]}:{changed:false,parts:[points]};
  const parts=[];let part=[],changed=false;
  const at=(a,b,t)=>({x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t});
  const finish=()=>{if(part.length)parts.push(part);part=[];};
  for(let i=1;i<points.length;i++){
    const a=points[i-1],b=points[i],cuts=erasedIntervals(a,b,start,end,radius);let from=0;
    for(const [lo,hi] of cuts){if(hi-lo<1e-9)continue;changed=true;if(lo>from+1e-9){if(!part.length)part.push(at(a,b,from));part.push(at(a,b,lo));}finish();from=hi;}
    if(from<1-1e-9){if(!part.length)part.push(at(a,b,from));part.push(b);}else finish();
  }finish();return {changed,parts:changed?parts:[points]};
}

const preset=(name,color,width,mode='pen')=>({name,color,width,mode,smooth:false});
export function drawingDefaults(){return {color:'#210a3b',width:4,mode:'pen',smooth:false,touch:false,eraserSize:24,eraserType:'stroke',presets:[preset('Fine ink','#30293b',2),preset('Purple pen','#7640a8',4),preset('Yellow highlight','#e7b52b',18,'highlighter')]};}
const validPreset=p=>p&&/^#[0-9a-f]{6}$/i.test(p.color)&&Number.isInteger(p.width)&&p.width>=1&&p.width<=24&&['pen','highlighter'].includes(p.mode)&&typeof p.smooth==='boolean';
export function readDrawingSettings(storage){
  const defaults=drawingDefaults();try{const saved=JSON.parse(storage?.getItem('nook-drawing')||'null');if(!saved)return defaults;
    for(const key of ['color','width'])if(validPreset({...defaults,color:saved.color,width:saved.width}))defaults[key]=saved[key];
    if(['pen','highlighter','eraser','lasso'].includes(saved.mode))defaults.mode=saved.mode;
    for(const key of ['smooth','touch'])if(typeof saved[key]==='boolean')defaults[key]=saved[key];
    if(Number.isInteger(saved.eraserSize)&&saved.eraserSize>=4&&saved.eraserSize<=80)defaults.eraserSize=saved.eraserSize;
    if(['stroke','partial'].includes(saved.eraserType))defaults.eraserType=saved.eraserType;
    if(Array.isArray(saved.presets)){const presets=saved.presets.filter(validPreset).slice(-5).map(p=>({...p,name:typeof p.name==='string'?p.name.slice(0,40):'Favorite pen'}));if(presets.length)defaults.presets=presets;}
  }catch{}return defaults;
}
export function writeDrawingSettings(storage,settings){try{storage?.setItem('nook-drawing',JSON.stringify(settings));}catch{}}
