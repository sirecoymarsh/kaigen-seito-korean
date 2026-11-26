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
p.add_argument('--previous-package', type=pathlib.Path, help='an earlier release package to upgrade from')
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
def check(ok, message):
    if not ok:
        raise SystemExit('FAIL: ' + message)
ps = pathlib.Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
env = dict(os.environ, TEMP=str(a.work), TMP=str(a.work), PSModuleAnalysisCachePath=str(a.work / 'ps-module-cache'))
def invoke(action, success=True, package=None):
    package = package or a.package
    run = subprocess.run([str(ps), '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
                          '-File', str(package / 'scripts/Patch.ps1'), '-Action', action, '-GameDir', str(fixture)],
                         capture_output=True, env=env, creationflags=subprocess.CREATE_NO_WINDOW)
    text = (run.stdout + run.stderr).decode('oem', errors='replace')  # PowerShell 5.1 writes the console code page
    if (run.returncode == 0) != success:
        raise AssertionError(f'{action}: exit {run.returncode}\n{text}')
    if snapshot(sentinels) != protected:
        raise SystemExit('FAIL: save/settings sentinel changed')
    return text
if a.previous_package:
    invoke('Install', package=a.previous_package)
    check(digest(fixture / 'ko.dll') != next(e for e in manifest['files'] if e['path'] == 'ko.dll')['target']['sha256'], 'previous package installed')
    checks.append('previous release installed first; next install upgrades it in place')
invoke('Install')
for entry in manifest['files']:
    if entry['kind'] == 'delta':
        check(digest(fixture / '.kaigen-ko-backup' / entry['path']) == entry['source']['sha256'], 'original backup: ' + entry['path'])
checks.append('complete original backup verified, including mpeg.pak for legacy upgrades')
for entry in manifest['files']:
    check(digest(fixture / entry['path']) == entry['target']['sha256'], str(entry['path']))
check(snapshot([x['path'] for x in manifest['unchanged']]) == {x['path']: x['sha256'] for x in manifest['unchanged']}, "snapshot([x['path'] for x in manifest['unchanged']]) == {x['path']: x['sha256'] for x in manifest['unchanged']}")
checks.append(f"install: {len(manifest['files'])} changed/added files plus {len(manifest['unchanged'])} unchanged files equal verified runtime hashes")
invoke('Verify')
checks.append('verify command accepts exact target')
check('이미 설치됨' in invoke('Install'), 'repeat install reports already installed')
checks.append('repeat install is idempotent')
invoke('Restore')
check(snapshot(names) == originals and not (fixture / 'ko.dll').exists(), "snapshot(names) == originals and not (fixture / 'ko.dll').exists()")
checks.append(f"restore: {sum(e['kind']=='delta' for e in manifest['files'])} originals restored and added DLL removed")
invoke('Restore')
check(snapshot(names) == originals, 'snapshot(names) == originals')
checks.append('repeat restore is idempotent')
# A mismatched original must be rejected without changing any other file.
bad = fixture / 'KaigenSeito.exe'
exe_bytes = bad.read_bytes()
bad.write_bytes(exe_bytes[:-1] + bytes([exe_bytes[-1] ^ 1]))
before = snapshot(names)
invoke('Install', False)
check(snapshot(names) == before and not (fixture / 'ko.dll').exists(), "snapshot(names) == before and not (fixture / 'ko.dll').exists()")
bad.write_bytes(exe_bytes)
checks.append('wrong original rejected before mutation')
# Corrupt only a temporary copy of the package, never the actual release payload.
bad_package = a.work / 'corrupt-package'
shutil.copytree(a.package, bad_package, ignore=shutil.ignore_patterns('.git', '__pycache__'))
bad_delta = bad_package / 'patches/system.pak.hdiff'
bad_delta.write_bytes(bad_delta.read_bytes() + b'corruption')
invoke('Install', False, bad_package)
check(snapshot(names) == originals and not (fixture / 'ko.dll').exists(), "snapshot(names) == originals and not (fixture / 'ko.dll').exists()")
checks.append('corrupt delta rejected before mutation')
# An unrelated existing DLL must not be overwritten or removed.
(fixture / 'ko.dll').write_bytes(b'unrelated user plugin')
invoke('Install', False)
check((fixture / 'ko.dll').read_bytes() == b'unrelated user plugin', "(fixture / 'ko.dll').read_bytes() == b'unrelated user plugin'")
check(snapshot(names) == originals, 'snapshot(names) == originals')
(fixture / 'ko.dll').unlink()
checks.append('unrelated existing DLL preserved and rejected')
result = {
    'status': 'PASS', 'release': manifest['version'], 'date_kst': __import__('datetime').datetime.now().strftime('%Y-%m-%d'),
    'checks': checks, 'save_and_settings_sentinels_unchanged': True,
    'personal_game_and_saves_accessed': False, 'game_started': False,
    'target_identity': {e['path']: e['target']['sha256'] for e in manifest['files']},
    'runtime_evidence': 'Reused native verification is documented separately in docs/runtime-verification.json; this test does not launch the game.',
    'ui_folder_picker': 'not interactively tested; command-line install/verify/restore tested under Windows PowerShell',
}
a.report.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, ensure_ascii=True, indent=2))