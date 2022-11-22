#!/bin/bash
module load StdEnv/2018.3
module load   intel/2016.4  openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1
source ~/env/bin/activate

read -p "Number of binding sites? " nSites
seqSites=$(seq 1 $nSites)

read -p "each site has own compound database? [true|false] " ans
if ! $ans; then
	read -p "pathDirectory/filename where the data of ligands for all site is saved. " filepath
fi

if [[ ! -d sites* ]]
then
	for i in $seqSites; do
		echo -e "\npreparing ligand input files for site $i\n"
		mkdir site_"$i"
		cd site_"$i"
		if $ans; then
			read -p "pathDirectory/filename where the data of ligands for site $i is saved. " filepath
		fi
		cp $filepath ligands.mol2
		prepare_compounds -l ligands.mol2 -csv compounds.csv
		cd ..
	done
fi


files_r=()
read -p "pathDirectory only where the file.pdb of the PROTEINS are saved. " dirpath
for prot in $(ls $dirpath)
do
	echo $prot
	if [[ $prot != *.pdb ]]
	then
		echo "$prot is not PDB file"
	else
		files_r+=($dirpath/$prot)
	 fi
done

prepare_targets  -r ${files_r[@]}
