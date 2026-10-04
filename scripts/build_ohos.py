#!/usr/bin/env python3
"""Build OHOS in a separate checkout so its Flutter SDK cannot replace desktop dependencies."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default=os.environ.get('FLUTTER_OHOS'), help='OHOS Flutter executable')
    parser.add_argument('--build-mode', choices=['debug', 'release'], default='debug')
    parser.add_argument('--unsigned', action='store_true', help='Use the public profile instead of local signing')
    args = parser.parse_args()
    flutter = shutil.which(args.flutter or '')
    cli = shutil.which('devecocli')
    npm = shutil.which('npm')
    if not flutter or not cli or not npm:
        raise SystemExit('Provide --flutter <OHOS Flutter executable>; install DevEco CLI and Node.js')
    sdk_root = Path(flutter).resolve().parents[1]
    plugin = sdk_root / 'packages/flutter_tools/hvigor'
    if not plugin.is_dir():
        raise SystemExit('This Flutter SDK does not contain the OHOS Hvigor plugin')
    env = dict(os.environ)
    if not env.get('HOS_SDK_HOME') and env.get('DEVECO_HOME'):
        env['HOS_SDK_HOME'] = str(Path(env['DEVECO_HOME']) / 'sdk')
    if not env.get('HOS_SDK_HOME') or not Path(env['HOS_SDK_HOME']).is_dir():
        raise SystemExit('Set HOS_SDK_HOME to the DevEco Studio SDK directory')
    stage = ROOT / '.codex_staging/ohos-validation'
    stage.mkdir(parents=True, exist_ok=True)
    ignore = shutil.ignore_patterns('build', 'node_modules', 'oh_modules', '.hvigor', '.cxx',
                                   '.idea', 'local.properties', 'package.json', 'package-lock.json',
                                   'build-profile.template.json5')
    for name in ['lib', 'assets', 'ohos']:
        shutil.copytree(ROOT / name, stage / name, dirs_exist_ok=True, ignore=ignore)
    for name in ['pubspec.yaml', '.metadata']:
        shutil.copy2(ROOT / name, stage / name)
    local = ROOT / 'ohos/build-profile.json5'
    profile = local if local.exists() and not args.unsigned else ROOT / 'ohos/build-profile.template.json5'
    shutil.copy2(profile, stage / 'ohos/build-profile.json5')
    (stage / 'ohos/package.json').write_text(json.dumps({
        'dependencies': {'flutter-hvigor-plugin': 'file:' + plugin.as_posix()}
    }, indent=2), encoding='utf-8')
    (stage / 'ohos/local.properties').write_text(
        'flutter.sdk=' + sdk_root.as_posix() + '\nhwsdk.dir=' + Path(env['HOS_SDK_HOME']).as_posix() + '\n',
        encoding='utf-8')
    subprocess.run([flutter, 'pub', 'get'], cwd=stage, env=env, check=True)
    subprocess.run([flutter, 'precache', '--ohos'], cwd=stage, env=env, check=True)
    subprocess.run([npm, 'install', '--ignore-scripts'], cwd=stage / 'ohos', env=env, check=True)
    subprocess.run([cli, 'build', '--modules', 'entry', '--build-mode', args.build_mode],
                   cwd=stage / 'ohos', env=env, check=True)
    output = ROOT / 'dist/ohos'
    output.mkdir(parents=True, exist_ok=True)
    products = stage / 'ohos/entry/build/default/outputs/default'
    unsigned = args.unsigned or not local.exists()
    artifacts = list(products.glob('*-unsigned.hap' if unsigned else '*.hap'))
    if not artifacts:
        raise SystemExit('Build finished without a HAP artifact')
    for artifact in artifacts:
        with zipfile.ZipFile(artifact) as package:
            bundled = package.read('libs/arm64-v8a/libopenp2p_ohos.so')
        expected = (ROOT / 'ohos/entry/libs/arm64-v8a/libopenp2p_ohos.so').read_bytes()
        if hashlib.sha256(bundled).digest() != hashlib.sha256(expected).digest():
            raise SystemExit('HAP OpenP2P runtime differs from the supplied reference library')
        target = output / artifact.name
        shutil.copy2(artifact, target)
        print(target)


if __name__ == '__main__':
    main()
