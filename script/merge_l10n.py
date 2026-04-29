#!/usr/bin/env python3
"""
Merge YAML localization files + a Basic.xcstrings into a target .xcstrings file.

Usage:
  merge_l10n.py <source_dir> <target> [--basic <basic_xcstrings>]

  source_dir   Directory containing YAML localization files
               (e.g. l10n)
  target       Output .xcstrings file
               (e.g. agent-battery/Shared/Localization/Localizable.xcstrings)
  --basic      Optional base .xcstrings file whose entries take priority
               over YAML (e.g. l10n/Basic.xcstrings)

Directory → key convention:
  <source_dir>/settings/menu.yaml  →  xcstrings key: settings.menu.<yaml_key>

YAML file format:
  add:
    en: "Add Pet"
    zh: "添加宠物"

Language mapping (YAML → xcstrings):
  zh  →  zh-Hans

Conflict rule:
  Basic.xcstrings entries always win. YAML only fills in missing keys or
  missing language translations.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Tuple

import yaml

LANG_MAP = {
    "zh": "zh-Hans",
}


def xcstrings_lang(lang):
    # type: (str) -> str
    return LANG_MAP.get(lang, lang)


def load_xcstrings(path):
    # type: (Path) -> dict
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def save_xcstrings(data, path):
    # type: (dict, Path) -> None
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=False)
        f.write("\n")


def remove_suffix(s, suffix):
    # type: (str, str) -> str
    if suffix and s.endswith(suffix):
        return s[: -len(suffix)]
    return s


def key_prefix(yaml_path, source_dir):
    # type: (Path, Path) -> str
    """
    Convert a yaml file path relative to source_dir into a dot-separated prefix.

    Example:
      source_dir = /…/Simplfy
      yaml_path  = /…/Simplfy/profile/pet.yaml
      → "profile.pet"
    """
    rel = yaml_path.relative_to(source_dir)
    parts = list(rel.parts)
    stem = remove_suffix(remove_suffix(parts[-1], ".yaml"), ".yml")
    parts[-1] = stem
    return ".".join(parts)


def collect_entries(source_dir):
    # type: (Path) -> Dict[str, Dict[str, str]]
    """
    Walk source_dir for *.yaml / *.yml files and return a flat dict:
      { "profile.pet.add": {"en": "Add Pet", "zh-Hans": "添加宠物"}, … }
    """
    entries = {}
    yaml_files = sorted(source_dir.rglob("*.yaml")) + sorted(source_dir.rglob("*.yml"))
    for yaml_file in yaml_files:
        prefix = key_prefix(yaml_file, source_dir)
        with yaml_file.open(encoding="utf-8") as f:
            data = yaml.safe_load(f)
        if not isinstance(data, dict):
            print(
                "[warn] {}: expected a mapping, skipping".format(yaml_file),
                file=sys.stderr,
            )
            continue
        for key, translations in data.items():
            if not isinstance(translations, dict):
                print(
                    "[warn] {}: key '{}' value is not a mapping, skipping".format(
                        yaml_file, key
                    ),
                    file=sys.stderr,
                )
                continue
            full_key = "{}.{}".format(prefix, key)
            entries[full_key] = {
                xcstrings_lang(lang): str(value)
                for lang, value in translations.items()
                if value is not None
            }
    return entries


def merge(base_data, yaml_entries):
    # type: (dict, Dict[str, Dict[str, str]]) -> Tuple[int, int]
    """
    Merge yaml_entries into base_data in-place.

    base_data is the authoritative source (Basic.xcstrings content or an
    already-populated xcstrings dict). YAML only fills in missing keys /
    missing language translations — it never overwrites existing values.

    Returns (added_keys, added_translations) counts.
    """
    strings = base_data.setdefault("strings", {})
    added_keys = 0
    added_translations = 0

    for key in sorted(yaml_entries):
        translations = yaml_entries[key]
        if key not in strings:
            strings[key] = {
                "extractionState": "manual",
                "localizations": {
                    lang: {"stringUnit": {"state": "translated", "value": value}}
                    for lang, value in translations.items()
                },
            }
            added_keys += 1
            added_translations += len(translations)
        else:
            # Key exists in base — only fill missing languages
            existing_locs = strings[key].setdefault("localizations", {})
            for lang, value in translations.items():
                if lang not in existing_locs:
                    existing_locs[lang] = {
                        "stringUnit": {"state": "translated", "value": value}
                    }
                    added_translations += 1
                # else: base already has this language → keep it

    return added_keys, added_translations


def main():
    parser = argparse.ArgumentParser(
        description="Merge YAML localization files (+ optional Basic.xcstrings) into a target .xcstrings file."
    )
    parser.add_argument(
        "source_dir",
        type=Path,
        help="Directory containing YAML localization files (e.g. Shared/Localization/Simplfy)",
    )
    parser.add_argument(
        "target",
        type=Path,
        help="Output .xcstrings file (e.g. Shared/Localization/Localizable.xcstrings)",
    )
    parser.add_argument(
        "--basic",
        type=Path,
        default=None,
        metavar="BASIC_XCSTRINGS",
        help="Base .xcstrings file whose entries take priority over YAML (e.g. Shared/Localization/Basic.xcstrings)",
    )
    args = parser.parse_args()

    source_dir = args.source_dir.resolve()
    target = args.target.resolve()

    if not source_dir.is_dir():
        print(
            "[error] source_dir does not exist or is not a directory: {}".format(source_dir),
            file=sys.stderr,
        )
        sys.exit(1)

    # Start from Basic.xcstrings if provided, otherwise a minimal skeleton
    if args.basic is not None:
        basic_path = args.basic.resolve()
        if not basic_path.is_file():
            print(
                "[error] --basic file does not exist: {}".format(basic_path),
                file=sys.stderr,
            )
            sys.exit(1)
        print("Basic  : {}".format(basic_path))
        base_data = load_xcstrings(basic_path)
    else:
        # No basic file: start from scratch (or load existing target if present)
        if target.is_file():
            base_data = load_xcstrings(target)
        else:
            base_data = {"sourceLanguage": "en", "strings": {}, "version": "1.0"}

    print("Source : {}".format(source_dir))
    print("Target : {}".format(target))

    entries = collect_entries(source_dir)
    print("Collected {} keys from YAML files".format(len(entries)))

    added_keys, added_translations = merge(base_data, entries)
    save_xcstrings(base_data, target)

    print(
        "Done — added {} new keys, {} new translations → {} total keys".format(
            added_keys, added_translations, len(base_data.get("strings", {}))
        )
    )


if __name__ == "__main__":
    main()
