#!/bin/bash

module load StdEnv/2018.3
module load   intel/2016.4  openmpi/2.1.1 amber/16 cuda/9.0.176
module load openbabel/2.4.1
source ~/env/bin/activate


#for i in [12]_sito*
#do
cd 1_sito2/output04/vs
sor=$(pwd)
for j in lig[34]*
do
	cd $j/target*
	extract_dbx_best_poses -copy -sf moe dock autodock dsx vina -skip-errors
	cd $sor
done

