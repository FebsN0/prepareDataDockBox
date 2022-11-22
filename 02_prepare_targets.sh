#!/bin/bash
module load StdEnv/2018.3
module load   intel/2016.4  openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1
source ~/env/bin/activate

dirs=$(pwd)
dirs=$dirs/proteins
for dir in $dirs; do
  files_r="$files_r $dir/*.pdb"
done

prepare_targets  -r ${files_r}
