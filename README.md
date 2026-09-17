# Emulating and calibrating a nuclear breakup reaction using surmise and bfrescox

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/beykyle/breakup-calibration-demo/blob/main/breakup_calibration_demo.ipynb)
    

This is a use case of the BAND software framework, using
[surmise](https://github.com/bandframework/surmise) for emulation and calibration and
[Bfrescox](https://github.com/bandframework/Bfrescox) to drive the Frescox reaction code to 
reproduce [Sürer, Nunes, Plumlee & Wild, *Phys. Rev. C* **106**, 024607 (2022)](https://journals.aps.org/prc/abstract/10.1103/PhysRevC.106.024607).

## Quick start

```bash
git clone https://github.com/bandframework/Bfrescox.git   # into this directory; setup_venv.sh
./setup_venv.sh                                            # does it for you if it is missing
source .venv/bin/activate
jupyter lab breakup_calibration_demo.ipynb
```

## Regenerating the training data

`data/training.npz` is the pre-computed training data. To rebuild it you need a Fortran compiler, an MPI
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

## Citation

If you use this demo, please cite the original paper:
```
@article{PhysRevC.106.024607,
  title = {Uncertainty quantification in breakup reactions},
  author = {S\"urer, \"O. and Nunes, F. M. and Plumlee, M. and Wild, S. M.},
  journal = {Phys. Rev. C},
  volume = {106},
  issue = {2},
  pages = {024607},
  numpages = {12},
  year = {2022},
  month = {Aug},
  publisher = {American Physical Society},
  doi = {10.1103/PhysRevC.106.024607},
  url = {https://link.aps.org/doi/10.1103/PhysRevC.106.024607}
}

```


and the BAND framework:
```
@techreport{bandframework,
    title       = {{BANDFramework: An} Open-Source Framework for {Bayesian} Analysis of Nuclear Dynamics},
    author      = {Kyle Beyer and Landon Buskirk and Manuel Catacora Rios and Moses Y-H. Chan and Tyler H. Chang and Troy Dasher 
    and Richard James DeBoer and Christian Drischler and Richard J. Furnstahl and Pablo Giuliani and
    Kyle Godbey and Kevin Ingles and Sunil Jaiswal and An Le and Dananjaya Liyanage and Filomena M. Nunes
    and Daniel Odell and David O'Gara and Jared O'Neal and Daniel R. Phillips and Matthew Plumlee
    and Matthew T. Pratola and Scott Pratt and Oleh Savchuk and Alexandra C. Semposki and \"Ozge S\"urer and 
    Stefan M. Wild and John C. Yannotty},
    institution = {},
    number      = {Version 0.5.0},
    year        = {2025},
    url         = {https://github.com/bandframework/bandframework}
}

```
