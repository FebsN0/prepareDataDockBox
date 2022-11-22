#!/bin/bash
module load StdEnv/2018.3
module load   intel/2016.4  openmpi/2.1.1 amber/16 cuda/9.0.176
source ~/env/bin/activate

export PATH=/project/6001216/moe2019/bin:$PATH

dirs=targets/target00*
for dir in $dirs; do
    files_r="$files_r $dir/*pdb"
done

python2.7 ./prepare_scripts/prepare_sites -r ${files_r} -sitefinder -nsitesmax 50 -minplb 2

#prepare_sites -r targets.csv -sitefinder -nsitesmax 50 -minplb -1


