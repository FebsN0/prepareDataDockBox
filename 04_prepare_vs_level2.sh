#!/bin/bash

module load StdEnv/2018.3
module load   intel/2016.4  openmpi/2.1.1 amber/16 cuda/9.0.176
module load openbabel/2.4.1
source ~/env/bin/activate

export PATH=/project/6001216/moe2019/bin:$PATH

########################------------------------- SETTING ---------------------------------#######################################
read -p 'level prepare_vs? [nligands*ntargets: < 1k(0) | <1M(1) | >1M(2)]: ' level
if [ $level -eq 2 ]
then
	echo "selected level 2, REMEMBER: no rescoring, only 1 socking software"
	read -p 'So.. which software do you want use? ' software
	sed "s/AAA/$software/g" config_level2.ini > config.ini
	outputPath=output04_$software
else
	cp config_level01.ini config.ini
	outputPath=output04
fi

read -p 'number of ligands per job: ' nligxJob
read -p 'time: [hh:mm:ss] ' timeSlurm
read -p 'number of cores for execute rundbx (ie: #SBATCH --cpus-per-task): ' cores
read -p 'number of sites: ' nSites
sorg=`pwd`

# -1 because first line compounds.csv report only name of each column
numLigs=$(($(wc -l $sorg/compounds.csv | cut -d ' ' -f 1) -1))

##############################--------------------------- FUNCTION PART --------------------------###################################
function preparationSingleSite(){
	outputName="$outputPath"_site"$nS"
	mkdir $outputName
	cd $outputName
	awk -v n="$nS" '{if(NR==1){{print $0}}; if(NR==n+1){{print $0}};}' $sorg/sito.csv > sito$nS.csv
	prepare_vs -l $sorg/compounds.csv -r $sorg/targets.csv -s sito$nS.csv -w vs -f $sorg/config.ini -slurm time,$timeSlurm,cpus-per-task,$cores,nodes,1,account,def-jtus -nligands-per-job $nligxJob -level $level
	echo "prepare_vs of site$nS DONE"
	fixing
}

#create variable $file based on number of lig. It contains the correct path to run.* for every ligand (run.slurm in case level 0 or run.sh in case of level 1)
#if more than 1000 ligands exist, prepare_vs generate more subdirectorie: ie "..../output04/lig/lig/target/...."  instead of "..../output04/lig/target/...."
#moreover, prepare_vs mistakes target path

function lessORmore1000lig(){
	if [[ $level -lt 2 && $1 -ge 1000 ]]
        then
                file="vs/lig*/lig*/target*/run.*"
        else
                file="vs/lig*/target*/run.*"
        fi
}


#add modules and activate virtual environment for each sbatch file
#adjust submit.sh file and set it executable

function fixing(){
	if [ $level -eq 0 ]
	then
		lessORmore1000lig $numLigs
		# $file updated
	        sed -i '/#SBATCH --nodes=1/a module load StdEnv/2018.3 intel/2016.4 openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1' $file
	        sed -i '/module load/a source ~/env/bin/activate' $file
		sed -i 's=vs/lig=../vs/lig=g' to_submit_vs/submit_all.sh
		chmod +x to_submit_vs/submit_all.sh

	elif [ $level -eq 1 ]
	then
		lessORmore1000lig $numLigs

        	command1="sed -i '/#SBATCH --nodes=1/a module load StdEnv/2018.3 intel/2016.4 openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1'"
        	command2="sed -i '/module load/a source ~/env/bin/activate'"
        	command3="sed -i 's=vs\/lig=..\/vs\/lig=g'"

	        sed -i "/sbatch \$file/i $command1 \$file" to_submit_vs/submit_all.sh
	        sed -i "/sbatch \$file/i $command2 \$file" to_submit_vs/submit_all.sh
	        sed -i "/sbatch \$file/i $command3 \$file\n" to_submit_vs/submit_all.sh

		sed -i 's=to_submit_vs/run_vs=run_vs=g' to_submit_vs/submit_all.sh
		chmod +x to_submit_vs/submit_all.sh

	elif [ $level -eq 2 ]
	then
		file="vs/job*/run.*"
       		sed -i '/#SBATCH --nodes=1/a module load StdEnv/2018.3 intel/2016.4 openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1' $file
	        sed -i '/module load/a source ~/env/bin/activate' $file

		sed -i 's=vs/job=../vs/job=g' to_submit_vs/submit_all.sh
        	chmod +x to_submit_vs/submit_all.sh
	fi

	sed -i "s=$outputName\/targets=targets=g;" $file
#after having generated all poses for each docking/rescoring program, in order to avoid to save, even temporarily, huge amount of file,
#extract right after rundbx the best pose among the selected programs based only on score function. I didnt consensus docking because
#it returns best pose for each used program but i dont care (like my life) (in the config file I selected moe, vina (knowledge-empirical),
#dock (forcefield based) and moe (just to use a proprietary program)

#extract_dbx_best_poses generate "results" dir in which there is the definitive pose
	sed -i '/rm -rf/a extract_dbx_best_poses -copy -sf moe dock vina -skip-errors' $file
	sed -i '/extract_dbx_best_poses/a tar -zcf DockRescExtr.tar.gz autodock dock moe poses rescoring vina run.sh --remove-files' $file
#in the end, DockRescExtr.tar.gz and results directory (which contain 3 files: best_poses.csv  ligand.mol2  poses.csv) will exist
	echo "fixing of site$nS DONE"
}








################################---------------------- MAIN CODE ----------------------#############

val=$(seq 1 $nSites)
for nS in $val
do
        preparationSingleSite &
done
wait
rm $sorg/config.ini
