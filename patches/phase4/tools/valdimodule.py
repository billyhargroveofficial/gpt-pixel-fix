#!/usr/bin/env python3
"""Deterministic reader/writer for Snapchat Valdi .valdimodule archives.

The archive layout is taken from ValdiModuleBuilder.swift:

    magic 0x0100c633 (little-endian bytes 33 c6 00 01)
    uint32 payload_size
    repeated:
        padded byte string: path
        padded byte string: entry contents

A padded byte string has a little-endian uint32 length. Bit 31 means that
zero padding up to a four-byte boundary follows the payload.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import struct
import subprocess
import sys
import tempfile
from typing import Iterable


VALDI_MAGIC = b"\x33\xc6\x00\x01"
PRECOMPILED_JS_MAGIC = b"\x34\xc6\x00\x01"
ZSTD_MAGIC = b"\x28\xb5\x2f\xfd"
PADDING_BIT = 0x80000000
SIZE_MASK = 0x7FFFFFFF
MANIFEST_NAME = ".valdi-manifest.json"


class ArchiveError(RuntimeError):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def run_zstd_decompress(path: Path) -> bytes:
    result = subprocess.run(
        ["zstd", "-q", "-d", "-c", str(path)],
        check=True,
        stdout=subprocess.PIPE,
    )
    return result.stdout


def read_module(path: Path) -> bytes:
    data = path.read_bytes()
    if data.startswith(ZSTD_MAGIC):
        return run_zstd_decompress(path)
    return data


def read_u32(data: bytes, offset: int, label: str) -> tuple[int, int]:
    if offset + 4 > len(data):
        raise ArchiveError(f"truncated {label} at offset {offset}")
    return struct.unpack_from("<I", data, offset)[0], offset + 4


def read_valdi_data(data: bytes, offset: int, label: str) -> tuple[bytes, int]:
    raw_length, offset = read_u32(data, offset, f"{label} length")
    size = raw_length & SIZE_MASK
    end = offset + size
    if end > len(data):
        raise ArchiveError(
            f"truncated {label}: need {size} bytes at offset {offset}, "
            f"archive ends at {len(data)}"
        )
    value = data[offset:end]
    offset = end
    if raw_length & PADDING_BIT:
        padding = (-size) % 4
        padding_end = offset + padding
        if padding_end > len(data):
            raise ArchiveError(f"truncated padding after {label}")
        if data[offset:padding_end] != b"\x00" * padding:
            raise ArchiveError(f"non-zero padding after {label}")
        offset = padding_end
    elif size % 4:
        raise ArchiveError(
            f"{label} length {size} is unaligned but padding bit is clear"
        )
    return value, offset


def validate_entry_path(raw_path: bytes) -> str:
    try:
        path = raw_path.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ArchiveError(f"entry path is not UTF-8: {exc}") from exc
    pure = PurePosixPath(path)
    if not path or pure.is_absolute() or ".." in pure.parts or "." in pure.parts:
        raise ArchiveError(f"unsafe entry path: {path!r}")
    if "\\" in path:
        raise ArchiveError(f"entry path contains a backslash: {path!r}")
    return path


def parse_archive(data: bytes) -> list[tuple[str, bytes]]:
    if not data.startswith(VALDI_MAGIC):
        raise ArchiveError(
            f"bad Valdi magic: got {data[:4].hex()}, expected {VALDI_MAGIC.hex()}"
        )
    payload_size, offset = read_u32(data, 4, "archive payload")
    if payload_size != len(data) - 8:
        raise ArchiveError(
            f"payload size mismatch: header={payload_size}, actual={len(data) - 8}"
        )

    entries: list[tuple[str, bytes]] = []
    seen: set[str] = set()
    while offset < len(data):
        raw_path, offset = read_valdi_data(data, offset, "entry path")
        path = validate_entry_path(raw_path)
        if path in seen:
            raise ArchiveError(f"duplicate entry path: {path}")
        seen.add(path)
        contents, offset = read_valdi_data(data, offset, f"contents for {path}")
        entries.append((path, contents))

    if offset != len(data):
        raise ArchiveError(f"parser stopped at {offset}, archive ends at {len(data)}")
    return entries


def append_valdi_data(target: bytearray, value: bytes) -> None:
    if len(value) > SIZE_MASK:
        raise ArchiveError(f"entry too large: {len(value)} bytes")
    padding = (-len(value)) % 4
    length = len(value) | (PADDING_BIT if padding else 0)
    target.extend(struct.pack("<I", length))
    target.extend(value)
    target.extend(b"\x00" * padding)


def build_archive(entries: Iterable[tuple[str, bytes]]) -> bytes:
    payload = bytearray()
    for path, contents in sorted(entries, key=lambda item: item[0], reverse=True):
        validate_entry_path(path.encode("utf-8"))
        append_valdi_data(payload, path.encode("utf-8"))
        append_valdi_data(payload, contents)
    return VALDI_MAGIC + struct.pack("<I", len(payload)) + payload


def entry_record(path: str, contents: bytes, index: int) -> dict[str, object]:
    return {
        "index": index,
        "path": path,
        "size": len(contents),
        "sha256": sha256(contents),
        "precompiled_js": contents.startswith(PRECOMPILED_JS_MAGIC),
    }


def archive_summary(module_path: Path) -> tuple[bytes, list[tuple[str, bytes]], dict]:
    packed = module_path.read_bytes()
    raw = read_module(module_path)
    entries = parse_archive(raw)
    summary = {
        "module": str(module_path),
        "compressed": packed.startswith(ZSTD_MAGIC),
        "compressed_size": len(packed),
        "compressed_sha256": sha256(packed),
        "raw_size": len(raw),
        "raw_sha256": sha256(raw),
        "entry_count": len(entries),
        "precompiled_js_entries": sum(
            contents.startswith(PRECOMPILED_JS_MAGIC) for _, contents in entries
        ),
        "source_js_entries": sum(
            not contents.startswith(PRECOMPILED_JS_MAGIC)
            and path.endswith(".js")
            for path, contents in entries
        ),
        "entries": [
            entry_record(path, contents, index)
            for index, (path, contents) in enumerate(entries)
        ],
    }
    return raw, entries, summary


def command_unpack(args: argparse.Namespace) -> None:
    module_path = Path(args.module).resolve()
    output = Path(args.output).resolve()
    if output.exists() and any(output.iterdir()):
        raise ArchiveError(f"output directory is not empty: {output}")
    output.mkdir(parents=True, exist_ok=True)

    _, entries, summary = archive_summary(module_path)
    for path, contents in entries:
        target = output.joinpath(*PurePosixPath(path).parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(contents)
    (output / MANIFEST_NAME).write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "output": str(output),
                "entry_count": len(entries),
                "raw_sha256": summary["raw_sha256"],
            },
            sort_keys=True,
        )
    )


def entries_from_directory(root: Path) -> list[tuple[str, bytes]]:
    entries: list[tuple[str, bytes]] = []
    for path in root.rglob("*"):
        if not path.is_file() or path.name == MANIFEST_NAME:
            continue
        relative = path.relative_to(root).as_posix()
        validate_entry_path(relative.encode("utf-8"))
        entries.append((relative, path.read_bytes()))
    if not entries:
        raise ArchiveError(f"no entries found under {root}")
    return entries


def compress_raw(raw: bytes, output: Path, level: int) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="valdimodule-") as temp_dir:
        raw_path = Path(temp_dir) / "module.raw"
        raw_path.write_bytes(raw)
        subprocess.run(
            [
                "zstd",
                "-q",
                "-f",
                f"-{level}",
                "-T1",
                "--no-check",
                str(raw_path),
                "-o",
                str(output),
            ],
            check=True,
        )
    if read_module(output) != raw:
        raise ArchiveError("zstd verification failed after compression")


def command_pack(args: argparse.Namespace) -> None:
    root = Path(args.entries).resolve()
    output = Path(args.output).resolve()
    entries = entries_from_directory(root)
    raw = build_archive(entries)
    parsed = parse_archive(raw)
    if parsed != sorted(entries, key=lambda item: item[0], reverse=True):
        raise ArchiveError("internal pack/parse round-trip mismatch")

    if args.raw:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(raw)
    else:
        compress_raw(raw, output, args.level)

    _, _, summary = archive_summary(output)
    print(json.dumps(summary, indent=2, sort_keys=True))


def command_inspect(args: argparse.Namespace) -> None:
    _, _, summary = archive_summary(Path(args.module).resolve())
    if not args.entries:
        summary = {key: value for key, value in summary.items() if key != "entries"}
    print(json.dumps(summary, indent=2, sort_keys=True))


def command_roundtrip(args: argparse.Namespace) -> None:
    module_path = Path(args.module).resolve()
    raw, entries, summary = archive_summary(module_path)
    rebuilt = build_archive(entries)
    result = {
        "module": str(module_path),
        "entry_count": len(entries),
        "original_raw_sha256": summary["raw_sha256"],
        "rebuilt_raw_sha256": sha256(rebuilt),
        "byte_exact": rebuilt == raw,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    if rebuilt != raw:
        raise ArchiveError("canonical rebuild is not byte-exact")


def command_compare(args: argparse.Namespace) -> None:
    _, before_entries, before_summary = archive_summary(Path(args.before).resolve())
    _, after_entries, after_summary = archive_summary(Path(args.after).resolve())
    before = dict(before_entries)
    after = dict(after_entries)
    expected = set(args.expected_changed)

    if list(before) != list(after):
        raise ArchiveError("entry path/order changed")
    actual = {path for path in before if before[path] != after[path]}
    if actual != expected:
        raise ArchiveError(
            f"changed entries mismatch: expected={sorted(expected)}, "
            f"actual={sorted(actual)}"
        )
    result = {
        "before_raw_sha256": before_summary["raw_sha256"],
        "after_raw_sha256": after_summary["raw_sha256"],
        "entry_count": len(before_entries),
        "changed_entries": sorted(actual),
        "unchanged_entries_verified": len(before_entries) - len(actual),
    }
    print(json.dumps(result, indent=2, sort_keys=True))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    unpack = subparsers.add_parser("unpack")
    unpack.add_argument("module")
    unpack.add_argument("output")
    unpack.set_defaults(function=command_unpack)

    pack = subparsers.add_parser("pack")
    pack.add_argument("entries")
    pack.add_argument("output")
    pack.add_argument("--raw", action="store_true")
    pack.add_argument("--level", type=int, default=19)
    pack.set_defaults(function=command_pack)

    inspect = subparsers.add_parser("inspect")
    inspect.add_argument("module")
    inspect.add_argument("--entries", action="store_true")
    inspect.set_defaults(function=command_inspect)

    roundtrip = subparsers.add_parser("roundtrip")
    roundtrip.add_argument("module")
    roundtrip.set_defaults(function=command_roundtrip)

    compare = subparsers.add_parser("compare")
    compare.add_argument("before")
    compare.add_argument("after")
    compare.add_argument(
        "--expected-changed",
        action="append",
        required=True,
        help="archive path expected to differ; repeat for each path",
    )
    compare.set_defaults(function=command_compare)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        args.function(args)
    except (ArchiveError, OSError, subprocess.CalledProcessError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
