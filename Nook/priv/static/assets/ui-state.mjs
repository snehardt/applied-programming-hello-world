export function saveState({ready=false,pending=0,editing=false,conflict=false,loading=false}={}) {
  if(loading)return {kind:'loading',text:'Opening board…'};
  if(conflict)return {kind:'conflict',text:'Review a conflicting change'};
  if(!ready)return {kind:'offline',text:pending?'Offline · changes on this device':'Reconnecting…'};
  if(pending)return {kind:'saving',text:'Saving…'};
  return {kind:'saved',text:editing?'Editing…':'All changes saved'};
}
export function loadFailure(status) {
  return status===404?{title:'This board is unavailable.',detail:'It may have expired, or you may need a new invitation from its owner.'}:
    {title:'We couldn’t open this board.',detail:'Check your connection and try again. Saved boards and device drafts are kept.'};
}
// Camera preferences are device-local, never part of shared board content.
export function readBoardView(storage,code) {
  try {
    const value=JSON.parse(storage.getItem(`nook-board-view:${code}`));
    if(value&&['x','y','z'].every(key=>typeof value[key]==='number'&&Number.isFinite(value[key]))&&Math.abs(value.x)<=1e9&&Math.abs(value.y)<=1e9&&value.z>=.2&&value.z<=3)
      return {x:value.x,y:value.y,z:value.z};
  }catch{/* Storage can be unavailable or contain invalid data. */}
  return {x:0,y:0,z:1};
}
export function writeBoardView(storage,code,view) {
  try{storage.setItem(`nook-board-view:${code}`,JSON.stringify({x:view.x,y:view.y,z:view.z}));}catch{/* Camera navigation must work without storage. */}
}

