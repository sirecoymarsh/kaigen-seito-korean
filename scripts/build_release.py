#!/usr/bin/env python3
"""Build hash-bound HDiffPatch payloads from an original game and verified release.
Neither original files nor rebuilt game archives belong in this repository.
"""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess

NAMES = ('cg.pak', 'data.pak', 'KaigenSeito.exe', 'script.pak', 'system.dll', 'system.pak')
ANCHORS = ('sound.pak', 'mpeg.pak')

def identity(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b''):
            digest.update(block)
    return {'size': path.stat().st_size, 'sha256': digest.hexdigest()}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--original', type=pathlib.Path, required=True)
    p.add_argument('--target', type=pathlib.Path, required=True)
    p.add_argument('--hdiffz', type=pathlib.Path, required=True)
    p.add_argument('--hpatchz', type=pathlib.Path, required=True)
    p.add_argument('--original-catalog', type=pathlib.Path, required=True)
    p.add_argument('--target-catalog', type=pathlib.Path, required=True)
    p.add_argument('--output', type=pathlib.Path, required=True)
    args = p.parse_args()
    old_catalog = json.loads(args.original_catalog.read_text(encoding='utf-8-sig'))
    new_catalog = json.loads(args.target_catalog.read_text(encoding='utf-8-sig'))
    # Fail before creating payloads if either input is not the reviewed snapshot.
    for name in (*NAMES, *ANCHORS):
        if identity(args.original / name) != old_catalog[name]:
            raise ValueError(f'Unrecognized original: {name}')
    for name in (*NAMES, *ANCHORS, 'ko.dll'):
        if identity(args.target / name) != new_catalog[name]:
            raise ValueError(f'Unrecognized target: {name}')
    for folder in ('patches', 'files', 'tools'):
        (args.output / folder).mkdir(parents=True, exist_ok=True)
    entries = []
    for name in NAMES:
        relative = f'patches/{name}.hdiff'
        patch = args.output / relative
        # hdiffz also applies and compares the generated patch unless -d is used.
        subprocess.run([str(args.hdiffz), '-c-zstd-12', '-p-2',
                        str(args.original / name), str(args.target / name), str(patch)], check=True)
        entries.append({'path': name, 'kind': 'delta', 'source': old_catalog[name],
                        'target': new_catalog[name], 'payload': relative, 'patch': identity(patch)})
    added = args.output / 'files/ko.dll'
    shutil.copy2(args.target / 'ko.dll', added)
    entries.append({'path': 'ko.dll', 'kind': 'added', 'target': new_catalog['ko.dll'],
                    'payload': 'files/ko.dll', 'patch': identity(added)})
    patcher = args.output / 'tools/hpatchz.exe'
    shutil.copy2(args.hpatchz, patcher)
    result = {
        'schema': 'kaigen-seito-korean-hdiff-v1',
        'version': 'v2026.11.25-r4a',
        'translator_model': 'Codex internal',
        'translation_provenance': 'Existing Codex-authored Korean localization and r4a integration snapshot; no scenario retranslation during packaging.',
        'patcher': {'path': 'tools/hpatchz.exe', 'version': 'HDiffPatch 5.1.3 windows64', **identity(patcher)},
        'unchanged': [{'path': name, **old_catalog[name]} for name in ANCHORS],
        'files': entries,
    }
    (args.output / 'manifest.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'status': 'PASS', 'delta_bytes': sum(e['patch']['size'] for e in entries if e['kind'] == 'delta')}, indent=2))

if __name__ == '__main__':
    main()