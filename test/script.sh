set -e
set -x

#export WM_PROJECT_DIR=$(realpath /lib/OpenFOAM-11)
source $WM_PROJECT_DIR/etc/bashrc

id
#cd $HOME
#cp -r $WM_PROJECT_DIR/tutorials/incompressibleFluid/motorBike .
cd motorBike/motorBike
chmod +rw .
mkdir -p constant/geometry
chmod 777 -R .
cp -r $WM_PROJECT_DIR/tutorials/resources/geometry/motorBike.obj.gz constant/geometry/

# Run in localhost with one MPI process per core
export NUM_PROCESSORS=8
# create a hostfile to list the set of hosts on which to spawn MPI processes
# using localhost with N processors
echo "localhost slots=$NUM_PROCESSORS" > hostfile

# Does not work because of hostfile not provided
# ./Allrun
PARAMS="-n $NUM_PROCESSORS --hostfile hostfile"

# Source tutorial run functions
. $WM_PROJECT_DIR/bin/tools/RunFunctions

PARAMS="--hostfile ./hostfile -np $NUM_PROCESSORS"

runApplication blockMesh
runApplication decomposePar -copyZero
mpirun $PARAMS snappyHexMesh -overwrite

find . -type f -iname "*level*" -exec rm {} \;

mpirun $PARAMS renumberMesh -overwrite
mpirun $PARAMS potentialFoam -initialiseUBCs
mpirun $PARAMS $(getApplication)

