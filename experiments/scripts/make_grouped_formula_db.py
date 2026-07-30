#!/usr/bin/env python3
"""Create an offline ChatGPT conversation DB with fewer LaTeX render nodes.

The source database is never modified. The script finds the synthetic
"Math Display Equations" response containing 120 separate display formulas
and rewrites only the copied database so the same 120 equations are grouped
into configurable ``aligned`` blocks.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sqlite3
from pathlib import Path


CHUNK_SIZE = 32_768
SOURCE_TITLE = "Math Display Equations"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--block-size", type=int, default=10)
    return parser.parse_args()


def grouped_content(block_size: int) -> str:
    if not 1 <= block_size <= 120:
        raise ValueError("--block-size must be between 1 and 120")

    blocks: list[str] = []
    for start in range(1, 121, block_size):
        stop = min(start + block_size, 121)
        rows = [
            rf"x_{{{index}}}^2+y_{{{index}}}^2&=z_{{{index}}}^2"
            for index in range(start, stop)
        ]
        blocks.append(
            f"Block {len(blocks) + 1}\n\n"
            "$$\n"
            "\\begin{aligned}\n"
            + " \\\\\n".join(rows)
            + "\n\\end{aligned}\n"
            "$$"
        )
    return "\n\n".join(blocks)


def main() -> None:
    args = parse_args()
    source = args.source.resolve()
    output = args.output.resolve()

    if not source.is_file():
        raise SystemExit(f"source database not found: {source}")
    if output.exists():
        raise SystemExit(f"refusing to overwrite existing output: {output}")

    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, output)

    connection = sqlite3.connect(output)
    try:
        conversation_row = connection.execute(
            """
            SELECT id, conversation
            FROM DBConversation
            WHERE json_extract(conversation, '$.title') = ?
            """,
            (SOURCE_TITLE,),
        ).fetchone()
        if conversation_row is None:
            raise RuntimeError(f"conversation title not found: {SOURCE_TITLE}")

        conversation_id, conversation_json = conversation_row
        messages = connection.execute(
            """
            SELECT m.id, group_concat(CAST(c.chunk AS TEXT), '')
            FROM DBMessage AS m
            JOIN DBMessageChunk AS c ON c.messageId = m.id
            WHERE m.conversationId = ?
            GROUP BY m.id
            ORDER BY length(group_concat(CAST(c.chunk AS TEXT), '')) DESC
            """,
            (conversation_id,),
        ).fetchall()

        target_id: str | None = None
        target_message: dict[str, object] | None = None
        for message_id, serialized in messages:
            message = json.loads(serialized)
            content = message.get("content", {}).get("content", "")
            if (
                message.get("role") == "Assistant"
                and isinstance(content, str)
                and content.count("$$x^2+y^2=z^2$$") == 120
            ):
                target_id = message_id
                target_message = message
                break

        if target_id is None or target_message is None:
            raise RuntimeError("120-formula synthetic assistant message not found")

        new_content = grouped_content(args.block_size)
        target_message["content"]["content"] = new_content
        serialized = json.dumps(
            target_message,
            ensure_ascii=True,
            separators=(",", ":"),
        ).encode("utf-8")

        conversation = json.loads(conversation_json)
        conversation["title"] = f"Math Grouped {args.block_size} Per Block"

        with connection:
            connection.execute(
                "DELETE FROM DBMessageChunk WHERE messageId = ?",
                (target_id,),
            )
            for chunk_index, offset in enumerate(range(0, len(serialized), CHUNK_SIZE)):
                connection.execute(
                    """
                    INSERT INTO DBMessageChunk(messageId, chunkIndex, chunk)
                    VALUES (?, ?, ?)
                    """,
                    (
                        target_id,
                        chunk_index,
                        serialized[offset : offset + CHUNK_SIZE],
                    ),
                )
            connection.execute(
                "UPDATE DBConversation SET conversation = ? WHERE id = ?",
                (
                    json.dumps(conversation, ensure_ascii=True, separators=(",", ":")),
                    conversation_id,
                ),
            )

        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise RuntimeError(f"SQLite integrity check failed: {integrity}")

        math_nodes = new_content.count("$$") // 2
        print(
            f"created {output}: 120 equations in {math_nodes} display-math nodes "
            f"({args.block_size} equations per node)"
        )
    finally:
        connection.close()


if __name__ == "__main__":
    main()
