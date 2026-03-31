#!/bin/bash
# Generates Navidrome playlists for each top-level music folder by inserting directly into the DB.

set -euo pipefail

if [ -f .env ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    export "$(eval echo "$line")"
  done < .env
fi

MUSIC_DIR="${ND_MUSICFOLDER:?ND_MUSICFOLDER is not set}"

db() { docker compose exec -T navidrome sqlite3 /data/navidrome.db "$@"; }

OWNER_ID=$(db "SELECT id FROM user LIMIT 1;")
if [ -z "$OWNER_ID" ]; then
  echo "Error: no user found in database" >&2
  exit 1
fi

gen_id() { openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 22; }

NOW=$(date -u '+%Y-%m-%d %H:%M:%S')
count=0

for dir in "$MUSIC_DIR"/*/; do
  [ -d "$dir" ] || continue
  folder=$(basename "$dir")
  [[ "$folder" == .* ]] && continue

  # Escape single quotes for SQLite
  sq="${folder//\'/\'\'}"

  existing=$(db "SELECT id FROM playlist WHERE name = '$sq';")
  if [ -n "$existing" ]; then
    echo "  skipping (exists): $folder"
    continue
  fi

  pid=$(gen_id)

  db << EOF
BEGIN;

INSERT INTO playlist (id, name, comment, duration, song_count, public, created_at, updated_at, path, sync, size, owner_id)
SELECT '$pid', '$sq', 'Auto-generated from folder', COALESCE(SUM(duration),0), COUNT(*), 1, '$NOW', '$NOW', '', 0, COALESCE(SUM(size),0), '$OWNER_ID'
FROM media_file WHERE path LIKE '$sq/%';

INSERT INTO playlist_tracks (id, playlist_id, media_file_id)
SELECT ROW_NUMBER() OVER (ORDER BY path) - 1, '$pid', id
FROM media_file WHERE path LIKE '$sq/%' ORDER BY path;

COMMIT;
EOF

  track_count=$(db "SELECT song_count FROM playlist WHERE id = '$pid';")
  echo "  created: $folder ($track_count tracks)"
  (( count++ )) || true
done

echo "Done — $count playlist(s) created."
