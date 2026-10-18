"""Keep Play builds off the system temporary filesystem."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "release", Path(__file__).resolve().parents[1] / "scripts/release.py"
)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseWorkspaceTest(unittest.TestCase):
    def test_play_workspace_location_and_cleanup(self):
        for mode in ("release", "patch", "failure"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "android/app").mkdir(parents=True)
                (root / "android/app/test.keystore").touch()
                (root / "android/app/build.gradle").touch()
                (root / "android/key.properties").write_text("storeFile=test.keystore\n")
                (root / "pubspec.yaml").write_text("flutter:\n  assets:\n" + release.PLAY_ASSET)
                workspace = None

                def build(*args, cwd):
                    nonlocal workspace
                    workspace = cwd
                    self.assertEqual(workspace.parent, root / "build")
                    self.assertTrue(workspace.is_dir())
                    self.assertIn("    - shorebird.yaml\n", (workspace / "pubspec.yaml").read_text())
                    if mode == "failure":
                        raise subprocess.CalledProcessError(1, args)
                    if mode == "release":
                        bundle = workspace / "build/app/outputs/bundle/playRelease/app-play-release.aab"
                        bundle.parent.mkdir(parents=True)
                        bundle.write_bytes(b"test bundle")

                with patch.object(release, "ROOT", root), patch.object(
                    release.subprocess, "check_output",
                    return_value=b"pubspec.yaml\0android/app/build.gradle\0"
                ), patch.object(release, "run", side_effect=build), patch.object(
                    release, "verify_artifact"
                ):
                    if mode == "failure":
                        with self.assertRaises(subprocess.CalledProcessError):
                            release.build_play("1.0.0+1", True)
                    else:
                        release.build_play("1.0.0+1", True, patch=mode == "patch")

                self.assertIsNotNone(workspace)
                self.assertFalse(workspace.exists())
                self.assertIn(release.PLAY_ASSET, (root / "pubspec.yaml").read_text())
                if mode == "release":
                    self.assertEqual(
                        (root / "build/releases/play/HadithSearcher-1.0.0+1-play.aab").read_bytes(),
                        b"test bundle",
                    )


if __name__ == "__main__":
    unittest.main()
