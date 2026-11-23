import {Socket} from './phoenix.mjs';
import './phoenix_html.js';
import {LiveSocket} from './phoenix_live_view.esm.js';
import {mountNook} from './app.mjs?v=0.12.2';
const liveSocket = new LiveSocket('/live', Socket, {
  params: {_csrf_token: document.querySelector('meta[name=csrf-token]').content},
  hooks: {Whiteboard: {
    mounted() { this.cleanup = mountNook(this); },
    destroyed() { this.cleanup?.(); }
  }}
});
liveSocket.connect();
