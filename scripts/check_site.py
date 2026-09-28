"""Crawl the built site without JavaScript; check links, fragments and release bytes."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit,unquote
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1];site=root/'site'
class Page(HTMLParser):
 def __init__(self,text):
  super().__init__();self.refs=[];self.ids=set();self.h1=0;self.article=False;self.article_text=[];self.feed(text)
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if a.get('id'):assert a['id'] not in self.ids, f'Duplicate ID {a["id"]}';self.ids.add(a['id'])
  if tag in ['a','script','img','link']:
   ref=a.get('href',a.get('src'))
   if ref:self.refs.append(ref)
  if tag=='h1':self.h1+=1
  if tag=='article':self.article=True
 def handle_endtag(self,tag):
  if tag=='article':self.article=False
 def handle_data(self,data):
  if self.article:self.article_text.append(data)
pages={p.resolve():Page(p.read_text()) for p in site.glob('*.html')}
for path,page in pages.items():
 assert page.h1==1,path
 assert len(''.join(page.article_text).strip())>100,path
 for ref in page.refs:
  u=urlsplit(ref)
  if u.scheme or ref.startswith('/'):continue
  target=(path.parent/unquote(u.path)).resolve() if u.path else path
  assert target.is_relative_to(site),ref
  assert target.exists(),(path.name,ref)
  if u.fragment and target in pages:assert unquote(u.fragment) in pages[target].ids,(path.name,ref)
nav=json.loads((root/'docs-nav.json').read_text())
for group in nav['groups']:
 for p in group['pages']:
  assert (site/'raw'/p['source']).read_bytes()==(root/'ineed-creator'/p['source']).read_bytes()
manifest=json.loads((site/'build-manifest.json').read_text())
for name,digest in manifest['files'].items():assert hashlib.sha256((site/name).read_bytes()).hexdigest()==digest,name
assert manifest['pages']==len(pages)==len(json.loads((site/'search-index.json').read_text()))
for a in ['manifest.json','markdown-manifest.json']:
 m=json.loads((site/'downloads'/a).read_text());assert m['version']==manifest['version']
 assert (site/'downloads'/a).read_bytes()==(root/'dist'/a).read_bytes()
with zipfile.ZipFile(site/'downloads/ineed-creator-markdown.zip') as z:
 for name in z.namelist():assert z.read(name)==(site/'raw'/Path(name).relative_to('ineed-creator')).read_bytes()
assert not any((site/x).exists() for x in ['.env','AGENTS.md','design'])
print(f'PASS: {len(pages)} HTML pages readable without JavaScript; all local links/anchors and Markdown/ZIP hashes match')
