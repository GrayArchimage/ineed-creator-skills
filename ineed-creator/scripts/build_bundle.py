#!/usr/bin/env python3
"""Deterministic release ZIP: identical bytes are vendored into the platform."""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]; out=root.parent/'dist';out.mkdir(exist_ok=True)
catalog=json.loads((root/'catalog.json').read_text()); version=catalog['version']
file=out/'ineed-creator.zip'
with zipfile.ZipFile(file,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for p in sorted(root.rglob('*')):
  if not p.is_file() or p.name.endswith('.ineed-backup') or p.name == 'ineed-integration-report.json' or any(x in p.parts for x in ['__pycache__','.godot','.DS_Store']):continue
  entry=zipfile.ZipInfo('ineed-creator/'+p.relative_to(root).as_posix(),(2026,1,1,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o100644<<16
  z.writestr(entry,p.read_bytes(),compresslevel=9)
manifest={'version':version,'file':file.name,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'size':file.stat().st_size,'protocolMajor':1}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');(out/'SHA256SUMS').write_text(manifest['sha256']+'  '+file.name+'\n');print(json.dumps(manifest))
