/** Candidate protocol-v1 signaling adapter. Game traffic uses WebRTC, never this API. */
export class INeedRealtime {
  constructor(host = window.INeedHost) {
    this.host = host;
    this.code = null;
    this.cursor = 0;
    this.stopped = true;
    this.listeners = new Set();
    this.epoch = 0;
    this.entering = false;
    this.unsubscribe = host?.subscribe?.(raw => {
      let event;
      try { event = typeof raw === 'string' ? JSON.parse(raw) : raw; } catch { return; }
      if (event.name === 'account.changed') this.stop('ACCOUNT_CHANGED');
    });
  }
  onEvent(listener) { this.listeners.add(listener); return () => this.listeners.delete(listener); }
  emit(name, data) { for (const f of this.listeners) { try { f({ name, data }); } catch {} } }
  async call(action, params = {}) {
    const before = this.epoch;
    const result = await this.host.request('multiplayer.' + action, params);
    if (before !== this.epoch) throw Object.assign(Error('ACCOUNT_CHANGED'), { code: 'ACCOUNT_CHANGED' });
    if (!result.ok) throw Object.assign(Error(result.error?.message || 'REQUEST_FAILED'), result.error);
    return result.value;
  }
  async ready() {
    if (!this.host) throw Error('UNSUPPORTED');
    const hello = await this.host.request('hello', { protocols: [1] });
    if (!hello.ok || !this.host.supports('multiplayer.create')) throw Object.assign(Error('UNSUPPORTED'), { code: 'UNSUPPORTED' });
  }
  async authenticate() {
    await this.ready();
    const account = await this.host.request('account.get');
    if (!account.ok) throw Object.assign(Error('AUTH_REQUIRED'), account.error);
    if (!account.value) {
      const login = await this.host.request('login');
      if (!login.ok) throw Object.assign(Error('AUTH_REQUIRED'), login.error);
    }
  }
  async enter(action, params) {
    if (this.entering || this.code) throw Error('ALREADY_IN_ROOM');
    this.entering = true;
    const before = this.epoch;
    try {
      await this.authenticate();
      // Successful login may produce account.changed; capture the epoch after authentication.
      if (this.epoch !== before && this.stopReason !== 'ACCOUNT_CHANGED') throw Error('CANCELLED');
      const result = await this.call(action, params);
      this.code = result.code;
      this.cursor = 0;
      this.stopped = false;
      this.emit('room', result);
      return result;
    } finally { this.entering = false; }
  }
  create(mode, build, clientId = crypto.randomUUID()) { return this.enter('create', { mode, build, clientId }); }
  match(build, clientId = crypto.randomUUID()) { return this.enter('match', { build, clientId }); }
  join(code, build, clientId = crypto.randomUUID()) { return this.enter('join', { code: code.trim().toUpperCase(), build, clientId }); }
  async list() { await this.authenticate(); return this.call('list'); }
  async poll() {
    if (!this.code || this.stopped) throw Error('NO_ROOM');
    const result = await this.call('poll', { code: this.code, cursor: this.cursor });
    this.cursor = result.cursor;
    return result;
  }
  signal(kind, data, requestId = crypto.randomUUID()) {
    if (!this.code || this.stopped) return Promise.reject(Error('NO_ROOM'));
    return this.call('signal', { code: this.code, kind, data, requestId });
  }
  async watch({ intervalMs = 2000 } = {}) {
    if (this.watching === this.epoch) throw Error('ALREADY_WATCHING');
    const epoch = this.epoch;
    this.watching = epoch;
    let failures = 0;
    try {
      while (!this.stopped && this.epoch === epoch) {
        try {
          const result = await this.poll();
          failures = 0;
          this.emit('peers', result.peers);
          for (const signal of result.signals) this.emit('signal', signal);
        } catch (error) {
          if (this.epoch !== epoch) break;
          if (++failures >= 4 || ['ACCOUNT_CHANGED', 'ROOM_CLOSED', 'NOT_MEMBER', 'AUTH_REQUIRED', 'UNSUPPORTED'].includes(error.code)) {
            this.stop(error.code || 'DISCONNECTED'); break;
          }
        }
        await new Promise(resolve => setTimeout(resolve, Math.min(8000, Math.max(500, intervalMs) * 2 ** failures)));
      }
    } finally { if (this.watching === epoch) this.watching = undefined; }
  }
  async leave() {
    const code = this.code;
    this.stop('LEFT');
    if (code) return this.call('leave', { code });
  }
  stop(reason = 'STOPPED') {
    this.stopped = true; this.code = null; this.epoch++; this.stopReason = reason;
    this.emit('disconnected', { reason });
  }
  dispose() { this.stop(); this.unsubscribe?.(); this.listeners.clear(); }
}
