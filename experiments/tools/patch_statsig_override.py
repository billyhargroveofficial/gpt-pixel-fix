#!/usr/bin/env python3
"""Add or replace Statsig.LOCAL_OVERRIDES in an AndroidX Preferences DataStore."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


LOCAL_OVERRIDES_KEY = b"Statsig.LOCAL_OVERRIDES"


def read_varint(data: bytes, offset: int) -> tuple[int, int]:
    value = 0
    shift = 0
    while offset < len(data):
        byte = data[offset]
        offset += 1
        value |= (byte & 0x7F) << shift
        if byte < 0x80:
            return value, offset
        shift += 7
        if shift >= 64:
            raise ValueError("invalid protobuf varint")
    raise ValueError("truncated protobuf varint")


def encode_varint(value: int) -> bytes:
    if value < 0:
        raise ValueError("negative varint")
    encoded = bytearray()
    while value >= 0x80:
        encoded.append((value & 0x7F) | 0x80)
        value >>= 7
    encoded.append(value)
    return bytes(encoded)


def length_delimited(field_number: int, payload: bytes) -> bytes:
    return encode_varint((field_number << 3) | 2) + encode_varint(len(payload)) + payload


def skip_field(data: bytes, offset: int, wire_type: int) -> int:
    if wire_type == 0:
        _, offset = read_varint(data, offset)
        return offset
    if wire_type == 1:
        return offset + 8
    if wire_type == 2:
        size, offset = read_varint(data, offset)
        return offset + size
    if wire_type == 5:
        return offset + 4
    raise ValueError(f"unsupported protobuf wire type {wire_type}")


def entry_key(entry: bytes) -> bytes | None:
    offset = 0
    while offset < len(entry):
        tag, payload_offset = read_varint(entry, offset)
        field_number = tag >> 3
        wire_type = tag & 7
        end = skip_field(entry, payload_offset, wire_type)
        if end > len(entry):
            raise ValueError("truncated map entry")
        if field_number == 1 and wire_type == 2:
            size, start = read_varint(entry, payload_offset)
            return entry[start : start + size]
        offset = end
    return None


def patch_preferences(data: bytes, override_json: str) -> bytes:
    preserved: list[bytes] = []
    offset = 0
    removed = 0

    while offset < len(data):
        field_start = offset
        tag, payload_offset = read_varint(data, offset)
        field_number = tag >> 3
        wire_type = tag & 7
        field_end = skip_field(data, payload_offset, wire_type)
        if field_end > len(data):
            raise ValueError("truncated Preferences protobuf")

        is_target = False
        if field_number == 1 and wire_type == 2:
            size, entry_start = read_varint(data, payload_offset)
            entry = data[entry_start : entry_start + size]
            is_target = entry_key(entry) == LOCAL_OVERRIDES_KEY

        if is_target:
            removed += 1
        else:
            preserved.append(data[field_start:field_end])
        offset = field_end

    value_message = length_delimited(5, override_json.encode("utf-8"))
    map_entry = (
        length_delimited(1, LOCAL_OVERRIDES_KEY)
        + length_delimited(2, value_message)
    )
    preserved.append(length_delimited(1, map_entry))
    result = b"".join(preserved)
    print(f"replaced={removed} output_bytes={len(result)}")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--gate", default="3320767387")
    parser.add_argument(
        "--value",
        choices=("true", "false"),
        default="true",
    )
    parser.add_argument(
        "--set",
        action="append",
        default=[],
        metavar="GATE=BOOL",
        help="repeatable gate override; when present, replaces --gate/--value",
    )
    args = parser.parse_args()

    gates: dict[str, bool] = {}
    if args.set:
        for assignment in args.set:
            gate, separator, raw_value = assignment.partition("=")
            if not separator or raw_value not in {"true", "false"}:
                parser.error(f"invalid --set value: {assignment!r}")
            gates[gate] = raw_value == "true"
    else:
        gates[args.gate] = args.value == "true"

    override = {
        "gates": gates,
        "configs": {},
        "layers": {},
    }
    override_json = json.dumps(override, separators=(",", ":"))
    args.output.write_bytes(
        patch_preferences(args.input.read_bytes(), override_json)
    )
    print(f"override={override_json}")


if __name__ == "__main__":
    main()
