export const iconPaths = {
 lightbulb:'<path d="M9 22h14m-12 5h10M10 22v-3a10 10 0 1 1 12 0v3"/>',
 arrow:'<path d="M3 16h25M19 7l9 9-9 9"/>',
 question:'<circle cx="16" cy="16" r="13"/><path d="M11 11a5 5 0 1 1 7 5c-2 1-2 2-2 4m0 4v1"/>',
 warning:'<path d="M16 3 31 29H1ZM16 11v9m0 4v1"/>',
 checkmark:'<path d="m4 16 8 9L29 6"/>',
 person:'<circle cx="16" cy="9" r="6"/><path d="M4 30v-4a12 12 0 0 1 24 0v4"/>',
 heart:'<path d="M16 28 4 16C-5 5 9-2 16 8 23-2 37 5 28 16Z"/>',
 document:'<path d="M6 2h14l7 7v21H6ZM20 2v8h7M11 16h11m-11 6h11"/>'
};
export const palette={lilac:'#eee3ff',yellow:'#fff0bc',peach:'#ffe3d6',mint:'#dff1e8',white:'#ffffff',purple:'#210a3b',charcoal:'#30293b',violet:'#7640a8'};
export const validHex=value=>typeof value==='string'&&/^#[0-9a-f]{6}$/i.test(value);
export const colorValue=value=>validHex(value)?value:palette[value]||palette.purple;
export function contrast(a,b){const luminance=c=>{const rgb=colorValue(c).slice(1).match(/../g).map(v=>parseInt(v,16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);return rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722;};const x=luminance(a),y=luminance(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05);}
// Snap the selection as one unit, using screen-space tolerance at every zoom.
export function snapMove(box,others,dx,dy,zoom=1){const out={dx,dy,guides:[]};for(const axis of ['x','y']){const size=axis==='x'?'w':'h',delta=axis==='x'?'dx':'dy';let best=6/zoom,match;for(const other of others)for(const a of [0,.5,1])for(const b of [0,.5,1]){const target=other[axis]+other[size]*b,d=target-(box[axis]+box[size]*a+out[delta]);if(Math.abs(d)<best){best=Math.abs(d);match={d,target};}}if(match){out[delta]+=match.d;out.guides.push({axis,at:match.target});}}return out;}

// Use visible item bounds supplied by the UI, with the same front-to-back order as the canvas.
export function overlappingItems(elements, selectedIds) {
  const selected = new Set(selectedIds);
  const boxes = elements.filter(el => selected.has(el.id) && el.type !== 'connection');
  const intersects = (a,b) => a.x < b.x+b.w && a.x+a.w > b.x && a.y < b.y+b.h && a.y+a.h > b.y;
  return elements.map((el,index)=>({el,index})).filter(({el}) => el.type !== 'connection' && !selected.has(el.id) && boxes.some(box=>intersects(box,el)))
    .sort((a,b)=>(b.el.z||0)-(a.el.z||0)||b.index-a.index).map(({el})=>el);
}

// Canvas items are converted to screen coordinates by the caller. Keep controls
// above the item when possible, but usable near the viewport and toolbar edges.
export function selectionBarPosition(box, size, viewport, obstacles=[]) {
 const margin=12, gap=12, minY=viewport.top+margin;
 const maxX=Math.max(margin,viewport.width-size.width-margin),maxY=Math.max(minY,viewport.height-size.height-margin);
 const clampX=x=>Math.max(margin,Math.min(maxX,x)),clampY=y=>Math.max(minY,Math.min(maxY,y));
 const x=clampX(box.x+box.w/2-size.width/2),above=box.y-size.height-gap,below=box.y+box.h+gap;
 const clear=(x,y)=>!obstacles.some(o=>x<o.x+o.w+gap&&x+size.width>o.x-gap&&y<o.y+o.h+gap&&y+size.height>o.y-gap);
 for(const y of [above,below])if(y>=minY&&y<=maxY&&clear(x,y))return {x,y};
 for(const y of [clampY(above),...obstacles.map(o=>clampY(o.y+o.h+gap)),clampY(below)])if(clear(x,y))return {x,y};
 return {x,y:clampY(above)};
}
