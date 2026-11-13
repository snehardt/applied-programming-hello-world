import {appendStandardColors} from './color-palette.mjs';
export const MAX_STROKE_POINTS=2048;
export function scheduleLineHold(getDraft,onStraighten,delay=650){
  return setTimeout(()=>{const draft=getDraft();if(!draft||draft.kind==='group'||draft.straight||draft.points.length<2||Math.hypot(draft.points.at(-1).x-draft.points[0].x,draft.points.at(-1).y-draft.points[0].y)<16)return;
    draft.raw=[...draft.points];draft.straight=true;draft.points=[draft.points[0],draft.points.at(-1)];onStraighten();
  },delay);
}
// Iterative simplification avoids deep recursion on long, scribbled strokes.
export function simplifyStroke(points,tolerance=.5){
  if(points.length<3)return points;
  const keep=new Set([0,points.length-1]),stack=[[0,points.length-1]];
  while(stack.length){const [a,b]=stack.pop(),start=points[a],end=points[b],dx=end.x-start.x,dy=end.y-start.y,length=dx*dx+dy*dy;let best=tolerance*tolerance,index=-1;
    for(let i=a+1;i<b;i++){const p=points[i],t=length?Math.max(0,Math.min(1,((p.x-start.x)*dx+(p.y-start.y)*dy)/length)):0,d=(p.x-start.x-t*dx)**2+(p.y-start.y-t*dy)**2;if(d>best){best=d;index=i;}}
    if(index!==-1){keep.add(index);stack.push([a,index],[index,b]);}
  }
  return points.filter((_,i)=>keep.has(i));
}
export function strokePath(points,w=1,h=1,linear=false){
  const p=points.map(([x,y])=>[x*w,y*h]);if(!p.length)return '';
  if(p.length===1)return `M ${p[0]} l .01 .01`;
  if(linear)return `M ${p[0]}`+p.slice(1).map(p=>` L ${p}`).join('');
  let d=`M ${p[0]}`;
  for(let i=1;i<p.length-1;i++)d+=` Q ${p[i]} ${(p[i][0]+p[i+1][0])/2},${(p[i][1]+p[i+1][1])/2}`;
  return d+` L ${p.at(-1)}`;
}
export function makeStroke(points,color,width,id,z){
  const xs=points.map(p=>p.x),ys=points.map(p=>p.y),pad=width/2+2;
  const x=Math.min(...xs)-pad,y=Math.min(...ys)-pad,w=Math.max(50,Math.max(...xs)-x+pad),h=Math.max(50,Math.max(...ys)-y+pad);
  if(w>10000||h>10000)return null;
  return {id,type:'stroke',linear:false,x,y,w,h,text:'',color,stroke_width:width,z,points:points.slice(0,MAX_STROKE_POINTS).map(p=>[(p.x-x)/w,(p.y-y)/h])};
}
export function strokeSvg(el){
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.classList.add('stroke-art');svg.setAttribute('viewBox',`0 0 ${el.w} ${el.h}`);svg.setAttribute('preserveAspectRatio','none');
  const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',strokePath(el.points,el.w,el.h,el.linear));path.setAttribute('fill','none');path.setAttribute('stroke',el.color);path.setAttribute('stroke-width',el.stroke_width);path.setAttribute('stroke-linecap','round');path.setAttribute('stroke-linejoin','round');svg.append(path);return svg;
}
export function installDrawing({root,canvas,world,listen,point,board,send,save,activate,uid,layer,toast,groupStrokes}){
  const controls=document.createElement('div');controls.className='draw-controls';controls.hidden=true;
  controls.innerHTML='<label>Ink <input aria-label="Drawing color" type="color" value="#210a3b"></label><label>Size <input aria-label="Brush size" type="range" min="1" max="24" value="4"><output>4</output></label><span>Escape to select</span>';
  const button=document.createElement('button');button.id='mode-draw';button.textContent='Draw';button.setAttribute('aria-pressed','false');root.querySelector('#mode-hand').after(button);root.append(controls);
  const paletteButton=document.createElement('button');paletteButton.textContent='Colors';paletteButton.setAttribute('aria-expanded','false');const palette=document.createElement('div');palette.className='draw-palette';palette.hidden=true;palette.setAttribute('aria-label','Drawing palette');controls.prepend(paletteButton);controls.append(palette);paletteButton.onclick=()=>{palette.hidden=!palette.hidden;paletteButton.setAttribute('aria-expanded',String(!palette.hidden));};
  const groupButton=document.createElement('button');groupButton.textContent='Group strokes';groupButton.setAttribute('aria-pressed','false');groupButton.title='Drag a box to group enclosed strokes';controls.append(groupButton);
  const status=controls.querySelector('span');status.setAttribute('role','status');
  const color=controls.querySelector('[type=color]'),width=controls.querySelector('[type=range]');width.oninput=()=>controls.querySelector('output').textContent=width.value;
  appendStandardColors(palette,value=>{color.value=value;palette.hidden=true;paletteButton.setAttribute('aria-expanded','false');});
  let grouping=false,holdTimer,enabled=false,draft=null,lastSend=0;
  groupButton.onclick=()=>{cancel();grouping=!grouping;groupButton.setAttribute('aria-pressed',String(grouping));status.textContent=grouping?'Drag a box around strokes':'Escape to select';};const remote=new Map();
  function setEnabled(value){cancel();enabled=value;controls.hidden=!value;palette.hidden=true;button.setAttribute('aria-pressed',String(value));canvas.classList.toggle('drawing-mode',value);if(value)activate();root.querySelector('#mode-select').setAttribute('aria-pressed',String(!value));}
  button.onclick=()=>setEnabled(!enabled);
  function clear(){clearTimeout(holdTimer);draft?.node.remove();draft=null;for(const node of world.querySelectorAll('.draw-group-candidate'))node.classList.remove('draw-group-candidate');status.textContent=grouping?'Drag a box around strokes':'Escape to select';}
  function armHold(){clearTimeout(holdTimer);holdTimer=scheduleLineHold(()=>draft,()=>{status.textContent='Straight line — move the endpoint, then release';preview();});}
  function groupBox(){const a=draft.start,b=draft.end;return {x:Math.min(a.x,b.x),y:Math.min(a.y,b.y),w:Math.abs(a.x-b.x),h:Math.abs(a.y-b.y)};}
  function groupPreview(){const b=groupBox();Object.assign(draft.node.style,{left:`${b.x}px`,top:`${b.y}px`,width:`${b.w}px`,height:`${b.h}px`});for(const node of world.querySelectorAll('.element.stroke')){const el=board().elements[node.dataset.id];node.classList.toggle('draw-group-candidate',enclosedStrokes([el],b).length>0);}}
  function cancel(){if(draft){if(draft.kind!=='group')send('drawing',{visible:false});clear();}}
  function preview(){if(!draft)return;const el=makeStroke(draft.points,draft.color,draft.width,draft.id,layer());if(!el)return;draft.node.replaceChildren(strokeSvg(el));Object.assign(draft.node.style,{left:`${el.x}px`,top:`${el.y}px`,width:`${el.w}px`,height:`${el.h}px`});
    if(performance.now()-lastSend>=66){lastSend=performance.now();const step=Math.max(1,Math.ceil(draft.points.length/127)),points=draft.points.filter((_,i)=>i%step===0);if(points.at(-1)!==draft.points.at(-1))points.push(draft.points.at(-1));send('drawing',{visible:true,color:draft.color,width:draft.width,points:points.map(p=>[p.x,p.y])});}}
  listen(canvas,'pointerdown',e=>{if(!enabled||e.button!==0||e.ctrlKey||e.metaKey||e.altKey||e.target.closest('dialog')||!board())return;e.preventDefault();e.stopImmediatePropagation();if(draft)return;const p=point(e);if(grouping){draft={kind:'group',pointer:e.pointerId,start:p,end:p,node:document.createElement('div')};draft.node.className='draw-group-box';world.append(draft.node);canvas.setPointerCapture(e.pointerId);return;}draft={id:uid(),pointer:e.pointerId,points:[p],color:color.value,width:Number(width.value),node:document.createElement('div')};draft.node.className='drawing-preview';world.append(draft.node);canvas.setPointerCapture(e.pointerId);preview();armHold();},{capture:true});
  listen(canvas,'pointermove',e=>{if(!draft||draft.pointer!==e.pointerId)return;e.preventDefault();const p=point(e);if(draft.kind==='group'){draft.end=p;groupPreview();return;}if(draft.straight){if(makeStroke([draft.points[0],p],draft.color,draft.width,draft.id,0)){draft.points=[draft.points[0],p];preview();}return;}const last=draft.points.at(-1);if(Math.hypot(p.x-last.x,p.y-last.y)<.75)return;
    const next=makeStroke([...draft.points,p],draft.color,draft.width,draft.id,0);if(draft.points.length>=MAX_STROKE_POINTS||!next){if(!draft.warned){toast('Stroke limit reached. Release to finish, then continue drawing.');draft.warned=true;}return;}draft.points.push(p);preview();armHold();},{capture:true});
  listen(canvas,'pointerup',e=>{if(!draft||draft.pointer!==e.pointerId)return;e.preventDefault();e.stopImmediatePropagation();if(draft.kind==='group'){const ids=enclosedStrokes(Object.values(board().elements),groupBox()).map(el=>el.id);clear();groupStrokes(ids);return;}const el=makeStroke(simplifyStroke(draft.raw||draft.points),draft.color,draft.width,draft.id,layer()),perfect=draft.straight?{...makeStroke(draft.points,draft.color,draft.width,draft.id,layer()),linear:true}:null;send('drawing',{visible:false});clear();if(el)save(el,perfect);},{capture:true});
  listen(canvas,'click',e=>{if(enabled&&e.button===0){e.preventDefault();e.stopImmediatePropagation();}},{capture:true});
  listen(canvas,'dblclick',e=>{if(enabled){e.preventDefault();e.stopImmediatePropagation();}},{capture:true});
  listen(canvas,'pointercancel',cancel);listen(canvas,'lostpointercapture',cancel);listen(window,'blur',cancel);
  listen(document,'keydown',e=>{if(e.key==='Escape'&&enabled)setEnabled(false);if(e.code==='Space'&&enabled&&!draft){setEnabled(false);}} ,{capture:true});
  listen(root,'pointerdown',e=>{if(enabled&&e.target.closest('[data-tool],#mode-select,#mode-hand'))setEnabled(false);},{capture:true});
  function receive(payload){const id=payload.id;remote.get(id)?.node.remove();remote.delete(id);if(!payload.visible)return;const el=makeStroke(payload.points.map(([x,y])=>({x,y})),payload.color,payload.width,id,0);if(!el)return;const node=document.createElement('div');node.className='drawing-preview remote-drawing';node.append(strokeSvg(el));Object.assign(node.style,{left:`${el.x}px`,top:`${el.y}px`,width:`${el.w}px`,height:`${el.h}px`});world.append(node);remote.set(id,{node,at:performance.now()});}
  const expiry=setInterval(()=>{for(const [id,value]of remote)if(performance.now()-value.at>4000){value.node.remove();remote.delete(id);}},1000);
  return {receive,disable:()=>{if(enabled)setEnabled(false);},dispose(){cancel();clearInterval(expiry);for(const value of remote.values())value.node.remove();controls.remove();button.remove();}};
}

export function enclosedStrokes(elements,b){return elements.filter(el=>el?.type==='stroke'&&!el.locked&&el.points.every(([x,y])=>{const px=el.x+x*el.w,py=el.y+y*el.h;return px>=b.x&&px<=b.x+b.w&&py>=b.y&&py<=b.y+b.h;}));}
