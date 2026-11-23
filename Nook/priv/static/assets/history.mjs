// Visit-local history stores semantic changes, never other people's actions.
const clean=value=>value?Object.fromEntries(Object.entries({z:0,...structuredClone(value)}).filter(([key])=>key!=='revision')):null;
const equal=(a,b)=>{if(a==null||b==null)return a==null&&b==null;if(typeof a!=='object'||typeof b!=='object')return a===b;if(Array.isArray(a)!==Array.isArray(b))return false;const keys=Object.keys(a),other=Object.keys(b);return keys.length===other.length&&keys.every(key=>Object.hasOwn(b,key)&&equal(a[key],b[key]));};
export class BoardHistory {
  constructor(limit=50){this.limit=limit;this.revision=0;this.undo=[];this.redo=[];this.group=null;}
  serialize(){return JSON.stringify({version:1,undo:this.undo.map(({group,...entry})=>entry),redo:this.redo.map(({group,...entry})=>entry)});}
  restore(raw){try{const saved=JSON.parse(raw||'null');if(saved?.version!==1||!Array.isArray(saved.undo)||!Array.isArray(saved.redo))return;const valid=entry=>entry&&typeof entry.label==='string'&&entry.changes&&typeof entry.changes==='object'&&!Array.isArray(entry.changes)&&Object.entries(entry.changes).every(([id,change])=>change&&['before','after'].every(side=>change[side]===null||change[side]&&typeof change[side]==='object'&&!Array.isArray(change[side])&&change[side].id===id&&typeof change[side].type==='string'));this.undo=saved.undo.filter(valid).slice(-this.limit);this.redo=saved.redo.filter(valid).slice(-this.limit);this.group=null;this.revision++;}catch{this.clear();}}
  begin(label){if(!this.group)this.group={id:Symbol(),label};}
  end(){this.group=null;}
  clear(){this.revision++;this.undo=[];this.redo=[];this.group=null;}
  record(before,after,label='change',candidateIds){
    const changes={};
    for(const id of new Set(candidateIds||[...Object.keys(before.elements),...Object.keys(after.elements)])){
      if(before.elements[id]===after.elements[id])continue;const a=clean(before.elements[id]),b=clean(after.elements[id]);if(!equal(a,b))changes[id]={before:a,after:b};
    }
    if(!Object.keys(changes).length)return;this.revision++;
    const last=this.undo.at(-1),group=this.group;
    if(group&&last?.group===group.id){for(const [id,change]of Object.entries(changes)){if(last.changes[id])last.changes[id].after=change.after;else last.changes[id]=change;if(equal(last.changes[id].before,last.changes[id].after))delete last.changes[id];}if(!Object.keys(last.changes).length)this.undo.pop();}
    else{this.undo.push({changes,label:group?.label||label,group:group?.id});if(this.undo.length>this.limit)this.undo.shift();}
    this.redo=[];
  }
  plan(board,direction){
    const entry=this[direction].at(-1);if(!entry)return {ops:[]};
    const source=direction==='undo'?'after':'before',target=direction==='undo'?'before':'after',ops=[];
    for(const [id,change]of Object.entries(entry.changes)){
      const current=clean(board.elements[id]),expected=clean(change[source]),desired=clean(change[target]);
      if(!expected||!desired){if(!equal(current,expected))return {error:'Someone changed this item since your action. Undo/redo will not replace their work.'};if(!desired&&Object.values(board.elements).some(e=>e.type==='connection'&&(e.from===id||e.to===id)&&!entry.changes[e.id]))return {error:'Someone connected this item since your action. Remove that connection before undoing its creation.'};ops.push(desired?{type:'put',element:desired}:{type:'delete',id});continue;}
      const keys=new Set([...Object.keys(expected),...Object.keys(desired)]),changes={};let replacement=current?.type==='file'&&['asset_id','name','mime','size','data'].some(key=>!equal(expected[key],desired[key]));
      for(const key of keys)if(!equal(expected[key],desired[key])){if(!equal(current?.[key],expected[key]))return {error:'Someone changed this part of the item. Undo/redo will not replace their work.'};changes[key]=desired[key];replacement ||= desired[key]===undefined;}
      if(!current)return {error:'This item no longer exists. Undo/redo cannot replace another person’s changes.'};
      if(replacement){const element={...current,...changes};for(const key of Object.keys(element))if(element[key]===undefined)delete element[key];ops.push({type:'put',replace:true,element});}
      else ops.push({type:'patch',id,changes});
    }
    const available=new Set(Object.keys(board.elements));for(const op of ops){if(op.type==='put')available.add(op.element.id);if(op.type==='delete')available.delete(op.id);}
    const valid=ops.filter(op=>op.type!=='put'||op.element.type!=='connection'||available.has(op.element.from)&&available.has(op.element.to));
    valid.sort((a,b)=>Number(a.element?.type==='connection')-Number(b.element?.type==='connection'));
    return {ops:valid,entry,skipped:ops.filter(op=>!valid.includes(op)).map(op=>op.element?.id||op.id)};
  }
  accept(direction,plan){const entry=this[direction].pop();if(entry){this.revision++;for(const id of plan?.skipped||[])delete entry.changes[id];this[direction==='undo'?'redo':'undo'].push(entry);}this.end();}
}
export function actionLabel(op){if(op.type==='batch'){const labels=[...new Set(op.ops.map(actionLabel))];return labels.length===1?labels[0]:'selection change';}if(op.type==='put')return op.replace?'file change':'create item';if(op.type==='delete')return 'delete item';const keys=Object.keys(op.changes||{});if(keys.includes('rotation'))return 'rotate';if(keys.includes('locked'))return op.changes.locked?'lock position':'unlock position';if(keys.includes('icon'))return 'change icon';if(keys.includes('shape'))return 'change shape';if(keys.includes('items'))return 'checklist change';if(keys.includes('text'))return 'text edit';if(keys.includes('group_id'))return 'group change';if(keys.includes('w')||keys.includes('h'))return 'resize';if(keys.includes('x')||keys.includes('y'))return 'move';return 'appearance change';}

export function guardedHistoryPlan(board,guard){const history=new BoardHistory();history[guard.direction]=[guard.entry];return history.plan(board,guard.direction);}
