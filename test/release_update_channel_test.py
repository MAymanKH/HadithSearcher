"""Check the release script embeds the correct channel before signing."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "release", Path(__file__).resolve().parents[1] / "scripts/release.py"
)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseUpdateChannelTest(unittest.TestCase):
    def test_unsigned_builds_embed_their_channel(self):
        for channel in ("fdroid", "github"):
            with self.subTest(channel=channel), patch.object(release, "run") as run, patch.object(release, "verify_artifact"):
                release.build_unsigned_apk(channel=channel)
                run.assert_called_once_with(
                    "flutter", "build", "apk", "--release", "--flavor", "fdroid",
                    f"--dart-define=UPDATE_CHANNEL={channel}",
                )


if __name__ == "__main__":
    unittest.main()
