# Emulating and calibrating a nuclear breakup reaction

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/USER/breakup_calibration/blob/main/breakup_demo/breakup_calibration_demo.ipynb)

A self-contained demonstration of Bayesian calibration of an expensive physics simulator,
end to end: **design → simulator outputs → Gaussian-process emulator → validation → MCMC →
posterior predictions → coverage**.

Reproduces Sürer, Nunes, Plumlee & Wild, *Phys. Rev. C* **106**, 024607 (2022), using
[surmise](https://github.com/bandframework/surmise) for the emulation and calibration and
[Bfrescox](https://github.com/bandframework/Bfrescox) to drive the Frescox reaction code:
`bfrescoxpro` (MPI build) for the expensive CDCC campaign that produced `data/`, and plain
`bfrescox` (serial build, installed by `setup_venv.sh`) for the cheap two-body bound-state
calculations the notebook runs live to get the ANC of the $^8$B ground state (paper Fig. 8).

## Quick start

```bash
git clone https://github.com/bandframework/Bfrescox.git   # into this directory; setup_venv.sh
./setup_venv.sh                                            # does it for you if it is missing
source .venv/bin/activate
jupyter lab breakup_calibration_demo.ipynb
```

Needs Python ≥ 3.10, plus `gfortran` and `git` on `PATH` and network access: installing
`bfrescox` compiles Frescox with meson (a few minutes, once). Everything is relative to this
directory; `Bfrescox/` is a clone, not part of the demo, and is git-ignored.
`setup_venv.sh` only creates the venv; the installs live in `install_deps.sh`, which works
in any active Python (`pip install -r requirements.txt`, clone + build bfrescox, skipped
when bfrescox already imports).

### Google Colab

Click the badge above (after replacing `USER` in its link with the GitHub account hosting
this repository), then run the notebook's first code cell. On Colab that cell clones the
repository, `apt-get install`s gfortran and runs `install_deps.sh`; the Frescox compile takes a
few minutes on Colab's two cores, and the ANC section takes ~2 minutes instead of ~40 s.
The same cell is a no-op when the notebook runs locally. Colab pins numpy 2.0.x, which is why
`requirements.txt` allows `numpy>=2.0` rather than the 2.1 the numbers were produced with.

The notebook runs in about five to seven minutes on a laptop. The emulator, calibration and
posterior-predictive sections read the pre-computed CDCC outputs in `data/` and never touch
the expensive physics code; the ANC section (Section 8) runs ~1500 bound-state frescox
calculations at a fraction of a second each, in a process pool.

## What is here

```
breakup_calibration_demo.ipynb   the demo
requirements.txt                 what the notebook needs
setup_venv.sh                    creates .venv, then runs install_deps.sh inside it
install_deps.sh                  pip requirements + clone/build bfrescox (laptop venv or Colab)
data/
  training.npz                   500 design points x 45 observables
  mock_data.npz                  simulator at the truth parameters + 10% noise
  design.csv                     the 500-point Latin hypercube design
model/
  cdcc_angular.template          frescox input, angular model space (134 states)  -- the
  cdcc_energy.template           frescox input, energy model space (141 states)   -- expensive
  run_design_point.py            run one design point, or assemble the .npz        -- half, NOT run
  anc.template                   frescox input for the 7Be+p bound state alone (no continuum);
                                 7 placeholders for the 7Be+p potential, run by the notebook's Section 8
  generate_anc_template.py       regenerates anc.template from the CDCC template's potentials
requirements-model.txt           extra dependencies for model/run_design_point.py
Bfrescox/                        clone of github.com/bandframework/Bfrescox (made by setup_venv.sh)
```


## Regenerating the training data

`data/training.npz` ships pre-computed. To rebuild it you need a Fortran compiler, an MPI
implementation, and a large machine:

```bash
pip install -r requirements.txt -r requirements-model.txt
BFRESCOX_USE_MPI=enabled BFRESCOX_USE_OPENMP=enabled BFRESCOX_USE_LAPACK=enabled \
  pip install -v "git+https://github.com/bandframework/Bfrescox.git#subdirectory=bfrescoxpro_pypkg"

python model/run_design_point.py --index 0 --ranks 32    # one point, ~2 h on 32 ranks
python model/run_design_point.py --assemble              # samples/ -> data/training.npz
```

In practice this is a SLURM array over `--index 0..499`. Each task is idempotent and uses
its own working directory, so a partial run can be resumed by re-submitting the gaps.

Two things that will bite if you build bfrescoxpro yourself:

- The build flag is `BFRESCOX_USE_OPENMP`. The Bfrescox docs say `BFRESCOX_USE_OMP`, which
  its `setup.py` does not read.
- frescox writes its scratch files to `<TMP>fort.<rank>.<unit>` with `TMP='/tmp/'` by
  default, so two jobs sharing a node collide. The shipped templates set `tmp='./'` so the
  files land in each run's own directory.
