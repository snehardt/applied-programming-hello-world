import {anchoredPanelPosition} from './visual-tools.mjs?v=0.12.2';
import {inkPoints,eraseInk,lassoStrokes,readDrawingSettings,writeDrawingSettings} from './ink-editing.mjs';
import {rotatePoint,itemCenter} from './rotation.mjs';
import {appendStandardColors} from './color-palette.mjs';
export const MAX_STROKE_POINTS=100000;
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
  if(!points.length||points.length>MAX_STROKE_POINTS)return null;
  let minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity;
  for(const p of points){minX=Math.min(minX,p.x);minY=Math.min(minY,p.y);maxX=Math.max(maxX,p.x);maxY=Math.max(maxY,p.y);}
  const pad=width/2+2,x=minX-pad,y=minY-pad,w=Math.max(50,maxX-x+pad),h=Math.max(50,maxY-y+pad);
  if(w>10000||h>10000)return null;
  return {id,type:'stroke',linear:true,x,y,w,h,text:'',color,stroke_width:width,z,points:points.map(p=>[(p.x-x)/w,(p.y-y)/h])};
}
export function strokeSvg(el){
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.classList.add('stroke-art');svg.setAttribute('viewBox',`0 0 ${el.w} ${el.h}`);svg.setAttribute('preserveAspectRatio','none');
  const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',strokePath(el.points,el.w,el.h,el.linear));svg.style.opacity=String(el.opacity??1);path.setAttribute('fill','none');path.setAttribute('stroke',el.color);path.setAttribute('stroke-width',el.stroke_width);path.setAttribute('stroke-linecap','round');path.setAttribute('stroke-linejoin','round');svg.append(path);return svg;
}
export function installDrawing({root,canvas,world,listen,point,board,send,save,activate,uid,layer,toast,groupStrokes,selectStrokes,eraseStrokes,getZoom=()=>1,canUseStroke=()=>true}){
  let storage;try{storage=localStorage;}catch{}
  const settings=readDrawingSettings(storage),persist=()=>writeDrawingSettings(storage,settings);
  const controls=document.createElement('div');controls.className='draw-controls';controls.hidden=true;
  controls.innerHTML=`<div class="ink-tool-tabs" role="group" aria-label="Ink tools">
    <button data-ink-mode="pen" title="Pen (P)">Pen</button><button data-ink-mode="highlighter" title="Highlighter (H)">Highlighter</button><button data-ink-mode="eraser" title="Eraser (E)">Eraser</button><button data-ink-mode="lasso" title="Select ink with a freehand loop (L)">Lasso</button></div>
    <div class="ink-settings"><div class="ink-favorites" role="group" aria-label="Favorite pens"></div><button class="ink-colors" aria-expanded="false">Colors</button><label class="ink-color-label">Ink <input aria-label="Drawing color" type="color"></label>
    <label class="ink-size-label">Size <input aria-label="Brush size" type="range"><output></output></label><label class="ink-eraser-label">Erase <select aria-label="Eraser type"><option value="stroke">Whole stroke</option><option value="partial">Precise</option></select></label>
    <details class="ink-more"><summary>More</summary><div class="ink-more-panel"><label><input class="ink-smoothing" type="checkbox"> Smooth while drawing</label><label><input class="ink-touch" type="checkbox"> Draw with touch</label><button class="ink-save-preset">Save current pen as favorite</button><button class="ink-group" aria-pressed="false">Group strokes</button><p>Shape cleanup is available after selecting ink.</p></div></details></div>
    <div class="draw-palette" aria-label="Drawing palette" hidden></div><span class="ink-status" role="status"></span>`;
  const button=document.createElement('button');button.id='mode-draw';button.className='tool';button.title='Draw with pen and ink';button.setAttribute('aria-label','Draw');button.innerHTML='<svg viewBox="0 0 34 34" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m8 23 2-7L24 2l5 5-14 14-7 2Zm12-17 5 5M10 16l5 5M5 28c4-5 7 5 12 0s7 3 12-1"/></svg><span>Draw</span>';button.setAttribute('aria-pressed','false');button.setAttribute('aria-expanded','false');button.setAttribute('aria-controls','draw-options');controls.id='draw-options';root.querySelector('[data-tool=text]').after(button);root.querySelector('#tool-dock').append(controls);
  const $=selector=>controls.querySelector(selector),status=$('.ink-status'),palette=$('.draw-palette'),paletteButton=$('.ink-colors'),color=$('[type=color]'),size=$('[type=range]'),eraserType=$('select'),groupButton=$('.ink-group');
  const cursor=document.createElement('div');cursor.className='ink-eraser-cursor';cursor.hidden=true;world.append(cursor);
  let enabled=false,grouping=false,draft=null,lastSend=0,penAt=-Infinity;
  const remote=new Map();
  function hint(){return grouping?'Drag a box around strokes':settings.mode==='eraser'?'Drag over ink to erase · Escape to select':settings.mode==='lasso'?'Circle ink to select it · Escape to select':'Draw freely · Escape to select';}
  function favorites(){const holder=$('.ink-favorites');holder.replaceChildren();for(const preset of settings.presets){const b=document.createElement('button');b.className='ink-favorite';b.style.setProperty('--favorite-ink',preset.color);b.title=`${preset.name} · ${preset.width}px`;b.setAttribute('aria-label',b.title);b.setAttribute('aria-pressed',String(settings.mode===preset.mode&&settings.color===preset.color&&settings.width===preset.width&&settings.smooth===preset.smooth));const dot=document.createElement('i');dot.style.height=`${Math.min(12,Math.max(3,preset.width))}px`;b.append(dot);b.onclick=()=>{cancel();Object.assign(settings,{color:preset.color,width:preset.width,mode:preset.mode,smooth:preset.smooth});grouping=false;sync();persist();};holder.append(b);}queueMicrotask(()=>positionOptions());}
  function sync(){
    for(const b of controls.querySelectorAll('[data-ink-mode]'))b.setAttribute('aria-pressed',String(!grouping&&settings.mode===b.dataset.inkMode));
    const erasing=settings.mode==='eraser'&&!grouping,inking=['pen','highlighter'].includes(settings.mode)&&!grouping;
    $('.ink-color-label').hidden=!inking;paletteButton.hidden=!inking;$('.ink-size-label').hidden=!inking&&!erasing;$('.ink-eraser-label').hidden=!erasing;
    color.value=settings.color;size.min=erasing?'4':'1';size.max=erasing?'80':'24';size.value=erasing?settings.eraserSize:settings.width;size.setAttribute('aria-label',erasing?'Eraser size':'Brush size');$('output').textContent=size.value;eraserType.value=settings.eraserType;
    $('.ink-smoothing').checked=settings.smooth;$('.ink-touch').checked=settings.touch;groupButton.setAttribute('aria-pressed',String(grouping));status.textContent=hint();canvas.classList.toggle('erasing-mode',enabled&&erasing);cursor.hidden=true;favorites();queueMicrotask(()=>positionOptions());
  }
  function mode(value){cancel();settings.mode=value;grouping=false;palette.hidden=true;paletteButton.setAttribute('aria-expanded','false');sync();persist();}
  for(const b of controls.querySelectorAll('[data-ink-mode]'))b.onclick=()=>mode(b.dataset.inkMode);
  paletteButton.onclick=()=>{palette.hidden=!palette.hidden;paletteButton.setAttribute('aria-expanded',String(!palette.hidden));positionOptions();};
  appendStandardColors(palette,value=>{settings.color=value;color.value=value;palette.hidden=true;paletteButton.setAttribute('aria-expanded','false');favorites();persist();});
  color.oninput=()=>{settings.color=color.value;favorites();persist();};size.oninput=()=>{settings[settings.mode==='eraser'?'eraserSize':'width']=Number(size.value);$('output').textContent=size.value;favorites();persist();};eraserType.onchange=()=>{settings.eraserType=eraserType.value;persist();};
  $('.ink-smoothing').onchange=e=>{settings.smooth=e.target.checked;favorites();persist();};$('.ink-touch').onchange=e=>{settings.touch=e.target.checked;persist();};
  $('.ink-save-preset').onclick=()=>{if(!['pen','highlighter'].includes(settings.mode)){toast('Choose a pen or highlighter to save a favorite.');return;}if(settings.presets.some(p=>p.color===settings.color&&p.width===settings.width&&p.mode===settings.mode&&p.smooth===settings.smooth)){toast('That pen is already in your favorites.');return;}settings.presets.push({name:settings.mode==='highlighter'?'Favorite highlighter':'Favorite pen',color:settings.color,width:settings.width,mode:settings.mode,smooth:settings.smooth});settings.presets=settings.presets.slice(-5);favorites();persist();toast('Favorite saved on this device.');};
  groupButton.onclick=()=>{cancel();grouping=!grouping;sync();$('.ink-more').open=false;};
  function setEnabled(value){cancel();enabled=value;controls.hidden=!value;palette.hidden=true;paletteButton.setAttribute('aria-expanded','false');$('.ink-more').open=false;button.setAttribute('aria-pressed',String(value));button.classList.toggle('active',value);button.setAttribute('aria-expanded',String(value));canvas.classList.toggle('drawing-mode',value);if(value){activate();root.querySelector('#toolbar').hidden=false;}root.querySelector('#mode-select').setAttribute('aria-pressed',String(!value));sync();}
  function positionOptions(){if(controls.hidden)return;const at=anchoredPanelPosition(button.getBoundingClientRect(),{width:controls.offsetWidth,height:controls.offsetHeight},{width:innerWidth,height:innerHeight,top:canvas.getBoundingClientRect().top});controls.style.left=`${at.x}px`;controls.style.top=`${at.y}px`;for(const panel of [palette,$('.ink-more-panel')]){if(panel===palette?panel.hidden:!$('.ink-more').open)continue;const position=anchoredPanelPosition(controls.getBoundingClientRect(),{width:panel.offsetWidth,height:panel.offsetHeight},{width:innerWidth,height:innerHeight,top:canvas.getBoundingClientRect().top});panel.style.left=`${position.x}px`;panel.style.top=`${position.y}px`;}}
  listen($('.ink-more'),'toggle',positionOptions);
  function hideOptions(){controls.hidden=true;palette.hidden=true;paletteButton.setAttribute('aria-expanded','false');$('.ink-more').open=false;button.setAttribute('aria-expanded','false');}
  button.onclick=()=>{if(!enabled){setEnabled(true);positionOptions();}else if(controls.hidden){controls.hidden=false;button.setAttribute('aria-expanded','true');positionOptions();}else hideOptions();};
  listen(document,'pointerdown',e=>{if(e.target.closest('#canvas'))hideOptions();else if(!e.target.closest('#draw-options,#mode-draw'))hideOptions();},{capture:true});
  listen(window,'resize',positionOptions);

  function clear(){draft?.node?.remove();for(const n of draft?.previewNodes||[])n.remove();for(const n of world.querySelectorAll('.ink-erase-source'))n.classList.remove('ink-erase-source');draft=null;for(const node of world.querySelectorAll('.draw-group-candidate'))node.classList.remove('draw-group-candidate');status.textContent=hint();}
  function cancel(){if(draft){if(draft.kind==='ink')send('drawing',{visible:false});clear();}}
  function nodeFor(el,parent=world){const node=document.createElement('div');node.className='drawing-preview';node.append(strokeSvg(el));Object.assign(node.style,{left:`${el.x}px`,top:`${el.y}px`,width:`${el.w}px`,height:`${el.h}px`});parent.append(node);return node;}
  function currentStroke(){return {...makeStroke(draft.points,draft.color,draft.width,draft.id,layer()),linear:draft.linear,opacity:draft.opacity};}
  function preview(){const el=currentStroke();draft.node.replaceChildren(strokeSvg(el));Object.assign(draft.node.style,{left:`${el.x}px`,top:`${el.y}px`,width:`${el.w}px`,height:`${el.h}px`});
    if(performance.now()-lastSend>=66){lastSend=performance.now();const step=Math.max(1,Math.ceil(draft.points.length/127)),points=draft.points.filter((_,i)=>i%step===0);if(points.at(-1)!==draft.points.at(-1))points.push(draft.points.at(-1));send('drawing',{visible:true,color:draft.color,width:draft.width,linear:draft.linear,opacity:draft.opacity,points:points.map(p=>[p.x,p.y])});}}
  function groupBox(){const a=draft.start,b=draft.end;return {x:Math.min(a.x,b.x),y:Math.min(a.y,b.y),w:Math.abs(a.x-b.x),h:Math.abs(a.y-b.y)};}
  function groupPreview(){const b=groupBox();Object.assign(draft.node.style,{left:`${b.x}px`,top:`${b.y}px`,width:`${b.w}px`,height:`${b.h}px`});for(const node of world.querySelectorAll('.element.stroke')){const el=board().elements[node.dataset.id];node.classList.toggle('draw-group-candidate',enclosedStrokes([el],b).length>0);}}
  function lassoPreview(){draft.path.setAttribute('d',draft.points.map((p,i)=>`${i?'L':'M'} ${p.x} ${p.y}`).join(' ')+' Z');}
  function eraseStep(p){
    const start=draft.last;draft.last=p;
    for(const el of Object.values(board().elements)){
      if(el.type!=='stroke'||el.locked||!canUseStroke(el)||draft.removed.has(el.id))continue;
      let cached=draft.sourcePoints.get(el.id);if(!cached||cached.model!==el){cached={model:el,points:inkPoints(el)};draft.sourcePoints.set(el.id,cached);}const previous=draft.parts.get(el.id)||[cached.points],next=[];let changed=false;
      for(const part of previous){const result=eraseInk(part,start,p,draft.radius+el.stroke_width/2);changed ||= result.changed;next.push(...result.parts);}
      if(!changed)continue;if(!draft.originals.has(el.id))draft.originals.set(el.id,structuredClone(el));
      if(draft.eraseType==='stroke'||!next.length){draft.removed.add(el.id);draft.parts.set(el.id,[]);}else draft.parts.set(el.id,next);
    }
    for(const n of draft.previewNodes)n.remove();draft.previewNodes=[];
    for(const [id,parts] of draft.parts){const original=draft.originals.get(id);world.querySelector(`.element[data-id="${CSS.escape(id)}"]`)?.classList.add('ink-erase-source');for(const points of parts){const el={...makeStroke(points,original.color,original.stroke_width,id,original.z),linear:true,opacity:original.opacity??1};const n=nodeFor(el,world.querySelector('#elements'));n.classList.add('ink-erasure-preview');n.style.zIndex=String(original.z||0);draft.previewNodes.push(n);}}
  }
  function paintCursor(p){if(!enabled||settings.mode!=='eraser'||grouping){cursor.hidden=true;return;}const diameter=settings.eraserSize/getZoom();cursor.hidden=false;Object.assign(cursor.style,{left:`${p.x}px`,top:`${p.y}px`,width:`${diameter}px`,height:`${diameter}px`});}
  function blockedTouch(e){if(e.pointerType==='pen')penAt=performance.now();if(e.pointerType!=='touch')return false;if(performance.now()-penAt<700){e.preventDefault();e.stopImmediatePropagation();return true;}return !settings.touch;}
  listen(canvas,'pointerdown',e=>{if(!enabled||e.button!==0||e.ctrlKey||e.metaKey||e.altKey||!board()||blockedTouch(e))return;e.preventDefault();e.stopImmediatePropagation();if(draft)return;const p=point(e);
    if(grouping){draft={kind:'group',pointer:e.pointerId,start:p,end:p,node:document.createElement('div')};draft.node.className='draw-group-box';world.append(draft.node);}
    else if(settings.mode==='lasso'){const node=document.createElementNS('http://www.w3.org/2000/svg','svg'),path=document.createElementNS(node.namespaceURI,'path');node.classList.add('ink-lasso');node.append(path);world.append(node);draft={kind:'lasso',pointer:e.pointerId,points:[p],node,path};lassoPreview();}
    else if(settings.mode==='eraser'){draft={kind:'erase',pointer:e.pointerId,last:p,radius:settings.eraserSize/(2*getZoom()),eraseType:settings.eraserType,originals:new Map(),sourcePoints:new Map(),parts:new Map(),removed:new Set(),previewNodes:[]};eraseStep(p);}
    else {const remaining=MAX_STROKE_POINTS-Object.values(board().elements).filter(el=>el.type==='stroke').reduce((n,el)=>n+el.points.length,0);if(remaining<1){toast('This board has reached 100,000 drawing points. Erase some ink to keep drawing.');return;}draft={kind:'ink',remaining,minX:p.x,maxX:p.x,minY:p.y,maxY:p.y,id:uid(),pointer:e.pointerId,points:[p],color:settings.color,width:settings.width,linear:!settings.smooth,opacity:settings.mode==='highlighter'?.3:1,node:document.createElement('div')};draft.node.className='drawing-preview';world.append(draft.node);preview();}
    canvas.setPointerCapture(e.pointerId);paintCursor(p);
  },{capture:true});
  function addPoint(p){
    const last=draft.points.at(-1);if(Math.hypot(p.x-last.x,p.y-last.y)<.1)return;
    const pad=draft.width/2+2,large=draft.kind==='ink'&&(Math.max(draft.maxX,p.x)-Math.min(draft.minX,p.x)+pad*2>10000||Math.max(draft.maxY,p.y)-Math.min(draft.minY,p.y)+pad*2>10000);
    if(draft.points.length>=(draft.remaining??MAX_STROKE_POINTS)||large){if(!draft.warned){toast(large?'This drawing spans the maximum canvas size. Release to save it.':'This board has reached 100,000 drawing points. Release to save this stroke.');draft.warned=true;}return;}
    draft.points.push(p);if(draft.kind==='ink'){draft.minX=Math.min(draft.minX,p.x);draft.maxX=Math.max(draft.maxX,p.x);draft.minY=Math.min(draft.minY,p.y);draft.maxY=Math.max(draft.maxY,p.y);}
  }
  let previewFrame=0;
  function schedulePreview(){if(previewFrame)return;previewFrame=requestAnimationFrame(()=>{previewFrame=0;if(draft?.kind==='ink')preview();else if(draft?.kind==='lasso')lassoPreview();});}
  listen(canvas,'pointermove',e=>{if(!enabled)return;paintCursor(point(e));if(!draft||draft.pointer!==e.pointerId)return;e.preventDefault();if(e.pointerType==='pen')penAt=performance.now();
    const events=e.getCoalescedEvents?.(),samples=events?.length?events:[e];
    for(const sample of samples){const p=point(sample);if(draft.kind==='group'){draft.end=p;groupPreview();}else if(draft.kind==='erase')eraseStep(p);else addPoint(p);}
    if(['lasso','ink'].includes(draft.kind))schedulePreview();
  },{capture:true});
  listen(canvas,'pointerup',e=>{if(!draft||draft.pointer!==e.pointerId)return;e.preventDefault();e.stopImmediatePropagation();
    if(draft.kind==='group'){const ids=enclosedStrokes(Object.values(board().elements),groupBox()).map(el=>el.id);clear();groupStrokes(ids);}
    else if(draft.kind==='lasso'){const ids=lassoStrokes(Object.values(board().elements).filter(canUseStroke),draft.points);clear();if(ids.length)selectStrokes(ids);else toast('Circle a whole stroke to select it.');}
    else if(draft.kind==='erase'){const edits=new Map();for(const [id,original]of draft.originals){if(!board().elements[id]||board().elements[id].locked)continue;const parts=draft.parts.get(id)||[];if(parts.some(points=>points.length>MAX_STROKE_POINTS)){toast('This stroke is too detailed for precise erasing. Use Whole stroke.');clear();return;}const elements=[];for(const [i,points]of parts.entries()){const geometry=makeStroke(points,original.color,original.stroke_width,i?uid():id,original.z||0);if(!geometry){toast('This rotated stroke is too large to split. Use Whole stroke.');clear();return;}elements.push({...original,...geometry,linear:true,rotation:0});}edits.set(id,{original,elements});}clear();if(edits.size)eraseStrokes(edits);}
    else {const el=currentStroke();send('drawing',{visible:false});clear();save(el);}
  },{capture:true});
  for(const name of ['click','dblclick'])listen(canvas,name,e=>{if(enabled&&e.button===0){e.preventDefault();e.stopImmediatePropagation();}},{capture:true});
  for(const name of ['pointercancel','lostpointercapture'])listen(canvas,name,e=>{if(draft?.pointer===e.pointerId)cancel();});listen(window,'blur',()=>{cancel();cursor.hidden=true;});listen(canvas,'pointerleave',()=>{cursor.hidden=true;});
  listen(document,'keydown',e=>{if(!enabled||e.target.closest('input,textarea,select,[contenteditable=true],dialog'))return;if(e.key==='Escape'){if(draft){cancel();e.preventDefault();e.stopImmediatePropagation();}else setEnabled(false);return;}if((e.ctrlKey||e.metaKey)&&['z','y'].includes(e.key.toLowerCase())){cancel();return;}if(e.code==='Space'&&!draft){setEnabled(false);return;}if(!e.ctrlKey&&!e.metaKey&&!e.altKey){const value={p:'pen',h:'highlighter',e:'eraser',l:'lasso'}[e.key.toLowerCase()];if(value){e.preventDefault();mode(value);}}},{capture:true});
  listen(root,'pointerdown',e=>{if(enabled&&e.target.closest('[data-tool],#mode-select,#mode-hand'))setEnabled(false);},{capture:true});
  function receive(payload){const id=payload.id;remote.get(id)?.node.remove();remote.delete(id);if(!payload.visible)return;const el=makeStroke(payload.points.map(([x,y])=>({x,y})),payload.color,payload.width,id,0);if(!el)return;el.linear=payload.linear??false;el.opacity=payload.opacity??1;const node=nodeFor(el);node.classList.add('remote-drawing');remote.set(id,{node,at:performance.now()});}
  listen(window,'nook:drawing-settings',e=>{cancel();Object.assign(settings,e.detail);sync();});
  const expiry=setInterval(()=>{for(const [id,value]of remote)if(performance.now()-value.at>4000){value.node.remove();remote.delete(id);}},1000);
  sync();return {receive,isEditing:id=>draft?.kind==='erase'&&draft.originals.has(id),disable:()=>{if(enabled)setEnabled(false);},dispose(){cancel();clearInterval(expiry);for(const value of remote.values())value.node.remove();controls.remove();button.remove();cursor.remove();}};
}

export function enclosedStrokes(elements,b){return elements.filter(el=>el?.type==='stroke'&&!el.locked&&el.points.every(([x,y])=>{const {x:px,y:py}=rotatePoint({x:el.x+x*el.w,y:el.y+y*el.h},itemCenter(el),el.rotation||0);return px>=b.x&&px<=b.x+b.w&&py>=b.y&&py<=b.y+b.h;}));}
