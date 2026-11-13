export const standardColors=[
 ['#ffffff','#f2f2f2','#d9d9d9','#bfbfbf','#808080','#404040','#000000','#210a3b','#ad7bfa','#7640a8'],
 ['#fce4d6','#fff2cc','#e2f0d9','#ddebf7','#e4dfec','#f4cccc','#fce5cd','#d0e0e3','#d9ead3','#ead1dc'],
 ['#f4b183','#ffd966','#a9d18e','#9dc3e6','#b4a7d6','#ea9999','#f9cb9c','#a2c4c9','#93c47d','#d5a6bd'],
 ['#ed7d31','#ffc000','#70ad47','#5b9bd5','#8064a2','#ff0000','#ff9900','#00b0f0','#00b050','#e06666'],
 ['#c55a11','#bf9000','#548235','#2f75b5','#7030a0','#c00000','#b45f06','#008a9a','#38761d','#a64d79'],
 ['#843c0c','#7f6000','#375623','#1f4e79','#3f225c','#660000','#783f04','#134f5c','#274e13','#741b47']
].flat();
export function appendStandardColors(host,choose){
 host.classList.add('standard-color-grid');
 for(const value of standardColors){const button=document.createElement('button');button.type='button';button.className='standard-color';button.style.backgroundColor=value;button.setAttribute('aria-label',`Use ${value}`);button.title=value;button.onclick=()=>choose(value);host.append(button);}
}
