#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: scripts/install-source.sh [--skip-install] [--bin-dir <dir>]

Installs this source checkout as the global `hapi` command by writing a small
wrapper into ~/.local/bin by default.

Options:
  --skip-install   Do not run `bun install`
  --bin-dir <dir>  Install the wrapper into a custom directory
  -h, --help       Show this help
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="${HAPI_INSTALL_BIN_DIR:-$HOME/.local/bin}"
SKIP_INSTALL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-install)
            SKIP_INSTALL=1
            shift
            ;;
        --bin-dir)
            if [[ $# -lt 2 || -z "$2" ]]; then
                echo "error: --bin-dir requires a directory" >&2
                exit 1
            fi
            BIN_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

BUN_BIN="${BUN_BIN:-$(command -v bun || true)}"
if [[ -z "$BUN_BIN" ]]; then
    echo "error: bun was not found on PATH. Install Bun first: https://bun.sh" >&2
    exit 1
fi

if [[ ! -f "$REPO_ROOT/package.json" || ! -f "$REPO_ROOT/cli/src/index.ts" ]]; then
    echo "error: expected to run from a HAPI source checkout" >&2
    exit 1
fi

if [[ "$SKIP_INSTALL" -eq 0 ]]; then
    echo "[hapi] Installing workspace dependencies..."
    (cd "$REPO_ROOT" && "$BUN_BIN" install)
fi

mkdir -p "$BIN_DIR"

WRAPPER="$BIN_DIR/hapi"
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export HAPI_INVOKED_CWD="\$PWD"
exec "$BUN_BIN" --cwd "$REPO_ROOT/cli" src/index.ts "\$@"
EOF
chmod +x "$WRAPPER"

echo "[hapi] Installed source wrapper: $WRAPPER"
echo "[hapi] Source checkout: $REPO_ROOT"
echo "[hapi] Bun: $BUN_BIN"

case ":$PATH:" in
    *":$BIN_DIR:"*)
        ;;
    *)
        echo "[hapi] Add this directory to PATH if needed: $BIN_DIR"
        ;;
esac

echo "[hapi] Verify with: hapi --version"
