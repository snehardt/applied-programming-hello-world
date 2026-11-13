import {applyOperation} from './canvas-model.mjs';

// A new page owns a new backup key, so two tabs cannot erase each other's drafts.
// The session pointer restores that page's queue on reload (including duplicated tabs).
export function openDraftStore(code, storage, session, pageId, navigationType = 'navigate') {
  const pointer = `nook-draft:${code}`, legacy = `nook-pending:${code}`;
  const previous = session.getItem(pointer), key = `${legacy}:${pageId}`;
  let pending;
  try { pending = JSON.parse(storage.getItem(previous || legacy) || '[]'); } catch { pending = []; }
  if (!Array.isArray(pending)) pending = [];
  const save = ops => ops.length ? storage.setItem(key, JSON.stringify(ops)) : storage.removeItem(key);
  save(pending);
  session.setItem(pointer, key);
  if (previous && navigationType === 'reload') storage.removeItem(previous);
  if (!previous) storage.removeItem(legacy);
  return {pending, save};
}

// Capture the values the person actually edited, before previews or remote updates.
export function prepareOperation(op, element) {
  op = structuredClone(op);
  if (element && (op.type === 'patch' || op.type === 'delete' || op.replace)) {
    // A newly placed element can be edited before its creation acknowledgement arrives.
    op.base_revision = element.revision ?? 1;
    op.base = Object.fromEntries(Object.keys(op.changes || {}).map(key => [key, element[key] ?? null]));
    op.recovery_element = structuredClone(element);
  }
  return op;
}
export function optimisticBoard(server, pending) {
  const board = {...server,elements:{...server.elements}};
  for (const op of pending) applyOperation(board, op);
  return board;
}
export function wireOperation(op) {
  const {history_guard,...operation}=op;op=operation;
  if(op.type==='batch') return {...op,ops:op.ops.map(wireOperation)};
  const {recovery_element, ...wire} = op;
  return wire;
}
export function resolveConflict(server, pending, keep, newId) {
  if(pending[0].type==='batch') {
    if(!keep)return pending.slice(1);
    const mapping=new Map(),ops=[];
    for(const [index,child] of pending[0].ops.entries()) {
      const resolved=resolveConflict(server,[child],true,`${newId.slice(0,28)}-${index}`);
      if(resolved[0]){const next=resolved[0];if(next.type==='put'&&child.type==='patch')mapping.set(child.id,next.element.id);delete next.op_id;ops.push(next);}
    }
    for(const op of ops)if(op.type==='put'&&op.element.type==='connection')for(const key of ['from','to'])op.element[key]=mapping.get(op.element[key])||op.element[key];
    return ops.length?[{type:'batch',ops,op_id:newId},...pending.slice(1)]:pending.slice(1);
  }
  const first = pending[0], id = first.id || first.element?.id;
  const related = pending.filter(op => (op.id || op.element?.id) === id);
  const rest = pending.filter(op => (op.id || op.element?.id) !== id);
  if (!keep) return rest;
  const current = server.elements[id];
  const scratch = {elements: {[id]: structuredClone(current || first.recovery_element || first.element)}};
  for (const op of related) applyOperation(scratch, op);
  const desired = scratch.elements[id];
  let next;
  if (!desired && current) next = prepareOperation({type:'delete', id}, current);
  else if (!desired) return rest;
  else if (!current) {
    desired.id = newId;
    delete desired.revision;
    next = {type:'put', element:desired};
  } else if (related.some(op => op.type === 'put')) {
    next = prepareOperation({type:'put', element:desired, replace:true}, current);
  } else {
    const keys = new Set(related.flatMap(op => Object.keys(op.changes || {})));
    next = prepareOperation({type:'patch', id, changes:Object.fromEntries([...keys].map(k => [k, desired[k]]))}, current);
  }
  next.op_id = newId;
  return [next, ...rest];
}

export function describeElement(element) {
  if (!element) return 'This element was deleted.';
  const lines = [element.type.charAt(0).toUpperCase() + element.type.slice(1)];
  if (element.text) lines.push(element.text);
  if (element.description) lines.push(element.description);
  if(element.items) lines.push(element.items.map(item=>`${item.done?'☑':'☐'} ${item.text}`).join('\n'));
  if (element.name) lines.push(`File: ${element.name}`);
  if (element.type === 'task') lines.push(element.items?`${element.items.filter(item=>item.done).length} of ${element.items.length} completed`:element.done ? 'Completed' : 'To do');
  if('group_id' in element)lines.push(element.group_id?'Grouped':'Ungrouped');
  if(element.type==='connection')for(const [key,label]of [['from_anchor','Start'],['to_anchor','End']]){const anchor=element[key];lines.push(anchor?`${label}: ${Math.round(anchor.x*100)}% across, ${Math.round(anchor.y*100)}% down`:`${label}: automatic`);}
  if (element.color) lines.push(`Color: ${element.color}`);
  if (element.shape) lines.push(`Shape: ${element.shape}`);
  if (element.font_size) lines.push(`Text size: ${element.font_size}`);
  if (element.text_color) lines.push(`Ink: ${element.text_color}`);
  lines.push(`Position: ${Math.round(element.x)}, ${Math.round(element.y)}`);
  if (element.w) lines.push(`Size: ${Math.round(element.w)} × ${Math.round(element.h)}`);
  return lines.join('\n\n');
}
