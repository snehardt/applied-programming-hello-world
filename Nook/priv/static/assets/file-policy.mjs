export function fileError(file){
 if(!file.size)return 'This file is empty. Choose a file with some content.';
 if(new TextEncoder().encode(file.name).length>255)return 'Shorten this file name before adding it.';
 if(file.size>10_000_000)return 'Choose a file up to 10 MB.';
 if(!/^(image\/(png|jpeg|gif|webp)|application\/pdf|text\/(plain|csv|markdown))$/.test(file.type)&&!(/\.(txt|md|csv)$/i.test(file.name)&&!file.type))return 'Choose an image, PDF, text, Markdown, or CSV file.';
 return null;
}

export function clipboardImages(clipboard){
 const items=Array.from(clipboard?.items||[]).filter(item=>item.kind==='file'&&item.type?.startsWith('image/')).map(item=>item.getAsFile()).filter(Boolean);
 return items.length?items:Array.from(clipboard?.files||[]).filter(file=>file.type?.startsWith('image/'));
}
export function imageCardSize(width,height){
 if(!(width>0&&height>0))return {w:280,h:220};
 const scale=Math.min(1,320/width,260/height);
 return {w:Math.max(50,Math.round(width*scale)),h:Math.max(50,Math.round(height*scale))};
}
