"""Package Tuantuan on macOS; optionally embed a framework Python and Laya.

UI-only: python3 package.py
Full:    .venv/bin/python package.py --with-laya --model-dir models/laya-multilingual-mlx

Run the full build with the environment containing runtime/requirements.txt.
No package or model downloads are performed by this script.
"""
from pathlib import Path
import argparse
import os
import platform
import plistlib
import shutil
import subprocess
import sys
import sysconfig

SOURCE = Path(__file__).resolve().parent
MAGIC = (b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca')


def run(*args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def is_macho(path):
    if not path.is_file() or path.is_symlink():
        return False
    with path.open('rb') as stream:
        return stream.read(4) in MAGIC


def embed_python(destination, framework, packages):
    version = f'{sys.version_info.major}.{sys.version_info.minor}'
    (destination / 'bin').mkdir(parents=True)
    (destination / 'lib').mkdir()
    # Use the real interpreter, not Homebrew's Python.app launcher stub.
    shutil.copy2(framework / 'Resources/Python.app/Contents/MacOS/Python', destination / 'bin/python3')
    library = destination / 'lib' / f'libpython{version}.dylib'
    shutil.copy2(framework / 'Python', library)
    stdlib = destination / 'lib' / f'python{version}'
    shutil.copytree(framework / 'lib' / f'python{version}', stdlib,
                    ignore=shutil.ignore_patterns('site-packages', '__pycache__', 'test', 'tests', 'config-*'))
    shutil.copytree(packages, stdlib / 'site-packages', ignore=shutil.ignore_patterns('__pycache__'))
    vendor = destination / 'lib/vendor'
    vendor.mkdir()
    pending = [path for path in destination.rglob('*') if is_macho(path)]
    seen = set()
    originals = {}
    while pending:
        binary = pending.pop()
        if binary in seen:
            continue
        seen.add(binary)
        dependencies = subprocess.check_output(['otool', '-L', str(binary)], text=True).splitlines()[1:]
        for line in dependencies:
            dep = line.strip().split(' (')[0]
            if not dep.startswith('/') or dep.startswith(('/usr/lib/', '/System/Library/')):
                continue
            if dep.endswith('/Python'):
                target = library
            else:
                original = Path(dep).resolve()
                target = vendor / original.name
                if target.name in originals and originals[target.name] != original:
                    raise RuntimeError(f'Dylib name collision: {original}')
                originals[target.name] = original
                if not target.exists():
                    shutil.copy2(original, target)
                    pending.append(target)
            new = '@loader_path/' + os.path.relpath(target, binary.parent)
            run('install_name_tool', '-change', dep, new, binary)
        if binary.suffix == '.dylib':
            run('install_name_tool', '-id', '@rpath/' + binary.name, binary)
        run('codesign', '--force', '--sign', '-', binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--with-laya', action='store_true', help='embed Python dependencies and local model weights')
    parser.add_argument('--model-dir', type=Path, default=SOURCE / 'models/laya-multilingual-mlx')
    parser.add_argument('--python-framework', type=Path, default=Path(sys.base_prefix), help='framework version directory containing Python and lib/')
    parser.add_argument('--site-packages', type=Path, default=Path(sysconfig.get_paths()['purelib']))
    parser.add_argument('--output', type=Path, default=SOURCE / 'dist/团团.app')
    parser.add_argument('--disable-swift-sandbox', action='store_true', help='for build hosts already running inside a sandbox')
    args = parser.parse_args()
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        parser.error('This packaging recipe currently supports Apple Silicon macOS only.')
    app = args.output.resolve()
    if app.suffix != '.app':
        parser.error('--output must end in .app')
    if app.exists():
        parser.error(f'Output already exists; choose a new --output path: {app}')
    if args.with_laya:
        required = [args.python_framework / 'Python', args.python_framework / 'Resources/Python.app/Contents/MacOS/Python',
                    args.site_packages / 'laya_mlx', args.model_dir / 'model.safetensors', args.model_dir / 'mlx_config.json']
        for path in required:
            if not path.exists():
                parser.error(f'Missing required input: {path}')
    flags = ['-c', 'release']
    if args.disable_swift_sandbox:
        flags += ['--disable-sandbox', '-Xswiftc', '-module-cache-path', '-Xswiftc', str(SOURCE / '.build/module-cache')]
    run('swift', 'build', *flags, cwd=SOURCE)
    bin_dir = Path(subprocess.check_output(['swift', 'build', '-c', 'release', '--show-bin-path'], cwd=SOURCE, text=True).strip())
    resources = app / 'Contents/Resources'
    macos = app / 'Contents/MacOS'
    macos.mkdir(parents=True)
    resources.mkdir()
    shutil.copy2(bin_dir / 'Tuantuan', macos / 'Tuantuan')
    shutil.copy2(SOURCE / 'runtime/brain.py', resources / 'brain.py')
    shutil.copy2(SOURCE / 'THIRD_PARTY_NOTICES.md', resources / 'THIRD_PARTY_NOTICES.md')
    shutil.copytree(SOURCE / 'licenses', resources / 'licenses')
    if args.with_laya:
        embed_python(resources / 'python', args.python_framework.resolve(), args.site_packages.resolve())
        shutil.copytree(args.model_dir.resolve(), resources / 'model', ignore=shutil.ignore_patterns('.cache', '.git', '__pycache__'))
    info = {'CFBundleDevelopmentRegion': 'zh_CN', 'CFBundleDisplayName': '团团', 'CFBundleName': '团团',
            'CFBundleExecutable': 'Tuantuan', 'CFBundleIdentifier': 'local.tuantuan.desktop',
            'CFBundleVersion': '1', 'CFBundleShortVersionString': '0.1.0', 'CFBundlePackageType': 'APPL',
            'CFBundleIconFile': 'AppIcon', 'LSMinimumSystemVersion': '26.0' if args.with_laya else '14.0',
            'NSHighResolutionCapable': True}
    with (app / 'Contents/Info.plist').open('wb') as stream:
        plistlib.dump(info, stream)
    iconset = SOURCE / '.build/AppIcon.iconset'
    iconset.mkdir(parents=True, exist_ok=True)
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            name = f'icon_{size}x{size}' + ('@2x' if scale == 2 else '') + '.png'
            run('sips', '-z', size * scale, size * scale, SOURCE / 'Assets/AppIcon.png', '--out', iconset / name, stdout=subprocess.DEVNULL)
    run('iconutil', '-c', 'icns', iconset, '-o', resources / 'AppIcon.icns')
    run('codesign', '--force', '--deep', '--sign', '-', app)
    run('codesign', '--verify', '--deep', '--strict', app)
    print(app)


if __name__ == '__main__':
    main()
