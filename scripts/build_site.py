#!/usr/bin/env python3
"""Build crawlable HTML and original Markdown from the versioned Skill source."""
from pathlib import Path
from urllib.parse import urlsplit,unquote
import html,json,re,shutil,subprocess,hashlib
import markdown
from markdown.extensions.toc import slugify_unicode
ROOT=Path(__file__).resolve().parents[1];SOURCE=ROOT/'ineed-creator';OUT=ROOT/'site'
nav=json.loads((ROOT/'docs-nav.json').read_text());catalog=json.loads((SOURCE/'catalog.json').read_text())
pages=[dict(p,group=g['title']) for g in nav['groups'] for p in g['pages']]
assert len({p['slug'] for p in pages})==len(pages)
by_source={p['source']:p['slug']+'.html' for p in pages}
subprocess.run(['python3',str(SOURCE/'scripts/build_bundle.py')],check=True,capture_output=True)
OUT.mkdir(exist_ok=True)
# Replace only this generator's known output directory, never source or deploy paths.
for p in OUT.iterdir():
 if p.is_dir():shutil.rmtree(p)
 else:p.unlink()
(OUT/'downloads').mkdir();(OUT/'raw').mkdir()
shutil.copytree(ROOT/'web/assets',OUT/'assets')
for p in SOURCE.rglob('*'):
 if p.is_file() and (p.suffix=='.md' or p.name in ['catalog.json','policy.json']):
  target=OUT/'raw'/p.relative_to(SOURCE);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
for name in ['ineed-creator-markdown.zip','markdown-manifest.json','manifest.json','SHA256SUMS']:
 shutil.copyfile(ROOT/'dist'/name,OUT/'downloads'/name)
full=json.loads((ROOT/'dist/manifest.json').read_text());docs=json.loads((ROOT/'dist/markdown-manifest.json').read_text())
version=catalog['version'];repo=nav['repository'];base=nav['baseUrl'];esc=html.escape
full_url='https://ineeds.club/api/skills/ineed-creator/download'
def rewrite(md,source):
 def link(m):
  ref=html.unescape(m.group(1));u=urlsplit(ref)
  if u.scheme or ref.startswith(('#','/')):return m.group(0)
  path=(SOURCE/source).parent/unquote(u.path);path=path.resolve()
  if not path.is_relative_to(SOURCE) or not path.exists():raise ValueError(f'Broken source link {source}: {ref}')
  name=path.relative_to(SOURCE).as_posix();dest=by_source.get(name,'raw/'+name)
  return 'href="'+esc(dest+('#'+u.fragment if u.fragment else ''),quote=True)+'"'
 return re.sub(r'href="([^"]+)"',link,md)
def sidebar(current):
 return ''.join('<section class="nav-group"><h2>'+esc(g['title'])+'</h2>'+''.join(f'<a href="{p["slug"]}.html"'+(' aria-current="page"' if p['slug']==current else '')+'>'+esc(p['title'])+'</a>' for p in g['pages'])+'</section>' for g in nav['groups'])
search=[];llms=['# iNeed 创作者文档\n','> 普通网页和 Godot 单线程 Web 的技能、SDK 接入及打包规范。\n',f'版本 {version}（预发布）；协议 v1；无需登录，正文 HTML 和 Markdown 均可直接读取。\n','## 完整技能与离线文档\n',f'- [完整 Skill ZIP]({full_url})：含插件、脚本及示例。',f'- [Markdown ZIP]({base}downloads/ineed-creator-markdown.zip)：仅阅读，不含插件。\n']
llms_full=[]
for i,p in enumerate(pages):
 raw=(SOURCE/p['source']).read_text();clean=re.sub(r'\A---\n.*?\n---\n','',raw,flags=re.S)
 md=markdown.Markdown(extensions=['tables','fenced_code','toc'],extension_configs={'toc':{'toc_depth':'2-3','slugify':slugify_unicode}})
 body=rewrite(md.convert(clean),p['source']);body=re.sub(r'(<table>.*?</table>)',r'<div class="table-wrap">\1</div>',body,flags=re.S)
 # Preserve public deep links after clearer page titles replace old headings.
 for alias in {'login': ['登录'], 'payments': ['支付']}.get(p['slug'], []):
  if 'id="'+alias+'"' not in body:
   body='<span id="'+alias+'" aria-hidden="true"></span>'+body
 if p['slug']=='index':
  action=f'<div class="actions"><a class="button primary" href="getting-started.html">开始接入 <span aria-hidden="true">&nbsp;↗</span></a><a class="button" href="downloads/ineed-creator-markdown.zip" download>下载 Markdown ZIP</a></div>'
  body=body.replace('</p>','</p>'+action,1)
  body=body.replace('<ul>', '<ul class="engine-links">', 1)
  body=re.sub(r'(<ul class="engine-links">.*?</ul>)',lambda m:m.group(1).replace('</a>：','</a>'),body,count=1,flags=re.S)
 if p['slug']=='releases':
  body+=f'<section class="download-block"><h2 id="downloads">下载 v{version}</h2><p>预发布 · 协议 v1 · Godot 插件 {catalog["pluginVersion"]}</p><p><a class="button primary" href="{full_url}">完整 Skill ZIP · {full["size"]/1048576:.1f} MiB</a> <a class="button" href="downloads/ineed-creator-markdown.zip" download>Markdown ZIP · {docs["size"]/1024:.0f} KiB</a></p><p>完整包包含插件、脚本和示例；Markdown 包仅供阅读。需要复现旧版本时访问 <a href="{repo}/releases">历史 Release</a>。</p><p class="digest">完整包 SHA256：{full["sha256"]}<br>文档包 SHA256：{docs["sha256"]}</p><p><a href="downloads/SHA256SUMS">校验清单</a> · <a href="downloads/manifest.json">完整包 manifest</a> · <a href="downloads/markdown-manifest.json">文档包 manifest</a></p></section>'
 toc=md.toc
 if p['slug']=='releases':toc=toc.replace('</ul>','<li><a href="#downloads">下载 v'+version+'</a></li></ul>',1)
 raw_url='raw/'+p['source'];canonical=base+p['slug']+'.html'
 prev=f'<a href="{pages[i-1]["slug"]}.html">← {esc(pages[i-1]["title"])}</a>' if i else '<span></span>'
 nex=f'<a href="{pages[i+1]["slug"]}.html">{esc(pages[i+1]["title"])} →</a>' if i+1<len(pages) else ''
 page=f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{esc(p['title'])} · iNeed 创作者文档</title><meta name="description" content="{esc(p['description'])}"><meta name="robots" content="index,follow"><meta name="theme-color" content="#262b39"><link rel="canonical" href="{canonical}"><link rel="alternate" type="text/markdown" href="{raw_url}" title="Markdown 源文档"><link rel="icon" href="assets/ineed-icon.svg" type="image/svg+xml"><link rel="stylesheet" href="assets/docs.css"><script src="assets/docs.js" defer></script></head>
