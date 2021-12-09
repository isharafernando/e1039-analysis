#!/bin/bash
DIR_BASE=$(dirname $(readlink -f $BASH_SOURCE))

LIST_RUN="list_run.txt"
VERSION="default"
DIR_DST=/pnfs/e1039/scratch/$USER/CalibChamXT/dst

USE_GRID=no
N_DST_ANA=0 # N of DSTs per run to be analyzed
N_EVT_ANA=0 # N of events per DST to be analyzed
OPTIND=1
while getopts ":gd:e:" OPT ; do
    case $OPT in
        g ) USE_GRID=yes ;;
        d ) N_DST_ANA=$OPTARG ;;
        e ) N_EVT_ANA=$OPTARG ;;
    esac
done
shift $((OPTIND - 1))
echo "USE_GRID  = $USE_GRID"
echo "N_DST_ANA = $N_DST_ANA"
echo "N_EVT_ANA = $N_EVT_ANA"

##
## Functions
##
function ProcessOneRun {
    local -r      RUN=$1
    local -r     RUN6=$(printf '%06d' $RUN)
    local -r LIST_DST=( $(find $DIR_DST/run_$RUN6 -name 'run_*.root' | sort) )
    local -r N_DST_ALL="${#LIST_DST[*]}"
    local -r     N_DST=$(( N_DST_ANA > 0 && N_DST_ALL > N_DST_ANA  ?  N_DST_ANA :  N_DST_ALL ))
    echo "================================================================"
    echo "Run $RUN"
    echo "  N of DSTs = $N_DST_ALL (all), $N_DST (analyzed)"
    #test $N_DST_ANA -gt 0 -a $N_DST -gt $N_DST_ANA && N_DST=$N_DST_ANA

    for (( I_DST = 0 ; I_DST < N_DST ; I_DST++ )) ; do
	FN_DST=${LIST_DST[$I_DST]}
	echo "  DST $I_DST: $FN_DST"
	BASE_NAME=$(basename $FN_DST .root)
	echo "    $BASE_NAME"

	mkdir -p $DIR_WORK/$BASE_NAME/out
	cp -a    $DIR_BASE/gridrun.sh $DIR_WORK/$BASE_NAME

	if [ $USE_GRID = 'yes' ]; then
	    CMD="/e906/app/software/script/jobsub_submit_spinquest.sh"
	    CMD+=" --expected-lifetime='short'" # medium=8h, short=3h, long=23h
	    CMD+=" -L $DIR_WORK/$BASE_NAME/log_gridrun.txt"
	    CMD+=" -f $DIR_WORK/input.tar.gz"
	    CMD+=" -f $FN_DST"
	    CMD+=" -d OUTPUT $DIR_WORK/$BASE_NAME/out"
	    CMD+=" file://$DIR_WORK/$BASE_NAME/gridrun.sh $(basename $FN_DST) $N_EVT_ANA"
	    #echo "$CMD"
	    $CMD |& tee $DIR_WORK/$BASE_NAME/log_jobsub_submit.txt
	    RET_SUB=${PIPESTATUS[0]}
	    test $RET_SUB -ne 0 && exit $RET_SUB
	else
	    export  CONDOR_DIR_INPUT=$DIR_WORK/$BASE_NAME/in
	    export CONDOR_DIR_OUTPUT=$DIR_WORK/$BASE_NAME/out
	    mkdir -p $DIR_WORK/$BASE_NAME/in
	    cp -p $DIR_WORK/input.tar.gz $DIR_WORK/$BASE_NAME/in
	    cd $DIR_WORK/$BASE_NAME
	    $DIR_WORK/$BASE_NAME/gridrun.sh $FN_DST $N_EVT_ANA |& tee $DIR_WORK/$BASE_NAME/log_gridrun.txt
	fi
    done
}

##
## Main
##
test "X$1" != 'XGO' && echo "Give 'GO' to make a real run." && exit 1

if [ $USE_GRID = 'yes' ]; then
    echo "Grid mode."
    DIR_DATA=/pnfs/e1039/scratch/$USER/CalibChamXT
    DIR_WORK=$DIR_DATA/$VERSION
    ln -nfs $DIR_DATA data # for convenience
else
    echo "Local mode."
    DIR_WORK=$DIR_BASE/scratch/$VERSION
fi
echo "DIR_WORK = $DIR_WORK"
rm -rf   $DIR_WORK
mkdir -p $DIR_WORK

cd $DIR_BASE
tar czvf $DIR_WORK/input.tar.gz  ../inst Fun4AllReco.C geom.root

while read RUN ; do
    ProcessOneRun $RUN
    test $USE_GRID = 'no' && break ## Process one run in case of test
done <$LIST_RUN

echo "run_reco.sh finished."
if [ $USE_GRID = 'yes' ]; then
    echo "Use 'jobsub_q_mine' and wait until all grid jobs finish."
fi
