#!/usr/bin/env python3
"""Verify incoming text shares on an installed app with consent already chosen."""
import argparse
import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET

PACKAGE = 'com.moaymandev.hadithsearcher'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True)
    args = parser.parse_args()
    adb = ['adb', '-s', args.serial]

    def shell(*command):
        return subprocess.check_output(adb + ['shell', shlex.join(command)], text=True)

    def snapshot():
        shell('uiautomator', 'dump', '/sdcard/hadith-share-check.xml')
        return ET.fromstring(shell('cat', '/sdcard/hadith-share-check.xml'))

    def wait_for_text(text):
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                root = snapshot()
                if any(text in node.get('text', '') or text in node.get('content-desc', '') for node in root.iter('node')):
                    return root
            except (subprocess.CalledProcessError, ET.ParseError):
                pass
            time.sleep(.5)
        raise RuntimeError(f'Shared text did not appear: {text}. Choose telemetry consent before running this check.')

    def share(text):
        shell('am', 'start', '-n', f'{PACKAGE}/.MainActivity', '-a', 'android.intent.action.SEND',
              '-t', 'text/plain', '--es', 'android.intent.extra.TEXT', text)

    shell('am', 'force-stop', PACKAGE)
    share('cold share verification phrase')
    root = wait_for_text('cold share verification phrase')
    print('PASS: cold launch presents the shared phrase for editing')
    for node in root.iter('node'):
        if 'الإعدادات' in node.get('content-desc', ''):
            coordinates = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
            if len(coordinates) == 4:
                left, top, right, bottom = coordinates
                shell('input', 'tap', str((left + right) // 2), str((top + bottom) // 2))
                break
    shell('input', 'keyevent', 'KEYCODE_HOME')
    share('warm share verification phrase')
    wait_for_text('warm share verification phrase')
    print('PASS: warm launch returns to search with the new shared phrase')


if __name__ == '__main__':
    main()
