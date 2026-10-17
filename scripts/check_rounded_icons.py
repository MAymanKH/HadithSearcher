#!/usr/bin/env python3
"""Check that app-owned Material icons use the rounded family."""

import re
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    violations = []
    count = 0
    for path in sorted((root / "lib").rglob("*.dart")):
        for line_number, line in enumerate(path.read_text().splitlines(), 1):
            for name in re.findall(r"\bIcons\.(\w+)", line):
                count += 1
                if not name.endswith("_rounded"):
                    violations.append(
                        f"{path.relative_to(root)}:{line_number}: Icons.{name}"
                    )
    if violations:
        print("Use rounded Material icons:\n" + "\n".join(violations))
        return 1
    print(f"All {count} app Material icon references use rounded variants.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
