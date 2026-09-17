#!/usr/bin/env bash
# Install everything the demo notebook needs: the PyPI packages in
# requirements.txt, then bfrescox built from a clone of
# https://github.com/bandframework/Bfrescox placed at ./Bfrescox.
#
# By default a virtual environment is created in .venv and everything goes
# into it:
#
#     ./setup.sh && source .venv/bin/activate && jupyter lab breakup_calibration_demo.ipynb
#
# With --no-venv it installs into whatever Python is already active instead,
# which is what the notebook's first cell does on Google Colab.
#
# Building bfrescox compiles the Frescox Fortran code, so it needs gfortran and
# git on PATH plus network access, and takes a few minutes the first time;
# afterwards it is skipped unless FORCE=1.  Everything is relative to this
# directory.
#
#     --no-venv          install into the active Python instead of .venv
#     BFRESCOX_CLONE=0   do not clone bfrescox automatically, just say how
#     FORCE=1            rebuild bfrescox even if it already imports
#     PYTHON=...         interpreter to bootstrap with (default python3)
#     VENV=...           virtual environment directory (default .venv)
set -euo pipefail
cd "$(dirname "$0")"

usage() { awk 'NR > 1 { if (!/^#/) exit; print substr($0, 3) }' "$0"; }

USE_VENV=1
for arg in "$@"; do
    case "$arg" in
        --no-venv) USE_VENV=0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

PYTHON=${PYTHON:-python3}
VENV=${VENV:-.venv}
BFRESCOX_DIR=Bfrescox
BFRESCOX_URL=https://github.com/bandframework/Bfrescox.git

if (( USE_VENV )); then
    if [[ ! -d "$VENV" ]]; then
        echo "creating $VENV"
        $PYTHON -m venv "$VENV"
    fi
    # shellcheck disable=SC1091
    source "$VENV/bin/activate"
    PYTHON=python
    $PYTHON -m pip install --quiet --upgrade pip
fi

# surmise requires >= 3.10; 3.12 is what this was tested on.
$PYTHON - <<'PY'
import sys
if sys.version_info < (3, 10):
    sys.exit(f"need Python >= 3.10, found {sys.version.split()[0]}")
print(f"using Python {sys.version.split()[0]}")
PY

$PYTHON -m pip install --quiet -r requirements.txt

install_bfrescox() {
    if [[ "${FORCE:-0}" != "1" ]] &&
       $PYTHON -c "import bfrescox, sys; sys.exit(0 if bfrescox.information() else 1)" 2>/dev/null; then
        echo "bfrescox already installed with its frescox binary; nothing to do (FORCE=1 to rebuild)"
        return 0
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
}

install_bfrescox

if (( USE_VENV )); then
    echo
    echo "done.  next:"
    echo "    source $VENV/bin/activate"
    echo "    jupyter lab breakup_calibration_demo.ipynb"
fi
