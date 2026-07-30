#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    printf 'Usage: %s SOURCE_DB OUTPUT_DB CONVERSATION_ID\n' "$0" >&2
    exit 2
fi

readonly source_db=$1
readonly output_db=$2
readonly conversation_id=$3

if [[ ! -f "$source_db" ]]; then
    printf 'Source database not found: %s\n' "$source_db" >&2
    exit 1
fi
if [[ -e "$output_db" ]]; then
    printf 'Refusing to overwrite: %s\n' "$output_db" >&2
    exit 1
fi
if [[ ! "$conversation_id" =~ ^[0-9a-f-]+$ ]]; then
    printf 'Invalid conversation id: %s\n' "$conversation_id" >&2
    exit 1
fi

cp --reflink=auto -- "$source_db" "$output_db"
sqlite3 "$output_db" <<SQL
BEGIN IMMEDIATE;
DELETE FROM DBMessageChunk
WHERE messageId IN (
    SELECT id FROM DBMessage WHERE conversationId <> '$conversation_id'
);
DELETE FROM DBMessage WHERE conversationId <> '$conversation_id';
DELETE FROM DBConversation WHERE id <> '$conversation_id';
COMMIT;
VACUUM;
SQL

readonly kept_count=$(
    sqlite3 "$output_db" \
        "SELECT count(*) FROM DBConversation WHERE id = '$conversation_id';"
)
readonly integrity=$(sqlite3 "$output_db" 'PRAGMA integrity_check;')
if [[ "$kept_count" != 1 || "$integrity" != ok ]]; then
    printf 'Minimal database verification failed: kept=%s integrity=%s\n' \
        "$kept_count" "$integrity" >&2
    exit 1
fi

printf 'Created %s with only conversation %s\n' "$output_db" "$conversation_id"
