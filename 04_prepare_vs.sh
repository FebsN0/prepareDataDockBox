#!/bin/bash

module load StdEnv/2018.3
module load   intel/2016.4  openmpi/2.1.1 amber/16 cuda/9.0.176
module load openbabel/2.4.1
source ~/env/bin/activate


function lessORmore2000lig(){
        if [[ $level -lt 2 && $1 -ge 2000 ]]
        then
                file="vs/lig*/lig*/target*/run.*"
        else
                file="vs/lig*/target*/run.*"
        fi
}

#the code is written in a way in which I have choosen manually best sites and there is a specific set of compounds
#for each site (they are from pharmacophore filtering for each site, thus each set has different number of compounds)

read -p 'number of cores for execute rundbx (ie: #SBATCH --cpus-per-task):  ' cores

#elenca tutti i siti directory
sites=$(ls | grep "[1234]_sito[1234]")
#sites=2_sito3
for i in $sites
do
	mkdir $i/output04
	cd $i/output04
	numLigs=$(($(wc -l ../compounds.csv | cut -d ' ' -f 1) -1))
	lessORmore2000lig $numLigs
	echo "preparazione $i"
	read -p 'level prepare_vs? [nligands*ntargets: < 1k(0) | <1M(1) | >1M(2)]: ' level
	read -p 'number of ligands per job: ' nligxJob
	read -p 'time: [hh:mm:ss] ' timeSlurm
	prepare_vs -l ../compounds.csv -r ../../targets.csv -s ../sito.csv -w vs -f ../../config.ini -slurm time,$timeSlurm,cpus-per-task,$cores,nodes,1,account,def-jtus,partition,default -nligands-per-job $nligxJob -level $level

	read -p "number of ligands is > 1000 in $i? [yes|no] " answer
	if [ $answer = yes ]
	then
		sed -i "s=$i\/output04\/targets=targets=g;" vs/lig*/lig*/target*/run.*
	elif [ $answer = no ]
	then
		sed -i "s=$i\/output04\/targets=targets=g;" vs/lig*/target*/run.*
	else
		exit 0
	fi
#siccome non ho messo tali loads in bashrc, c'e la necessita di farlo per ogni run.slurm. easy per level 0 perche genera un solo run.slurm
#ma in caso di level > 0, si avranno piu diversi run.slurm dentro to_submit_vs
	command1="sed -i '/#SBATCH --nodes=1/a module load StdEnv/2018.3 intel/2016.4 openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1'"
	command2="sed -i '/module load/a source ~/env/bin/activate'"
	command3="sed -i 's=vs\/lig=..\/vs\/lig=g'"

	if [ $level -eq 0 ]
	then
		sed -i '/#SBATCH --nodes=1/a module load StdEnv/2018.3 intel/2016.4 openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1' $file
                sed -i '/module load/a source ~/env/bin/activate' $file
	else
		sed -i "/sbatch \$file/i $command1 \$file" to_submit_vs/submit_all.sh
		sed -i "/sbatch \$file/i $command2 \$file" to_submit_vs/submit_all.sh
		sed -i "/sbatch \$file/i $command3 \$file\n" to_submit_vs/submit_all.sh
		sed -i 's=to_submit_vs/run_vs=run_vs=g' to_submit_vs/submit_all.sh
                chmod +x to_submit_vs/submit_all.sh
	fi

	sed -i "s=output04\/targets=targets=g;" $file
#after having generated all poses for each docking/rescoring program, in order to avoid to save, even temporarily, huge amount of file,
#extract right after rundbx the best pose among the selected programs based only on score function. I didnt consensus docking because
#it returns best pose for each used program but i dont care (like my life) (in the config file I selected moe, vina (knowledge-empirical),
#dock (forcefield based) and moe (just to use a proprietary program)

#extract_dbx_best_poses generate "results" dir in which there is the definitive pose
        sed -i '/rm -rf/a extract_dbx_best_poses -copy -sf moe dock vina -skip-errors' $file
        sed -i '/extract_dbx_best_poses/a tar -zcf DockRescExtr.tar.gz autodock dock moe poses rescoring vina run.sh --remove-files' $file
#in the end, DockRescExtr.tar.gz and results directory (which contain 3 files: best_poses.csv  ligand.mol2  poses.csv) will exist
        echo "fixing of site$nS DONE"
	cd ../..
	read -p "continue? [true|false] " ans
	if $ans
	then
		exit 1
	fi
done



#after having generated all poses for each docking/rescoring program, in order to avoid to save, even temporarily, huge amount of file,
#extract right after rundbx the best pose among the selected programs based only on score function. I didnt consensus docking because
#it returns best pose for each used program but i dont care (like my life) (in the config file I selected moe, vina (knowledge-empirical),
#dock (forcefield based) and moe (just to use a proprietary program
