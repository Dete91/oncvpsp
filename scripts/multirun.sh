#!/bin/bash
#runs ONCVPSP for each command-line argument <prefix>.dat
#launches up to NPROC jobs at a time
#uses the scalar-relativistic all-electron atom calculation
#does not display plots
#

NPROC=4

# repo root (this script lives in scripts/); executables are in build/bin
PREFIX=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

nn=0


for ii do

	nn=$(( $nn + 1))

	OUTFILE=`echo $ii | sed -e s/.dat// `.out

	$PREFIX/build/bin/oncvpsp.x <$ii >$OUTFILE &


       if [ $(($nn%$NPROC)) == 0 ]
                then
                wait
        fi

done
wait

echo '*** ALL DONE ***'

