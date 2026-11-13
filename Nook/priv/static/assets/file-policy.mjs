export function fileError(file){
 if(!file.size)return 'This file is empty. Choose a file with some content.';
 if(new TextEncoder().encode(file.name).length>255)return 'Shorten this file name before adding it.';
 if(file.size>1_000_000)return 'Choose a file smaller than 1 MB.';
 if(!/^(image\/(png|jpeg|gif|webp)|application\/pdf|text\/(plain|csv|markdown))$/.test(file.type)&&!(/\.(txt|md|csv)$/i.test(file.name)&&!file.type))return 'Choose an image, PDF, text, Markdown, or CSV file.';
 return null;
}
