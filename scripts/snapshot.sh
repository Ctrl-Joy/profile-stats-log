#!/usr/bin/env bash
# Records snapshots of the owner's public GitHub profile stats, one commit each.
# Usage: snapshot.sh <number-of-commits>
set -euo pipefail

count="${1:-3}"
owner="${OWNER:?OWNER is not set}"
csv="data/stats.csv"
mkdir -p data

[ -f "$csv" ] || echo "timestamp,followers,following,public_repos,total_stars" > "$csv"

fetch_stats() {
  local profile stars
  profile=$(gh api "users/$owner" --jq '[.followers, .following, .public_repos] | @csv')
  stars=$(gh api --paginate "users/$owner/repos?per_page=100" --jq '.[].stargazers_count' \
    | awk '{s += $1} END {print s + 0}')
  echo "$profile,$stars"
}

write_readme() {
  local last total
  last=$(tail -n 1 "$csv")
  total=$(($(wc -l < "$csv") - 1))
  IFS=, read -r ts followers following repos stars <<< "$last"
  cat > README.md <<MD
# Profile stats log

Automated snapshots of [@$owner](https://github.com/$owner)'s public GitHub stats.

| Followers | Following | Public repos | Total stars |
|---|---|---|---|
| $followers | $following | $repos | $stars |

Last updated: $ts UTC. Snapshots recorded: $total. Full history in [\`$csv\`]($csv).
MD
}

for i in $(seq 1 "$count"); do
  ts=$(date -u +"%Y-%m-%d %H:%M:%S")
  echo "$ts,$(fetch_stats)" >> "$csv"
  write_readme
  git add "$csv" README.md
  git commit -q -m "Snapshot $ts UTC"
  [ "$i" -lt "$count" ] && sleep 2
done

echo "Made $count commit(s)."
