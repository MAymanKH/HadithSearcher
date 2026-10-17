#!/usr/bin/env python3
"""Prefer rounded icons while preserving outlines without rounded variants."""

import re
from pathlib import Path


OUTLINED_EXCEPTIONS = {
    "account_tree_outlined",
    "article_outlined",
    "copy_outlined",
    "fact_check_outlined",
    "library_books_outlined",
    "menu_book_outlined",
    "restore_outlined",
    "search_outlined",
    "settings_outlined",
    "share_outlined",
}


def main():
    root = Path(__file__).resolve().parents[1]
    violations = []
    count = 0
    for path in sorted((root / "lib").rglob("*.dart")):
        for line_number, line in enumerate(path.read_text().splitlines(), 1):
            for name in re.findall(r"\bIcons\.(\w+)", line):
                count += 1
                if not name.endswith("_rounded") and name not in OUTLINED_EXCEPTIONS:
                    violations.append(
                        f"{path.relative_to(root)}:{line_number}: Icons.{name}"
                    )
    if violations:
        print("Use rounded icons or approved outlined exceptions:\n" + "\n".join(violations))
        return 1
    print(f"All {count} app Material icon references follow the icon style.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
