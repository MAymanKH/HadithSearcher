"""Check shared FOSS ABI artifacts are verified and signed before publishing."""
import importlib.util
from pathlib import Path
import shutil
import sys
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "release", Path(__file__).resolve().parents[1] / "scripts/release.py"
)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseUpdateChannelTest(unittest.TestCase):
    def test_unsigned_foss_build_produces_three_abi_outputs(self):
        with patch.object(release, "run") as run, patch.object(release, "verify_artifact") as verify:
            apks = release.build_unsigned_apks()
            run.assert_called_once_with(sys.executable, str(release.ROOT / "scripts/build_foss_unsigned.py"))
            self.assertEqual(set(apks), set(release.ABI_CODES))
            self.assertEqual(verify.call_count, 3)

    def test_all_abis_are_signed_before_publication(self):
        for abi, suffix in release.ABI_CODES.items():
            with self.subTest(abi=abi), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "android/app").mkdir(parents=True)
                (root / "android/app/release.keystore").touch()
                (root / "android/key.properties").write_text(
                    "storeFile=release.keystore\nstorePassword=store-secret\n"
                    "keyAlias=release\nkeyPassword=key-secret\n"
                )
                (root / "android/local.properties").write_text(f"sdk.dir={root / 'sdk'}\n")
                tools = root / "sdk/build-tools/37.0.0"
                tools.mkdir(parents=True)
                for name in ("apksigner", "zipalign"):
                    (tools / name).touch()
                unsigned = root / "unsigned.apk"
                unsigned.write_bytes(b"unsigned APK")

                def run(*args):
                    if args[1] == "-P" and "-f" in args:
                        shutil.copyfile(args[-2], args[-1])

                def sign(args, **kwargs):
                    self.assertEqual(args[:2], [str(tools / "apksigner"), "sign"])
                    self.assertIn("--alignment-preserved", args)
                    self.assertEqual(kwargs["env"]["HADITH_STORE_PASSWORD"], "store-secret")
                    self.assertEqual(kwargs["env"]["HADITH_KEY_PASSWORD"], "key-secret")
                    self.assertNotIn("store-secret", args)
                    self.assertNotIn("key-secret", args)
                    Path(args[args.index("--out") + 1]).write_bytes(b"signed APK")

                with patch.object(release, "ROOT", root), patch.object(
                    release, "build_unsigned_apks", return_value={abi: unsigned}
                ) as build, patch.object(release, "run", side_effect=run) as commands, patch.object(
                    release.subprocess, "run", side_effect=sign
                ), patch.object(release, "verify_artifact"):
                    release.build_foss("3.0.1+200")
                    build.assert_called_once_with()
                    self.assertEqual(
                        (root / f"build/releases/foss/HadithSearcher-3.0.1+{200 + suffix}-foss-{abi}.apk").read_bytes(),
                        b"signed APK",
                    )
                    self.assertEqual(commands.call_args_list[1].args[1:3], ("verify", "--verbose"))

                    def fail_verification(*args):
                        if args[1] == "verify":
                            raise subprocess.CalledProcessError(1, args)
                        run(*args)

                    commands.side_effect = fail_verification
                    with patch.object(release, "keep_artifact") as publish:
                        with self.assertRaises(subprocess.CalledProcessError):
                            release.build_foss("3.0.1+210")
                        publish.assert_not_called()


if __name__ == "__main__":
    unittest.main()
