#!/usr/bin/env bash
# Create a virtual environment for the demo notebook and install everything
# it needs into it (see install_deps.sh for the details, including the
# bfrescox build and its prerequisites: gfortran, git, network access).
#
#     ./setup_venv.sh && source .venv/bin/activate && jupyter lab
#
set -euo pipefail
cd "$(dirname "$0")"

PYTHON=${PYTHON:-python3}
VENV=${VENV:-.venv}

# surmise requires >= 3.10; 3.12 is what this was tested on.
$PYTHON - <<'PY'
import sys
if sys.version_info < (3, 10):
    sys.exit(f"need Python >= 3.10, found {sys.version.split()[0]}")
print(f"using Python {sys.version.split()[0]}")
PY

if [[ ! -d "$VENV" ]]; then
    echo "creating $VENV"
    $PYTHON -m venv "$VENV"
fi

# shellcheck disable=SC1091
source "$VENV/bin/activate"
python -m pip install --quiet --upgrade pip
PYTHON=python ./install_deps.sh

echo
echo "done.  next:"
echo "    source $VENV/bin/activate"
echo "    jupyter lab breakup_calibration_demo.ipynb"
