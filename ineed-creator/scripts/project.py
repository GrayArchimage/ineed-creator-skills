#!/usr/bin/env python3
"""Read-only inspection and idempotent Godot bridge installation; no project code execution."""
import argparse, hashlib, json, re, shutil, zipfile
from pathlib import Path, PurePosixPath
BUNDLE = Path(__file__).resolve().parents[1]
def inspect(target):
    target=Path(target)
    if target.is_file():
        with zipfile.ZipFile(target) as z:
            infos=z.infolist()
            if len(infos)>10000 or sum(i.file_size for i in infos)>1024**3: raise ValueError('Source archive exceeds inspection limits')
            names=[i.filename for i in infos]
            if any(PurePosixPath(n).is_absolute() or '..' in PurePosixPath(n).parts for n in names):raise ValueError('Unsafe ZIP path')
            config=next((z.read(i).decode('utf8') for i in infos if i.filename.endswith('/project.godot') or i.filename=='project.godot'),'')
    else:
        names=[str(p.relative_to(target)) for p in target.rglob('*') if p.is_file() and '.godot' not in p.relative_to(target).parts]
        config=(target/'project.godot').read_text() if (target/'project.godot').exists() else ''
    engine='godot-source' if config else 'godot-export' if any(re.search(r'\.pck(?:\.(br|gz))?$',n) for n in names) else 'web'
    return {'engine':engine,'fileCount':len(names),'csharp':any(n.endswith('.cs') for n in names),'hasExportPresets':any(n.endswith('export_presets.cfg') for n in names),'developmentAutoload':bool(re.search(r'^.*mcp.*=',config,re.M)),'mode':'source-integration' if config else 'hosting-only','nextSkill':'skills/engines/godot/SKILL.md' if engine.startswith('godot') else 'skills/engines/web/SKILL.md'}
def install(target):
    target=Path(target).resolve(); project=target/'project.godot'
    if not project.is_file(): raise ValueError('Godot source project required')
    if list(target.glob('*.csproj')): raise ValueError('First release supports GDScript only; .NET Web export is not supported')
    text=project.read_text(); key='INeed'; registration='INeed="*res://addons/ineed/ineed.gd"'
    section=re.search(r'^\[autoload\]\s*\n(.*?)(?=^\[|\Z)',text,re.M|re.S)
    existing=re.search(r'^INeed=.*$',section.group(1),re.M) if section else None
    if existing and existing.group(0)!=registration:raise ValueError('Existing INeed Autoload conflicts; preserve it and resolve explicitly')
    plugin=target/'addons/ineed/ineed.gd'; source=BUNDLE/'skills/engines/godot/plugin/ineed.gd'
    if plugin.exists() and plugin.read_bytes()!=source.read_bytes():raise ValueError('Existing plugin differs; review compatibility before replacing it')
    if not existing:
        backup=project.with_name('project.godot.ineed-backup')
        if not backup.exists():shutil.copy2(project,backup)
        if section:text=text[:section.end()]+registration+'\n\n'+text[section.end():]
        else:text+='\n[autoload]\n\n'+registration+'\n'
        project.write_text(text)
    plugin.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,plugin)
    report={'pluginVersion':'0.1.1','protocol':1,'autoload':'INeed','pluginSha256':hashlib.sha256(plugin.read_bytes()).hexdigest(),'pending':['Bind real game start/end/save/pause events','Confirm product, leaderboard and reward placement settings','Choose game UI or platform UI; default platform','Export and test both data and platform UI paths']}
    (target/'ineed-integration-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    return report
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['inspect','install']);p.add_argument('target');a=p.parse_args()
    print(json.dumps((inspect if a.action=='inspect' else install)(a.target),ensure_ascii=False,indent=2))
