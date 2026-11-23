import {rotatePoint,itemCenter} from './rotation.mjs';
import {simplifyStroke,makeStroke} from './drawing.mjs?v=0.12.2';
const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const bounds=points=>{let x=Infinity,y=Infinity,right=-Infinity,bottom=-Infinity;for(const p of points){x=Math.min(x,p.x);y=Math.min(y,p.y);right=Math.max(right,p.x);bottom=Math.max(bottom,p.y);}return {x,y,w:right-x,h:bottom-y};};
export const worldPoints=el=>el.points.map(([x,y])=>rotatePoint({x:el.x+x*el.w,y:el.y+y*el.h},itemCenter(el),el.rotation||0));
const ellipse=(b,start=0,end=Math.PI*2,count=64)=>Array.from({length:count+1},(_,i)=>({x:b.x+b.w/2+Math.cos(start+(end-start)*i/count)*b.w/2,y:b.y+b.h/2+Math.sin(start+(end-start)*i/count)*b.h/2}));
function polygon(points,tolerance){let p=simplifyStroke([...points,points[0]],tolerance);p.pop();for(let pass=0;pass<3;pass++)p=p.filter((b,i)=>{const a=p[(i+p.length-1)%p.length],c=p[(i+1)%p.length],cross=Math.abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x));return distance(a,b)>tolerance&&cross/Math.max(1,distance(a,c))>tolerance;});return p;}
export function recognizeStroke(points){
 if(points.length<2)return null;const b=bounds(points),diag=Math.hypot(b.w,b.h);if(diag<16)return null;
 const closed=distance(points[0],points.at(-1))<Math.max(10,diag*.15);
 if(closed&&b.w>12&&b.h>12){
  const radial=points.map(p=>Math.hypot((p.x-b.x-b.w/2)/(b.w/2),(p.y-b.y-b.h/2)/(b.h/2)));
  const angles=new Set(points.map(p=>Math.floor((Math.atan2((p.y-b.y-b.h/2)/(b.h/2),(p.x-b.x-b.w/2)/(b.w/2))+Math.PI)*8/(Math.PI*2))));
  if(angles.size>=7&&radial.reduce((n,r)=>n+Math.abs(r-1),0)/points.length<.12)return {kind:'ellipse',points:ellipse(b)};
  const corners=polygon(points,diag*.045);
  if(corners.length===3){const top=corners.reduce((a,p)=>p.y<a.y?p:a),bottom=top.y<b.y+b.h*.4;const triangle=bottom?[{x:b.x+b.w/2,y:b.y},{x:b.x+b.w,y:b.y+b.h},{x:b.x,y:b.y+b.h}]:[{x:b.x,y:b.y},{x:b.x+b.w,y:b.y},{x:b.x+b.w/2,y:b.y+b.h}];return {kind:'triangle',points:[...triangle,triangle[0]]};}
  if(corners.length===4){const rect=[{x:b.x,y:b.y},{x:b.x+b.w,y:b.y},{x:b.x+b.w,y:b.y+b.h},{x:b.x,y:b.y+b.h}];if(corners.every(p=>rect.some(q=>distance(p,q)<diag*.19)))return {kind:'box',points:[...rect,rect[0]]};
   const diamond=[{x:b.x+b.w/2,y:b.y},{x:b.x+b.w,y:b.y+b.h/2},{x:b.x+b.w/2,y:b.y+b.h},{x:b.x,y:b.y+b.h/2}];if(corners.every(p=>diamond.some(q=>distance(p,q)<diag*.18)))return {kind:'diamond',points:[...diamond,diamond[0]]};}
  return null;
 }
 const simple=simplifyStroke(points,diag*.05);
 if(simple.length>=4&&simple.length<=6){const start=simple[0],tip=simple[1],shaft=distance(start,tip),near=simple.findIndex((p,i)=>i>=3&&distance(p,tip)<diag*.18);if(shaft>diag*.6&&near!==-1){const angle=Math.atan2(tip.y-start.y,tip.x-start.x),size=shaft*.25,wing=a=>({x:tip.x-Math.cos(a)*size,y:tip.y-Math.sin(a)*size});return {kind:'arrow',points:[start,tip,wing(angle-.55),tip,wing(angle+.55)]};}}
 const a=points[0],z=points.at(-1),span=distance(a,z);if(span>16){const dx=z.x-a.x,dy=z.y-a.y,error=points.reduce((sum,p)=>sum+Math.abs(dx*(a.y-p.y)-(a.x-p.x)*dy)/span,0)/points.length;if(error<span*.06)return {kind:'line',points:[a,z]};}
 return null;
}
export function cleanedStrokes(elements){
 if(!elements.length||elements.some(el=>el.type!=='stroke'||el.locked))return null;
 const sets=elements.map(worldPoints),all=sets.flat(),b=bounds(all),cx=b.x+b.w/2;
 if(elements.length===4){const outer=sets.findIndex(p=>recognizeStroke(p)?.kind==='ellipse'&&bounds(p).w>b.w*.8&&bounds(p).h>b.h*.8);if(outer!==-1){const inside=sets.map((p,i)=>({i,b:bounds(p)})).filter(p=>p.i!==outer),eyes=inside.filter(p=>p.b.y+p.b.h/2<b.y+b.h*.55&&p.b.w<b.w*.25&&p.b.h<b.h*.25),mouth=inside.find(p=>p.b.y>b.y+b.h*.48&&p.b.w>b.w*.2&&p.b.w<b.w*.9&&p.b.h<b.h*.4);
   if(eyes.length===2&&mouth&&eyes.some(p=>p.b.x<cx)&&eyes.some(p=>p.b.x>cx)){return {kind:'smiley face',elements:elements.map((el,i)=>{const box=i===outer?b:eyes.some(p=>p.i===i)?{x:b.x+b.w*(eyes.find(p=>p.i===i).b.x<cx?.3:.7)-b.w*.025,y:b.y+b.h*.34,w:b.w*.05,h:b.h*.05}:{x:b.x+b.w*.25,y:b.y+b.h*.48,w:b.w*.5,h:b.h*.5};return cleanElement(el,i===mouth.i?ellipse(box,0,Math.PI,24):ellipse(box));})};}
  }}
 if(elements.length===1){const result=recognizeStroke(sets[0]);return result?{kind:result.kind,elements:[cleanElement(elements[0],result.points)]}:null;}
 if(elements.length===3){
  const segments=sets.map(points=>simplifyStroke(points,Math.hypot(b.w,b.h)*.04));
  if(segments.every(points=>points.length===2)){
   const lengths=segments.map(points=>distance(...points)),shaft=lengths.indexOf(Math.max(...lengths)),others=[0,1,2].filter(i=>i!==shaft);
   for(const reverse of [false,true]){const start=segments[shaft][reverse?1:0],tip=segments[shaft][reverse?0:1],length=lengths[shaft],dx=(tip.x-start.x)/length,dy=(tip.y-start.y)/length;
    const ends=others.map(i=>{const [a,z]=segments[i];return distance(a,tip)<distance(z,tip)?{i,near:a,far:z}:{i,near:z,far:a};});
    if(ends.every(e=>distance(e.near,tip)<length*.18&&distance(e.far,tip)>length*.12&&distance(e.far,tip)<length*.65&&(e.far.x-tip.x)*dx+(e.far.y-tip.y)*dy < -length*.05)&&
       ((ends[0].far.x-tip.x)*dy-(ends[0].far.y-tip.y)*dx)*((ends[1].far.x-tip.x)*dy-(ends[1].far.y-tip.y)*dx)<0){
      const angle=Math.atan2(dy,dx),size=length*.28;return {kind:'arrow',elements:elements.map((el,i)=>{if(i===shaft)return cleanElement(el,[start,tip]);const end=ends.find(e=>e.i===i),side=((end.far.x-tip.x)*dy-(end.far.y-tip.y)*dx)>0?1:-1;return cleanElement(el,[tip,{x:tip.x-Math.cos(angle+side*.55)*size,y:tip.y-Math.sin(angle+side*.55)*size}]);})};
    }
   }
  }
 }
 // A box or triangle drawn with separate sides can be cleaned without replacing IDs.
 if(elements.length===3||elements.length===4){const remaining=sets.map((points,i)=>({i,points})),ordered=[remaining.shift()];while(remaining.length){const end=ordered.at(-1).points.at(-1);let best=0,reverse=false,gap=Infinity;remaining.forEach((entry,i)=>{for(const flip of [false,true]){const d=distance(end,flip?entry.points.at(-1):entry.points[0]);if(d<gap){gap=d;best=i;reverse=flip;}}});if(gap>Math.hypot(b.w,b.h)*.2)return null;const next=remaining.splice(best,1)[0];if(reverse)next.points=[...next.points].reverse();ordered.push(next);}
  const recognized=recognizeStroke(ordered.flatMap(e=>e.points));if(recognized&&['box','triangle','diamond'].includes(recognized.kind)&&recognized.points.length-1===elements.length){return {kind:recognized.kind,elements:ordered.map((entry,i)=>cleanElement(elements[entry.i],[recognized.points[i],recognized.points[i+1]]))};}}
 return null;
}
function cleanElement(el,points){const next=makeStroke(points,el.color,el.stroke_width,el.id,el.z||0);return {...el,...next,...(el.rotation?{rotation:0}:{}),linear:true};}
