#!/bin/bash
module load StdEnv/2018.3
module load   intel/2016.4  openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1
source ~/env/bin/activate


sites=$(ls | grep "[12]_sito*")
for i in $sites
do
	cd $i
	prepare_compounds -l ligands.mol2  -csv compounds.csv
	cd ..
done
