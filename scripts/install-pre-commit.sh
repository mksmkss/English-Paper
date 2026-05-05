#!/bin/sh
set -eu

repo_root="${1:-$(pwd)}"
hook_dir="$repo_root/.git/hooks"
hook_path="$hook_dir/pre-commit"

mkdir -p "$hook_dir"

cat > "$hook_path" <<'HOOK'
#!/bin/sh
set -eu

if [ ! -f .paperapp/app.db ]; then
  exit 0
fi

mkdir -p .paperapp
sqlite3 .paperapp/app.db .dump > .paperapp/backup.sql
git add .paperapp/backup.sql
HOOK

chmod +x "$hook_path"
echo "Installed pre-commit hook at $hook_path"
