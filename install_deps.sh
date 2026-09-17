#!/usr/bin/env bash
# Install the demo's dependencies into whatever Python is active: the PyPI
# packages in requirements.txt, then bfrescox built from a clone of
# https://github.com/bandframework/Bfrescox placed at ./Bfrescox.
#
# Used by setup_venv.sh (laptop, inside .venv) and by the notebook's first
# cell on Google Colab (system Python).  Everything is relative to this
# directory.  Building bfrescox compiles the Frescox Fortran code, so it needs
# gfortran and git on PATH plus network access, and takes a few minutes the
# first time; afterwards it is skipped unless FORCE=1.
#
#     BFRESCOX_CLONE=0   do not clone automatically, just say how
#     FORCE=1            rebuild bfrescox even if it already imports
set -euo pipefail
cd "$(dirname "$0")"

PYTHON=${PYTHON:-python}
BFRESCOX_DIR=Bfrescox
BFRESCOX_URL=https://github.com/bandframework/Bfrescox.git

$PYTHON -m pip install --quiet -r requirements.txt

if [[ "${FORCE:-0}" != "1" ]] && $PYTHON -c "import bfrescox, sys; sys.exit(0 if bfrescox.information() else 1)" 2>/dev/null; then
    echo "bfrescox already installed with its frescox binary; nothing to do (FORCE=1 to rebuild)"
    exit 0
fi

if [[ ! -d "$BFRESCOX_DIR/bfrescox_pypkg" ]]; then
    if [[ "${BFRESCOX_CLONE:-1}" == "0" ]]; then
        echo "bfrescox source not found.  Clone it into this directory with:"
        echo "    git clone $BFRESCOX_URL $BFRESCOX_DIR"
        echo "then re-run $0"
        exit 1
    fi
    echo "cloning bfrescox:  git clone $BFRESCOX_URL $BFRESCOX_DIR"
    git clone "$BFRESCOX_URL" "$BFRESCOX_DIR"
fi

missing=()
for tool in gfortran git; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if (( ${#missing[@]} )); then
    echo "bfrescox needs these tools on PATH to build Frescox: ${missing[*]}"
    echo "(e.g. 'apt-get install gfortran git', 'conda install -c conda-forge gfortran git', or brew)"
    exit 1
fi

# A regular (non-editable) install copies the package, including the frescox
# binary it just built, into site-packages.  That is what lets an already
# running kernel (Colab) import it without a restart.
echo "installing bfrescox from $BFRESCOX_DIR/bfrescox_pypkg (compiles Frescox; a few minutes)"
$PYTHON -m pip install --quiet "$BFRESCOX_DIR/bfrescox_pypkg"
$PYTHON - <<'PY'
import importlib
importlib.invalidate_caches()
import bfrescox
info = bfrescox.information()
assert info, "bfrescox installed without its frescox binary -- check the build log"
print(f"bfrescox {bfrescox.__version__}, frescox at {info['frescox_exe']}")
PY
