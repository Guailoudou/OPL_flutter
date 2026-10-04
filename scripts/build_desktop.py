#!/usr/bin/env python3
"""Build a complete portable desktop package, including the vendored P2P core."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def run(*args, cwd=ROOT, env=None):
    subprocess.run(list(args), cwd=cwd, env=env, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arch', choices=['x64', 'arm64'], default='x64')
    parser.add_argument('--skip-flutter', action='store_true', help='Package an existing release build')
    args = parser.parse_args()
    target = {'Windows': 'windows', 'Linux': 'linux', 'Darwin': 'macos'}[platform.system()]
    flutter = shutil.which('flutter')
    go = shutil.which('go')
    if not flutter or not go:
        raise SystemExit('Flutter and Go 1.20.x must be available on PATH')
    if not args.skip_flutter:
        run(flutter, 'pub', 'get')
        build_args = [flutter, 'build', target, '--release']
        if target == 'linux':
            build_args += ['--target-platform', f'{target}-{args.arch}']
        run(*build_args)

    if target == 'windows':
        bundle = ROOT / 'build/windows' / args.arch / 'runner/Release'
    elif target == 'linux':
        bundle = ROOT / 'build/linux' / args.arch / 'release/bundle'
    else:
        apps = list((ROOT / 'build/macos/Build/Products/Release').glob('*.app'))
        if len(apps) != 1:
            raise SystemExit('Expected exactly one release .app bundle')
        bundle = apps[0]
    if not bundle.is_dir():
        raise SystemExit(f'Release bundle not found: {bundle}')
    native = bundle / ('Contents/MacOS/OPL' if target == 'macos' else 'OPL')
    native.mkdir(parents=True, exist_ok=True)
    binary = native / ('openp2p-opl.exe' if target == 'windows' else 'openp2p-opl')
    env = dict(os.environ, GOOS={'macos': 'darwin'}.get(target, target),
               GOARCH={'x64': 'amd64', 'arm64': 'arm64'}[args.arch], CGO_ENABLED='0')
    run(go, 'build', '-trimpath', '-ldflags=-s -w', '-o', str(binary), './cmd',
        cwd=ROOT / 'third_party/openp2p', env=env)
    shutil.copy2(ROOT / 'third_party/openp2p/LICENSE', native / 'OpenP2P-LICENSE.txt')
    if target == 'windows':
        # Bundle the signed upstream driver so the core does not download a DLL at runtime.
        with urllib.request.urlopen('https://www.wintun.net/builds/wintun-0.14.1.zip', timeout=30) as response:
            driver_zip = response.read(4 * 1024 * 1024)
        if hashlib.sha256(driver_zip).hexdigest() != '07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51':
            raise SystemExit('Wintun archive checksum mismatch')
        import io
        with zipfile.ZipFile(io.BytesIO(driver_zip)) as archive:
            dll_arch = {'x64': 'amd64', 'arm64': 'arm64'}[args.arch]
            (native / 'wintun.dll').write_bytes(archive.read(f'wintun/bin/{dll_arch}/wintun.dll'))
            (native / 'Wintun-LICENSE.txt').write_bytes(archive.read('wintun/LICENSE.txt'))
    if target != 'windows':
        binary.chmod(0o755)
    if target == 'macos':
        run('codesign', '--force', '--sign', '-', str(binary))
        run('codesign', '--force', '--deep', '--sign', '-',
            '--preserve-metadata=entitlements,requirements,flags,runtime', str(bundle))
    output = ROOT / 'dist'
    output.mkdir(exist_ok=True)
    name = f'opl-{target}-{args.arch}'
    if target == 'windows':
        package = output / f'{name}.zip'
        with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as archive:
            for file in sorted(bundle.rglob('*')):
                if file.is_file():
                    archive.write(file, file.relative_to(bundle))
    else:
        package = output / f'{name}.tar.gz'
        with tarfile.open(package, 'w:gz', dereference=False) as archive:
            archive.add(bundle, arcname=bundle.name if target == 'macos' else name)
    with package.open('rb') as package_stream:
        digest = hashlib.file_digest(package_stream, 'sha256').hexdigest()
    (output / f'{package.name}.sha256').write_text(f'{digest}  {package.name}\n', encoding='utf-8')
    (output / f'{name}.json').write_text(json.dumps({
        'platform': target, 'architecture': args.arch, 'filename': package.name,
        'sha256': digest, 'openp2pBundled': True,
    }, indent=2) + '\n', encoding='utf-8')
    print(package)


if __name__ == '__main__':
    main()
