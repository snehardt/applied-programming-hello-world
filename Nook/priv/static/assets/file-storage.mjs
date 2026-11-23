import {imageCardSize} from './file-policy.mjs?v=0.12.2';

export function fileUrl(code,el,download=false){
  if(!el.asset_id)return el.data||'';
  return `/api/boards/${encodeURIComponent(code)}/files/${encodeURIComponent(el.asset_id)}${download?'?download=1':''}`;
}

// Only the lightweight preview is resized. The uploaded original is byte-for-byte intact.
export async function prepareFile(file){
  if(!file.type.startsWith('image/'))return {size:{w:280,h:90},preview:null};
  let bitmap;try{bitmap=await createImageBitmap(file);}catch{throw Error('Could not open this image. Try another image.');}
  try{
    const size=imageCardSize(bitmap.width,bitmap.height);
    if(file.type==='image/gif'||file.size<300000)return {size,preview:null};
    const scale=Math.min(1,1280/bitmap.width,1280/bitmap.height),canvas=document.createElement('canvas');
    let width=Math.max(1,Math.round(bitmap.width*scale)),height=Math.max(1,Math.round(bitmap.height*scale));
    const mime=file.type==='image/jpeg'?'image/jpeg':'image/png';let preview;
    do{
      canvas.width=width;canvas.height=height;canvas.getContext('2d').drawImage(bitmap,0,0,width,height);
      preview=await new Promise(resolve=>canvas.toBlob(resolve,mime,.85));
      width=Math.max(1,Math.floor(width/2));height=Math.max(1,Math.floor(height/2));
    }while(preview?.size>1000000);
    return {size,preview};
  }finally{bitmap.close();}
}

export async function uploadFile(code,file,name){
  const {size,preview}=await prepareFile(file),body=new FormData();
  body.append('file',file,name);if(preview)body.append('preview',preview,'preview');
  const response=await fetch(`/api/boards/${encodeURIComponent(code)}/files`,{method:'POST',headers:{'x-csrf-token':document.querySelector('meta[name=csrf-token]').content},body,signal:AbortSignal.timeout(60000)});
  const result=await response.json().catch(()=>({}));
  if(!response.ok)throw Error(result.error||'Could not upload this file. Check your connection and try again.');
  return {type:'file',...size,...result};
}