<body><a class="skip" href="#content">跳到正文</a><header class="topbar"><div class="top-inner"><a class="brand" href="index.html"><img src="assets/ineed-icon.svg" alt="" width="30" height="30"><strong>iNeed</strong><span>创作者文档</span></a><form class="search" role="search" hidden><label for="search-input">搜索文档</label><input id="search-input" type="search" placeholder="搜索文档…" autocomplete="off" aria-controls="search-panel"><kbd aria-hidden="true">/</kbd><div id="search-panel" class="search-panel" hidden><p class="search-status" role="status"></p><ul class="search-results"></ul><button class="button retry" type="button" hidden>重试搜索</button></div></form><div class="top-links"><span class="version">v{version} 预发布</span><a class="github" href="{repo}">GitHub ↗</a><a class="button primary" href="{full_url}">下载 Skill</a></div></div></header>
<div class="layout"><details class="sidebar" open><summary>文档目录</summary><nav aria-label="文档分类">{sidebar(p['slug'])}</nav></details><main id="content" class="{'home' if p['slug']=='index' else ''}"><p class="eyebrow">{'CREATOR DOCUMENTATION' if p['slug']=='index' else esc(p['group'])}</p><div class="article-meta"><span>v{version} · 预发布</span><a href="{raw_url}">查看 Markdown</a><a href="{repo}/blob/main/ineed-creator/{p['source']}">在 GitHub 查看 ↗</a></div><details class="mobile-toc"><summary>本页目录</summary>{toc}</details><article>{body}</article><nav class="pager" aria-label="前后文档">{prev}{nex}</nav><footer class="page-footer"><span>iNeed 创作者文档 · 兼容性优先</span><span><a href="llms.txt">AI 阅读索引</a> · <a href="sitemap.xml">站点地图</a></span></footer></main><aside class="toc-rail" aria-label="本页章节"><p class="toc-title">本页目录</p>{toc}<p class="rail-note">文档与技能同源。<br>平台升级应保持旧游戏与 SDK 的既有行为。<br><a href="compatibility.html">兼容性原则 ↗</a></p></aside></div></body></html>'''
 (OUT/(p['slug']+'.html')).write_text(page)
 search.append({'title':p['title'],'url':p['slug']+'.html','description':p['description'],'text':clean})
 llms.append(f'- [{p["group"]} / {p["title"]}]({base}{raw_url}): {p["description"]}')
 llms_full.append(f'\n\n---\n\nSource: {base}{raw_url}\n\n'+raw)
(OUT/'search-index.json').write_text(json.dumps(search,ensure_ascii=False,separators=(',',':'))+'\n')
(OUT/'llms.txt').write_text('\n'.join(llms)+'\n');(OUT/'llms-full.txt').write_text('# iNeed Creator Documentation\n'+''.join(llms_full))
(OUT/'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+''.join(f'<url><loc>{base}{p["slug"]}.html</loc></url>' for p in pages)+'</urlset>\n')
# A nested robots file is informative for standalone hosting; root robots owns crawler policy.
(OUT/'build-manifest.json').write_text(json.dumps({'version':version,'sourceRepository':repo,'pages':len(pages),'skill':full,'markdown':docs,'files':{p.relative_to(OUT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.rglob('*')) if p.is_file()}},ensure_ascii=False,indent=2)+'\n')
print(f'Built {len(pages)} crawlable pages, original Markdown, search index and archives in {OUT}')
