#!/usr/bin/env python3
"""Deterministic, versioned full Skill and Markdown-only archives."""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
out=root.parent/'dist';out.mkdir(exist_ok=True)
catalog=json.loads((root/'catalog.json').read_text());version=catalog['version']
paths=[p for p in sorted(root.rglob('*')) if p.is_file() and not p.name.endswith('.ineed-backup') and p.name!='ineed-integration-report.json' and not any(x in p.parts for x in ['__pycache__','.godot','.DS_Store'])]
def archive(name,selected):
 file=out/name
 with zipfile.ZipFile(file,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for p in selected:
   entry=zipfile.ZipInfo('ineed-creator/'+p.relative_to(root).as_posix(),(2026,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o100644<<16
   z.writestr(entry,p.read_bytes(),compresslevel=9)
 return {'version':version,'file':file.name,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'size':file.stat().st_size,'protocolMajor':1}
full=archive('ineed-creator.zip',paths)
# The documentation archive preserves all Markdown paths and links. It contains
# no plugin, scripts or font binary, so it must never be advertised as installable.
markdown=archive('ineed-creator-markdown.zip',[p for p in paths if p.suffix=='.md'])
(out/'manifest.json').write_text(json.dumps(full,indent=2)+'\n')
(out/'markdown-manifest.json').write_text(json.dumps(markdown,indent=2)+'\n')
(out/'SHA256SUMS').write_text(''.join(x['sha256']+'  '+x['file']+'\n' for x in [full,markdown]))
print(json.dumps({'skill':full,'markdown':markdown}))
