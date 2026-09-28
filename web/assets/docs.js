(() => {
  const nav = document.querySelector('.sidebar');
  const narrow = window.matchMedia('(max-width: 820px)');
  function syncNav() { nav.open = !narrow.matches; }
  syncNav(); narrow.addEventListener('change', syncNav);
  const form = document.querySelector('.search');
  const input = form.querySelector('input');
  const panel = form.querySelector('.search-panel');
  const list = form.querySelector('.search-results');
  const status = form.querySelector('.search-status');
  const retry = form.querySelector('.retry');
  form.hidden = false;
  let indexPromise, timer, revision = 0;
  const getIndex = () => indexPromise ||= fetch('search-index.json').then(r => {
    if (!r.ok) throw new Error('index unavailable'); return r.json();
  });
  async function search() {
    const current = ++revision;
    const query = input.value.trim().toLocaleLowerCase();
    list.replaceChildren(); retry.hidden = true;
    if (!query) { panel.hidden = true; return; }
    panel.hidden = false; status.textContent = '正在查找…';
    try {
      const pages = await getIndex();
      if (current !== revision) return;
      const terms = query.split(/\s+/);
      const results = pages.filter(p => terms.every(t => (p.title + ' ' + p.text).toLocaleLowerCase().includes(t)))
        .sort((a,b) => Number(b.title.toLocaleLowerCase().includes(query)) - Number(a.title.toLocaleLowerCase().includes(query))).slice(0,12);
      status.textContent = results.length ? `找到 ${results.length} 篇相关文档` : '没有找到，试试“Godot”“压缩”或“支付”。';
      for (const p of results) {
        const li = document.createElement('li'); const a = document.createElement('a');
        a.href = p.url; a.textContent = p.title;
        const summary = document.createElement('small'); summary.textContent = p.description;
        a.append(summary); li.append(a); list.append(li);
      }
    } catch {
      if (current !== revision) return;
      status.textContent = '搜索暂不可用，请使用分类目录继续阅读。'; retry.hidden = false;
    }
  }
  input.addEventListener('input', () => {clearTimeout(timer); revision++; timer=setTimeout(search,120);});
  input.addEventListener('focus', () => {if(input.value.trim()) search();});
  form.addEventListener('submit', event => { event.preventDefault(); clearTimeout(timer); search(); });
  retry.addEventListener('click', () => {indexPromise=undefined; search();});
  document.addEventListener('keydown', event => {
    if (event.key==='Escape') {revision++;panel.hidden=true;input.focus();}
    if ((event.key==='k' && (event.metaKey||event.ctrlKey)) || (event.key==='/' && !/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName))) {
      event.preventDefault();input.focus();
    }
  });
  document.addEventListener('click', event => {if(!form.contains(event.target)){revision++; panel.hidden=true;}});
})();
