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
    # Windows venvs put the activate script in Scripts/ instead of bin/.
    VENV_BIN="$VENV/bin"
    [[ -d "$VENV_BIN" ]] || VENV_BIN="$VENV/Scripts"
    # shellcheck disable=SC1091
    source "$VENV_BIN/activate"
    PYTHON=python
    $PYTHON -m pip install --quiet --upgrade pip
fi

# surmise requires >= 3.11; 3.12 is what this was tested on.
$PYTHON - <<'PY'
import sys
if sys.version_info < (3, 11):
    sys.exit(f"need Python >= 3.11, found {sys.version.split()[0]}")
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

    # Bfrescox uses git symlinks, which a Windows checkout without symlink
    # privileges (core.symlinks=false) writes out as small text files holding
    # the target path.  Replace those with copies of what they point to.
    git -C "$BFRESCOX_DIR" ls-files -s -- bfrescox_pypkg |
        awk '$1 == "120000" { print $2, $4 }' |
        $PYTHON -c '
import hashlib, os, shutil, sys
root = sys.argv[1]
links = {}
for line in sys.stdin:
    blob, path = line.split(maxsplit=1)
    links[os.path.normpath(os.path.join(root, path.strip()))] = blob
def is_placeholder(p):
    # Still the text file git wrote, i.e. not materialized on an earlier run.
    if p not in links or os.path.islink(p) or not os.path.isfile(p):
        return False
    with open(p, "rb") as f:
        data = f.read()
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest() == links[p]
def resolve(p):
    while is_placeholder(p):
        with open(p) as f:
            p = os.path.normpath(os.path.join(os.path.dirname(p), f.read().strip()))
    return p
for link in sorted(links):
    if not is_placeholder(link):
        continue
    target = resolve(link)
    os.remove(link)
    if os.path.isdir(target):
        shutil.copytree(target, link)
    else:
        shutil.copy2(target, link)
    print("materialized symlink", os.path.relpath(link, root))
' "$BFRESCOX_DIR"

    # A regular (non-editable) install copies the package, including the frescox
    # binary it just built, into site-packages.  That is what lets an already
    # running kernel (Colab) import it without a restart.
    echo "installing bfrescox from $BFRESCOX_DIR/bfrescox_pypkg (compiles Frescox; a few minutes)"
    $PYTHON -m pip install --quiet "$BFRESCOX_DIR/bfrescox_pypkg"

    # On Windows the build produces bin/frescox.exe, but bfrescox only packages
    # and looks for bin/frescox.  Install the binary under both names: the bare
    # one passes bfrescox's existence check and CreateProcess appends .exe when
    # running it.  Also put the gfortran runtime DLLs beside it, since Windows
    # searches the executable's directory first and the compiler's bin/ will
    # not necessarily be on PATH when Jupyter runs it.
    built_exe="$BFRESCOX_DIR/bfrescox_pypkg/src/bfrescox/bin/frescox.exe"
    if [[ -f "$built_exe" ]]; then
        $PYTHON - "$built_exe" "$(dirname "$(command -v gfortran)")" <<'PY'
import importlib.util, os, shutil, sys
exe, compiler_bin = sys.argv[1:]
bin_dir = os.path.join(os.path.dirname(importlib.util.find_spec("bfrescox").origin), "bin")
os.makedirs(bin_dir, exist_ok=True)
for name in ("frescox", "frescox.exe"):
    shutil.copy2(exe, os.path.join(bin_dir, name))
for dll in ("libgfortran-5.dll", "libgcc_s_seh-1.dll", "libquadmath-0.dll", "libwinpthread-1.dll"):
    src = os.path.join(compiler_bin, dll)
    if os.path.isfile(src):
        shutil.copy2(src, bin_dir)
PY
    fi

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
    echo "    source $VENV_BIN/activate"
    echo "    jupyter lab breakup_calibration_demo.ipynb"
fi
