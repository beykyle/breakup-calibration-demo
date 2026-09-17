#!/usr/bin/env python
"""Generate ``anc.template``: the frescox input for the 7Be + p bound state alone.

    python model/generate_anc_template.py                     # from run_design_point.FIXED
    python model/generate_anc_template.py --fixed my.json     # from another fixed parameter set

The ANC of the 8B ground state depends only on the 7Be-p potential, so the
template keeps ``@placeholders@`` for that potential's seven entries
(``rC_p_7Be, V_p_7Be, rV_p_7Be, aV_p_7Be, Vso_p_7Be, rso_p_7Be, aso_p_7Be``)
and writes the fixed target potentials in as numbers.  The ``&Pot`` block is
taken from ``cdcc_angular.template`` so the potentials cannot drift from the
CDCC campaign; everything else (one partition state, one bound overlap with
``isc=1`` to refit the depth to 137 keV and ``ipc=1`` to print the full
radial ANC table, no couplings) is the minimal bound-state input.

A ``--fixed`` JSON file uses the same layout as ``run_design_point.FIXED``:
``{"8B_208Pb": {"rC": ...}, "7Be_208Pb": {...}, "p_208Pb": {...}}``.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_design_point import FIXED  # noqa: E402

CDCC_TEMPLATE = HERE / "cdcc_angular.template"
OUT = HERE / "anc.template"

#: The interaction whose parameters stay as placeholders.
VARIED = "p_7Be"

HEAD = """8B = 7Be + p bound state only; ANC of the 0p3/2 ground state (no continuum, no couplings)
NAMELIST
 &Fresco  hcm= 0.01 rmatch= -60.000 rintp= 0.15 rsp=   0.0
     rasym= 1000.00 accrcy= 0.0010000
     jtmin=   0.0 jtmax= 1.0 absend= -50.0000
      jump =      1
      jbord=       0.0       1.0
     thmin= 0.00 thmax= 1.00 thinc= 1.00  cutr=-20.00
     tmp='./'
     ips= 0.0000  it0= 0 iter=  0 iblock= 1 nnu= 24
     smallchan= 1.00E-12  smallcoup= 1.00E-12
     chans= 1 smats= 2 xstabl= 1
     elab= 640.0000    pel=1 exl=1 lab=1 lin=1 lex=1 /

 &Partition namep='8B      ' massp=  8.0000 zp=  5 nex=  1 pwf=T
            namet='208Pb   ' masst=208.0000 zt= 82 qval= 0.1370/
 &States jp= 1.5 ptyp=-1 ep=  0.0000  cpot=  1
         jt= 0.0 ptyt= 1 et=  0.0000/
 &Partition namep='7Be     ' massp=  7.0000 zp=  4 nex= -1 pwf=T
            namet='208Pb +p' masst=209.0000 zt= 83 qval=  0.0000/
 &States jp= 0.0 ptyp= 1 ep=  0.0000  cpot=  2
         jt= 0.0 ptyt= 1 et=  0.0000/
 &Partition /   ! END OF DEFINING PARTITIONS

"""

TAIL = """
 &Overlap kn1=  1 kn2=  0 ic1=1 ic2=2 in= 1
          kind=0 nn= 1 l=1 lmax=0 sn=0.5 j= 1.5 nam=1 ampl=  1.0000
    kbpot= 4 be=  0.1370 isc= 1 ipc=1 /
 &Overlap /   ! END OF DEFINING OVERLAPS

 &Coupling /
"""


def potential_block(cdcc_template: Path = CDCC_TEMPLATE) -> str:
    """The ``&Pot ... &Pot /`` block of the CDCC template, placeholders included."""
    lines = cdcc_template.read_text().splitlines(keepends=True)
    start = next(i for i, l in enumerate(lines) if l.startswith(" &Pot kp= 1"))
    stop = next(i for i, l in enumerate(lines) if l.startswith(" &Pot /"))
    return "".join(lines[start : stop + 1])


def fixed_params(fixed: dict = FIXED) -> dict[str, float]:
    """Flatten ``{interaction: {name: value}}`` to ``{name_interaction: value}``."""
    return {
        f"{name}_{interaction}": float(value)
        for interaction, params in fixed.items()
        for name, value in params.items()
    }


def render(fixed: dict = FIXED) -> str:
    """The template text: fixed potentials as numbers, ``p_7Be`` as placeholders."""
    block = potential_block()
    for key, value in fixed_params(fixed).items():
        if f"@{key}@" not in block:
            raise ValueError(f"no @{key}@ placeholder in {CDCC_TEMPLATE.name}")
        block = block.replace(f"@{key}@", f"{value:.4f}")
    left = set(re.findall(r"@(\w+)@", block))
    stray = sorted(k for k in left if not k.endswith(f"_{VARIED}"))
    if stray:
        raise ValueError(f"fixed parameter set does not cover {stray}")
    return HEAD + block + TAIL


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument(
        "--fixed",
        type=Path,
        default=None,
        help="JSON file with the fixed potentials (default: run_design_point.FIXED)",
    )
    ap.add_argument("--out", type=Path, default=OUT)
    args = ap.parse_args()

    fixed = FIXED if args.fixed is None else json.loads(args.fixed.read_text())
    text = render(fixed)
    args.out.write_text(text)
    placeholders = sorted(set(re.findall(r"@(\w+)@", text)))
    print(f"wrote {args.out} with placeholders: {', '.join(placeholders)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
