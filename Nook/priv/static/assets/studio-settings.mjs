import {readDrawingSettings,writeDrawingSettings} from './ink-editing.mjs';

export function installStudioSettings(root){
  const $=s=>root.querySelector(s),controller=new AbortController(),listen=(el,type,fn)=>el.addEventListener(type,fn,{signal:controller.signal});
  const dock=$('#tool-dock'),toolbar=$('#toolbar'),pointer=document.createElement('div'),utilities=document.createElement('div');
  pointer.id='pointer-tools';utilities.id='rail-utilities';
  const select=$('#mode-select'),hand=$('#mode-hand'),gear=$('#studio-settings-open');
  select.setAttribute('aria-label','Select');hand.setAttribute('aria-label','Hand');
  select.innerHTML='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 3 13 10-7 1-3 7Z"/></svg>';
  hand.innerHTML='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 12V5a2 2 0 0 1 4 0v6-8a2 2 0 0 1 4 0v8-5a2 2 0 0 1 4 0v9c0 5-3 8-7 8-3 0-5-2-7-5l-3-5a2 2 0 0 1 3-2l2 2"/></svg>';
  gear.innerHTML='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 3-1 3-3 1v3l-2 2 2 2v3l3 1 1 3h6l1-3 3-1v-3l2-2-2-2V7l-3-1-1-3Z"/><circle cx="12" cy="12" r="3"/></svg>';
  pointer.append(select);utilities.append(hand,gear);dock.insertBefore(pointer,toolbar);dock.append(utilities);
  const dialog=document.createElement('dialog');dialog.className='studio-preferences';dialog.id='studio-preferences';dialog.setAttribute('aria-labelledby','studio-preferences-title');
  dialog.innerHTML=`<header><h2 id="studio-preferences-title">Settings</h2><button aria-label="Close settings" data-settings-close>×</button></header>
    <div class="studio-preferences-body"><nav class="studio-settings-tabs" role="tablist" aria-label="Settings sections">
      <button role="tab" id="studio-tab-general" aria-controls="studio-pane-general" data-settings-tab="general">General</button><button role="tab" id="studio-tab-drawing" aria-controls="studio-pane-drawing" data-settings-tab="drawing">Drawing</button><button role="tab" id="studio-tab-navigation" aria-controls="studio-pane-navigation" data-settings-tab="navigation">Navigation</button></nav>
    <section class="studio-settings-pane" role="tabpanel" id="studio-pane-general" aria-labelledby="studio-tab-general" hidden><h3>Your preferences</h3><p>Drawing and navigation choices are saved on this device.</p><label class="studio-setting-row"><span>Account</span><a href="/users/settings">Account settings</a></label><p><a href="/dashboard">Open saved boards</a></p></section>
    <section class="studio-settings-pane" role="tabpanel" id="studio-pane-drawing" aria-labelledby="studio-tab-drawing" hidden><h3>Drawing</h3>
      <div class="studio-pen-preview" aria-label="Preview of your pen"><svg viewBox="0 0 330 78" fill="none"><path d="M24 51C65 10 87 23 117 45S166 66 198 30 246 20 307 40" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
      <label class="studio-setting-row"><span>Pen color</span><input id="studio-pen-color" type="color" aria-label="Default pen color"></label>
      <label class="studio-setting-row"><span>Brush size</span><span class="studio-pen-samples"><input id="studio-pen-width" type="range" min="1" max="24" aria-label="Default brush size"><output id="studio-width-label"></output></span></label>
      <label class="studio-setting-row"><span>Draw with touch</span><input id="studio-touch" type="checkbox"></label>
      <label class="studio-setting-row"><span>Smooth strokes<small>Off keeps your original lines.</small></span><input id="studio-smooth" type="checkbox"></label>
    </section>
    <section class="studio-settings-pane" role="tabpanel" id="studio-pane-navigation" aria-labelledby="studio-tab-navigation" hidden><h3>Navigation</h3><div id="studio-navigation-holder"></div><p>Hold Alt to move without snapping.</p></section></div>
    <footer><button class="primary" data-settings-close>Done</button></footer>`;
  root.append(dialog);const navigation=$('#navigation-settings');$('#studio-navigation-holder').append(navigation);navigation.hidden=false;
  for(const label of navigation.querySelectorAll('label')){const control=label.querySelector('input,select'),text=document.createElement('span');text.textContent=control.id==='snap-enabled'?'Alignment guides and snapping':'Input device';label.classList.add('studio-setting-row');label.replaceChildren(text,control);}
  if(root.querySelector('.account-nav a[href="/users/log-in"]')){const account=dialog.querySelector('a[href="/users/settings"]');account.href='/users/log-in';account.textContent='Log in';}

  let storage;try{storage=localStorage;}catch{}
  let settings=readDrawingSettings(storage);
  function sync(){settings=readDrawingSettings(storage);$('#studio-pen-color').value=settings.color;$('#studio-pen-width').value=settings.width;$('#studio-touch').checked=settings.touch;$('#studio-smooth').checked=settings.smooth;preview();}
  function preview(){const path=dialog.querySelector('.studio-pen-preview path');path.setAttribute('stroke',settings.color);path.setAttribute('stroke-width',settings.width);$('#studio-width-label').value=`${settings.width} px`;}
  function tab(name){for(const button of dialog.querySelectorAll('[data-settings-tab]')){const active=button.dataset.settingsTab===name;button.setAttribute('aria-selected',String(active));button.tabIndex=active?0:-1;$('#studio-pane-'+button.dataset.settingsTab).hidden=!active;}}
  function open(name='drawing'){sync();tab(name);if(!dialog.open)dialog.showModal();dialog.querySelector('[aria-selected=true]').focus();}
  for(const button of dialog.querySelectorAll('[data-settings-tab]'))listen(button,'click',()=>tab(button.dataset.settingsTab));
  listen(dialog.querySelector('[role=tablist]'),'keydown',e=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;e.preventDefault();const buttons=[...dialog.querySelectorAll('[role=tab]')],index=buttons.indexOf(document.activeElement);const next=e.key==='Home'?0:e.key==='End'?2:(index+(e.key==='ArrowRight'?1:2))%3;tab(buttons[next].dataset.settingsTab);buttons[next].focus();});
  for(const button of dialog.querySelectorAll('[data-settings-close]'))listen(button,'click',()=>dialog.close());
  listen(dialog,'click',e=>{if(e.target!==dialog)return;const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)dialog.close();});
  const update=(key,value)=>{settings=readDrawingSettings(storage);settings[key]=value;writeDrawingSettings(storage,settings);preview();window.dispatchEvent(new CustomEvent('nook:drawing-settings',{detail:settings}));};
  listen($('#studio-pen-color'),'input',e=>update('color',e.target.value));listen($('#studio-pen-width'),'input',e=>update('width',Number(e.target.value)));listen($('#studio-touch'),'change',e=>update('touch',e.target.checked));listen($('#studio-smooth'),'change',e=>update('smooth',e.target.checked));
  listen(gear,'click',()=>open());listen($('#home-settings'),'click',()=>open());
  $('#navigation-settings-toggle').onclick=()=>open('navigation');
  return {dispose(){controller.abort();dialog.remove();}};
}
