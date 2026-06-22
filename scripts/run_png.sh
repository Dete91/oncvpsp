#!/bin/bash
# Runs ONCVPSP (scalar-relativistic, oncvpsp.x) with command-line argument
# <prefix>, then renders the analysis plots as PNG files -- like replot.sh,
# but emitting PNGs instead of an interactive wxt window.
#
# The output listing and every plot are collected in a single new folder
# named  <prefix>_<YYYYmmdd_HHMMSS>/  so each run is self-contained and
# time-stamped.  Layout:
#     <prefix>_<stamp>/<prefix>.dat   (copy of the input, for reproducibility)
#     <prefix>_<stamp>/<prefix>.out   (full output listing)
#     <prefix>_<stamp>/<prefix>_NN.png  (one PNG per analysis plot block)
#
# Usage:   run_png.sh <prefix>
#   <prefix>.dat must exist in the current directory.
#
# The scalar-relativistic executable is located automatically (build/bin of
# this repo).  Override with the ONCVPSP_BIN environment variable, e.g.
#     ONCVPSP_BIN=/path/to/oncvpsp.x  run_png.sh 14_Si

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "usage: $(basename "$0") <prefix>   (expects <prefix>.dat)" >&2
    exit 1
fi

PREFIX=$1
INFILE=$PREFIX.dat

if [ ! -f "$INFILE" ]; then
    echo "error: input file '$INFILE' not found in $(pwd)" >&2
    exit 1
fi

# --- locate the scalar-relativistic executable -----------------------------
# Default to build/bin/oncvpsp.x relative to this repo (script lives in scripts/).
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
EXE=${ONCVPSP_BIN:-$REPO_ROOT/build/bin/oncvpsp.x}

if [ ! -x "$EXE" ]; then
    echo "error: scalar-relativistic executable not found/executable: $EXE" >&2
    echo "       build it (cmake --build build) or set ONCVPSP_BIN." >&2
    exit 1
fi

# --- create the time-stamped output folder ---------------------------------
STAMP=$(date +%Y%m%d_%H%M%S)
OUTDIR=$(pwd)/${PREFIX}_${STAMP}
mkdir -p "$OUTDIR"

OUTFILE=$OUTDIR/$PREFIX.out
cp "$INFILE" "$OUTDIR/"

# --- run the scalar-relativistic calculation -------------------------------
echo "running scalar-relativistic oncvpsp.x on $INFILE ..."
"$EXE" <"$INFILE" >"$OUTFILE"

# surface ghost-state warnings, if any
if grep -q GHOST "$OUTFILE"; then
    echo "WARNING: ghost state(s) reported:"
    grep GHOST "$OUTFILE"
fi

# --- extract the pseudopotential file(s) into the same folder --------------
# Whichever format(s) the input requested are carved out of the listing
# (mirrors scripts/extract.sh): psp8/UPF are inline between their start tag
# and END_PSP; PSML is written by the run as ONCVPSP.psml in the CWD.
if grep -q PSPCODE8 "$OUTFILE"; then
    awk 'BEGIN{out=0};/END_PSP/{out=0}; {if(out==1){print}};\
        /PSPCODE8/{out=1}' "$OUTFILE" >"$OUTDIR/$PREFIX.psp8"
    echo "extracted $PREFIX.psp8"
fi
if grep -q PSP_UPF "$OUTFILE"; then
    awk 'BEGIN{out=0};/END_PSP/{out=0}; {if(out==1){print}};\
        /PSP_UPF/{out=1}' "$OUTFILE" >"$OUTDIR/$PREFIX.upf"
    echo "extracted $PREFIX.upf"
fi
if grep -q psmlout "$OUTFILE" && [ -f ONCVPSP.psml ]; then
    mv ONCVPSP.psml "$OUTDIR/$PREFIX.psml"
    echo "extracted $PREFIX.psml"
fi

# --- render the embedded gnuplot blocks as PNGs ----------------------------
PLOTFILE=$OUTDIR/$PREFIX.plot     # data rows ('!p', '!L', ... tagged lines)
GNUFILE=$OUTDIR/$PREFIX.scr       # rewritten gnuplot script
PNGBASE=$OUTDIR/$PREFIX           # PNGs become ${PNGBASE}_NN.png

# data block: between "DATA FOR PLOTTING" and "GNUSCRIPT"
awk 'BEGIN{out=0};/GNUSCRIPT/{out=0}; {if(out==1){print}};\
    /DATA FOR PLOTTING/{out=1}' "$OUTFILE" >"$PLOTFILE"

# gnuplot script: between "GNUSCRIPT" and "END_GNU"
awk 'BEGIN{out=0};/END_GNU/{out=0}; {if(out==1){print}};\
    /GNUSCRIPT/{out=1}' "$OUTFILE" >"$OUTFILE.gnu.tmp"

# Substitute the placeholders (t1 -> data file, t2 -> title prefix), then
# rewrite for PNG output:
#   * swap the wxt terminal for pngcairo
#   * inject "set output <prefix>_NN.png" before each plot's title
#   * turn each interactive "pause" into "unset output" (flush the PNG)
# Absolute paths are used so the embedded "< grep ... t1" data references
# resolve no matter what the working directory is.
sed -e "s|t1|$PLOTFILE|" -e "s|t2|$PREFIX|" "$OUTFILE.gnu.tmp" | \
awk -v base="$PNGBASE" '
    BEGIN { n = 0 }
    /set term wxt/ { sub(/wxt/, "pngcairo"); print; next }
    /set title/    { n++; printf "set output \"%s_%02d.png\"\n", base, n; print; next }
    /^pause/       { print "unset output"; next }
                   { print }
' >"$GNUFILE"

gnuplot "$GNUFILE"

# --- tidy up intermediate files --------------------------------------------
rm -f "$PLOTFILE" "$GNUFILE" "$OUTFILE.gnu.tmp"

NPNG=$(ls "$OUTDIR"/${PREFIX}_*.png 2>/dev/null | wc -l)
echo "done: $NPNG plot(s) + $PREFIX.out written to $OUTDIR"
