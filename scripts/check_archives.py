from pathlib import Path
import hashlib,json,subprocess,zipfile
root=Path(__file__).resolve().parents[1]
subprocess.run(['python3',str(root/'ineed-creator/scripts/build_bundle.py')],check=True,capture_output=True)
first={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'dist').glob('*.zip')}
subprocess.run(['python3',str(root/'ineed-creator/scripts/build_bundle.py')],check=True,capture_output=True)
assert first=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'dist').glob('*.zip')},'Rebuild must be byte deterministic'
with zipfile.ZipFile(root/'dist/ineed-creator.zip') as full,zipfile.ZipFile(root/'dist/ineed-creator-markdown.zip') as docs:
 assert docs.namelist() and all(p.endswith('.md') for p in docs.namelist())
 assert set(docs.namelist())=={p for p in full.namelist() if p.endswith('.md')}
 for name in docs.namelist():
  assert docs.read(name)==full.read(name)==(root/name).read_bytes(),name
 for name in full.namelist():
  assert name.startswith('ineed-creator/') and '..' not in Path(name).parts
  assert not any(x in name.split('/') for x in ('.git','.env','node_modules','.godot','__pycache__'))
 assert 'ineed-creator/skills/engines/godot/plugin/ineed.gd' in full.namelist()
for filename in ['manifest.json','markdown-manifest.json']:
 m=json.loads((root/'dist'/filename).read_text());p=root/'dist'/m['file']
 assert m['sha256']==hashlib.sha256(p.read_bytes()).hexdigest()
 assert m['size']==p.stat().st_size
print('Deterministic ZIPs, Markdown equivalence and manifests verified')
