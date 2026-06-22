#!/bin/bash
#runs ONCVPSP with the command-line argument <prefix> and the graphics
#which review the results
#uses the scalar-relativistic all-electron atom calculation

# repo root (this script lives in scripts/) and the CMake executable dir;
# override with  BIN_DIR=/path  if your build is elsewhere
PREFIX=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BIN_DIR=${BIN_DIR:-$PREFIX/build/bin}

INFILE=$1.dat

OUTFILE=$1.out

GNUFILE=$$.scr

PLOTFILE=$1.plot

TEMP=$$.tmp

$BIN_DIR/oncvpsp.x <$INFILE >$OUTFILE  #Edit if your executable is
                                            #in another directory

grep GHOST $OUTFILE

awk 'BEGIN{out=0};/GNUSCRIPT/{out=0}; {if(out == 1) {print}};\
	/DATA FOR PLOTTING/{out=1}' $OUTFILE >$PLOTFILE

awk 'BEGIN{out=0};/END_GNU/{out=0}; {if(out == 1) {print}};\
	/GNUSCRIPT/{out=1}' $OUTFILE >$TEMP

sed -e s/t1/$PLOTFILE/ $TEMP | sed -e s/t2/$1/ >$GNUFILE

if [ "$2" != "-np" ]
then
	gnuplot $GNUFILE
fi

rm  $GNUFILE $TEMP $PLOTFILE
