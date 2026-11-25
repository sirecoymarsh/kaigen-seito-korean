#!/usr/bin/env python3
"""Exercise installation/restoration without starting a game or reading personal saves."""
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--original', type=pathlib.Path, required=True)
p.add_argument('--package', type=pathlib.Path, required=True)
p.add_argument('--work', type=pathlib.Path, required=True)
p.add_argument('--report', type=pathlib.Path, required=True)
a = p.parse_args()
a.work.mkdir(parents=True, exist_ok=False)
fixture = a.work / '한글 경로 game'
fixture.mkdir()
manifest = json.loads((a.package / 'manifest.json').read_text(encoding='utf-8-sig'))
names = [e['path'] for e in manifest['files'] if e['kind'] == 'delta'] + [e['path'] for e in manifest['unchanged']]
for name in names:
    shutil.copy2(a.original / name, fixture / name)
(fixture / 'SAVE').mkdir()
(fixture / 'SAVE/retained.fixture').write_bytes(b'fake personal save sentinel\x00\xff')
(fixture / 'kaigen-mods.ini').write_bytes(b'[Test]\r\nKeepThis=1\r\n')
sentinels = ['SAVE/retained.fixture', 'kaigen-mods.ini']
def digest(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()
def snapshot(paths):
    return {n: digest(fixture / n) for n in paths}
originals = snapshot(names)
protected = snapshot(sentinels)
checks = []
ps = pathlib.Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
env = dict(os.environ, TEMP=str(a.work), TMP=str(a.work), PSModuleAnalysisCachePath=str(a.work / 'ps-module-cache'))
def invoke(action, success=True, package=None):
    package = package or a.package
    run = subprocess.run([str(ps), '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
                          '-File', str(package / 'scripts/Patch.ps1'), '-Action', action, '-GameDir', str(fixture)],
                         capture_output=True, env=env, creationflags=subprocess.CREATE_NO_WINDOW)
    text = (run.stdout + run.stderr).decode('utf-8', errors='replace')
    if (run.returncode == 0) != success:
        raise AssertionError(f'{action}: exit {run.returncode}\n{text}')
    if snapshot(sentinels) != protected:
        raise AssertionError('Save/settings sentinel changed')
    return text
invoke('Install')
for entry in manifest['files']:
    assert digest(fixture / entry['path']) == entry['target']['sha256'], entry['path']
assert snapshot([x['path'] for x in manifest['unchanged']]) == {x['path']: x['sha256'] for x in manifest['unchanged']}
checks.append('install: 7 changed/added files plus 2 unchanged files equal verified runtime hashes')
invoke('Verify')
checks.append('verify command accepts exact target')
assert 'ALREADY INSTALLED' in invoke('Install')
checks.append('repeat install is idempotent')
invoke('Restore')
assert snapshot(names) == originals and not (fixture / 'ko.dll').exists()
checks.append('restore: 6 originals restored and added DLL removed')
invoke('Restore')
assert snapshot(names) == originals
checks.append('repeat restore is idempotent')
# A mismatched original must be rejected without changing any other file.
bad = fixture / 'KaigenSeito.exe'
exe_bytes = bad.read_bytes()
bad.write_bytes(exe_bytes[:-1] + bytes([exe_bytes[-1] ^ 1]))
before = snapshot(names)
invoke('Install', False)
assert snapshot(names) == before and not (fixture / 'ko.dll').exists()
bad.write_bytes(exe_bytes)
checks.append('wrong original rejected before mutation')
# Corrupt only a temporary copy of the package, never the actual release payload.
bad_package = a.work / 'corrupt-package'
shutil.copytree(a.package, bad_package, ignore=shutil.ignore_patterns('.git', '__pycache__'))
bad_delta = bad_package / 'patches/system.pak.hdiff'
bad_delta.write_bytes(bad_delta.read_bytes() + b'corruption')
invoke('Install', False, bad_package)
assert snapshot(names) == originals and not (fixture / 'ko.dll').exists()
checks.append('corrupt delta rejected before mutation')
# An unrelated existing DLL must not be overwritten or removed.
(fixture / 'ko.dll').write_bytes(b'unrelated user plugin')
invoke('Install', False)
assert (fixture / 'ko.dll').read_bytes() == b'unrelated user plugin'
assert snapshot(names) == originals
(fixture / 'ko.dll').unlink()
checks.append('unrelated existing DLL preserved and rejected')
result = {
    'status': 'PASS', 'release': manifest['version'], 'date_kst': '2026-11-25',
    'checks': checks, 'save_and_settings_sentinels_unchanged': True,
    'personal_game_and_saves_accessed': False, 'game_started': False,
    'target_identity': {e['path']: e['target']['sha256'] for e in manifest['files']},
    'runtime_evidence': 'Reused prior r4a/r4b native verification; no new playthrough.',
    'ui_folder_picker': 'not interactively tested; command-line install/verify/restore tested under Windows PowerShell',
}
a.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, ensure_ascii=True, indent=2))