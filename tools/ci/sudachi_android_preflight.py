#!/usr/bin/env python3
"""Preflight of Sudachi LowRAM's pinned Android CI deps. Runs only in CI."""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
ABS_INCLUDE = re.compile(r'^[ \t]*#[ \t]*include[ \t]*["<]([A-Za-z]:[/\\][^">\r\n]+)[">][ \t]*$', re.M)
SOURCE_EXT = {'.h', '.hpp', '.hxx', '.hh', '.cpp', '.cc', '.inl', '.inc'}
def check(condition, message):
    if not condition:
        raise RuntimeError(message)
def fix_windows_boost_forwarders(path):
    """Replace host-specific Boost forwarding includes with Clang's include_next."""
    try:
        content = path.read_text(encoding='utf-8')
    except (UnicodeError, OSError):
        return 0
    matches = list(ABS_INCLUDE.finditer(content))
    if not matches:
        return 0
    for match in reversed(matches):
        original = match.group(1)
        normalized = original.replace('\\', '/')
        if '/include/boost/' not in normalized:
            raise RuntimeError(f'Nonportable absolute header in {path}: {original}')
        relative = 'boost/' + normalized.rsplit('/include/boost/', 1)[1]
        if not re.fullmatch(r'boost/[A-Za-z0-9_./+-]+', relative):
            raise RuntimeError(f'Unexpected Boost include path in {path}: {original}')
        # Clang supports include_next. It skips the broken forwarded file in mcl's
        # include directory and loads actual Boost from vcpkg's arm64 include tree.
        content = content[:match.start()] + '#include_next <' + relative + '>' + content[match.end():]
        print(f'REPAIRED: {path.relative_to(ROOT)} -> {relative}')
    path.write_text(content, encoding='utf-8')
    return len(matches)
def main():
    print('Sudachi Android: full CI dependency preflight')
    check((ROOT / 'src/android/gradlew').is_file(), 'Gradle wrapper missing')
    check((ROOT / 'externals/vcpkg/.git').exists() or (ROOT / '.git/modules/externals/vcpkg').exists(), 'vcpkg submodule missing')
    check(shutil.which('glslangValidator'), 'Host glslangValidator missing')
    manifest_path = ROOT / 'vcpkg.json'
    check(manifest_path.is_file(), 'vcpkg manifest missing')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    names = {dep if isinstance(dep, str) else dep.get('name') for dep in manifest['dependencies']}
    check('boost-variant' in names, 'vcpkg manifest must include Boost Variant for Dynarmic')
    cmake = ROOT / 'CMakeModules/DownloadExternals.cmake'
    check(cmake.is_file() and 'Sudachi Galaxy LowRAM: FFmpeg Android bundle fallback' in cmake.read_text(encoding='utf-8'),
          'Android ARM64 FFmpeg fallback from previous fix is missing')
    gradle = ROOT / 'src/android/sudachi/build.gradle.kts'
    check('applicationIdSuffix = ".relWithDebInfo"' in gradle.read_text(encoding='utf-8'),
          'Separate APK package suffix missing: installation might overwrite original Sudachi')
    # Detect ALL include directives pointing to Windows paths in vendored Dynarmic,
    # not just the first bad boost/variant.hpp which made the previous run fail.
    vendor = ROOT / 'externals/dynarmic'
    check(vendor.is_dir(), 'Dynarmic submodule missing')
    repaired = 0
    scanned = 0
    for path in sorted(vendor.rglob('*')):
        if path.is_file() and path.suffix.lower() in SOURCE_EXT:
            scanned += 1
            repaired += fix_windows_boost_forwarders(path)
    print(f'Inspected {scanned} vendor source/header files; repaired {repaired} nonportable Boost includes.')
    if repaired:
        print('These temporary patches affect only the GitHub runner, not the pinned Git submodule.')
    check((ROOT / 'externals/dynarmic/externals/mcl/include').is_dir(), 'Nested Dynarmic mcl headers missing')
    output = subprocess.check_output(['git','submodule','status'], cwd=ROOT, text=True)
    for line in output.splitlines():
        if line and line[0] in '-+U':
            raise RuntimeError(f'Wrong/uninitialized pinned submodule: {line}')
    print('OK: Android tools, Boost manifest, FFmpeg fallback, APK isolation, and pinned submodules.')
if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('DEPENDENCY PREFLIGHT FAILED:', error, file=sys.stderr)
        sys.exit(1)
