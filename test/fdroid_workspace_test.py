"""Exercise the fixed-path F-Droid workspace without invoking Flutter."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "fdroid_build", Path(__file__).resolve().parents[1] / "scripts/build_fdroid_unsigned.py"
)
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class FdroidWorkspaceTest(unittest.TestCase):
    def test_workspace_is_unsigned_and_cleaned_on_success_or_failure(self):
        for failure in (False, True):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / "source"
                workspace = Path(directory) / "fixed-path"
                files = {
                    ".flutter/bin/flutter": "",
                    "android/app/build.gradle.kts": 'keep\n"playImplementation"("play")\n',
                    "android/app/src/play/Play.kt": "play code",
                    "pubspec.yaml": "version: 3.0.0+19\n",
                    "android/key.properties": "private credentials",
                }
                for name, text in files.items():
                    target = root / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text(text)

                def run(args, **kwargs):
                    self.assertEqual(kwargs["cwd"], workspace)
                    self.assertEqual(args[0], str(root / ".flutter/bin/flutter"))
                    self.assertFalse((workspace / "android/key.properties").exists())
                    self.assertFalse((workspace / "android/app/src/play").exists())
                    self.assertEqual((workspace / "android/app/build.gradle.kts").read_text(), "keep\n")
                    self.assertTrue((workspace / ".flutter").is_symlink())
                    if args[1] == "build":
                        self.assertIn("--dart-define=UPDATE_CHANNEL=fdroid", args)
                        if failure:
                            raise subprocess.CalledProcessError(1, args)
                        output = workspace / build.OUTPUT
                        output.parent.mkdir(parents=True)
                        output.write_bytes(b"unsigned APK")
                    else:
                        self.assertEqual(args[1:], ["pub", "get", "--enforce-lockfile"])

                tracked = "\0".join(name for name in files if name not in (
                    "android/key.properties", ".flutter/bin/flutter",
                )).encode()
                with patch.object(build, "ROOT", root), patch.object(
                    build, "WORKSPACE", workspace
                ), patch.object(build.subprocess, "check_output", return_value=tracked), patch.object(
                    build.subprocess, "run", side_effect=run
                ):
                    if failure:
                        with self.assertRaises(subprocess.CalledProcessError):
                            build.main()
                        self.assertFalse((root / build.OUTPUT).exists())
                    else:
                        build.main()
                        self.assertEqual((root / build.OUTPUT).read_bytes(), b"unsigned APK")
                self.assertFalse(workspace.exists())

    def test_existing_workspace_is_left_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            (workspace / ".flutter/bin").mkdir(parents=True)
            (workspace / ".flutter/bin/flutter").touch()
            with patch.object(build, "ROOT", workspace), patch.object(build, "WORKSPACE", workspace):
                with self.assertRaises(FileExistsError):
                    build.main()
            self.assertTrue((workspace / ".flutter/bin/flutter").exists())


if __name__ == "__main__":
    unittest.main()
