#!/bin/bash
module load StdEnv/2018.3
module load   intel/2016.4  openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1
source ~/envDockBox/bin/activate


######################################--------------------------- FUNCTIONS ---------------------------------###################################


############------------ PREPARATION INPUT FILES --------------###################

function prepareInputFiles(){
	ls; pwd;
	files_r=()
	echo ""
	read -p "pathDirectory only where the file.pdb of the PROTEINS are saved. " dirpath
	for prot in $(ls $dirpath); do
        	echo "$prot taken"
        	if [[ $prot != *.pdb ]]; then
                	echo "$prot is not PDB file"
        	else
                	files_r+=($dirpath/$prot)
         	fi
	done
	prepare_targets  -r ${files_r[@]}

	#prepare ligands based on knowledge of binding sites
	echo ""
	read -p "Do you know which binding site are you focusing? If not, siteFinder of MOE will be used [true|false] " ansSite
	if $ansSite
	then
		read -p "pathDir/filename where SITES coordinates are saved " filepath_sites
		read -p "Number of binding sites? " nSites
		seqSites=$(seq 1 $nSites)
		vectSites=()
		count=0
		read -p "each site has own compound database? [true|false] " ansLigs
		if ! $ansLigs; then read "pathDirectory/filename where LIGANDS are saved and same for ALL sites" filepath_ligands; fi;
		for i in $seqSites; do
			echo ""
			read -p "run the docking on the site $i? [true|false] " ansTrueSite
			if $ansTrueSite; then
				vectSite+=("$(($count+1))"_site$i)
				mkdir ${vectSite[$count]}
				cd ${vectSite[$count]}
				count=$(($count+1))
#INSIDE DIR SITE i-esim
#save specific site coordinates
				sed -n "1p" $filepath_sites > siteInfo.csv #first row contain name columns
				sed -n "$(($i+1))p" $filepath_sites >> siteInfo.csv
#preparation ligand input file
				if $ansLigs; then read -p "pathDirectory/filename where LIGANDS for the ${vectSite[$count]} is saved. " filepath_ligands; fi;
				echo -e "\npreparing ligand input files for site$i | ${vectSite[$(($count-1))]}\n"
				cp $filepath_ligands ligands.mol2
				prepare_compounds -l ligands.mol2 -csv compounds.csv
				cd ..
			fi
		done
		wait
	else
#BLIND DOCKING (it use siteFinder of MOE)
		mkdir siteFinderAll
		cd siteFinderAll
		read "pathDirectory/filename where LIGANDS are saved and same for ALL sites: " filepath_ligands
		cp $filepath ligands.mol2
		prepare_compounds -l ligands.mol2 -csv compounds.csv
		python2.7 ./prepare_scripts/prepare_sites -r ${files_r[@]} -sitefinder -nsitesmax 50 -minplb 2
        	cd ..
	fi
cd $mainDir
}

###########---------- PREPARATION VIRTUAL SCREENING FILES X DOCKBOX ---------###########

function settingsAndPrepareVS(){
        echo -e "\npreparation settings $singleSite\n"
        cd $singleSite
#here you should have compounds.csv, ligands.mol2 and siteInfo.csv
	siteDir=`pwd`
#count number of ligands, -1 because name columns
        numLigs=$(($(wc -l compounds.csv | cut -d ' ' -f 1) -1))
	echo ""
        echo -e "number of compounds in $singleSite:\t$numLigs"
#if more 2000 ligs, there is splittings in further dirs (lig0001-1999 lig2000-etc)
	read -p 'number of ligands per job: ' nligxJob
        read -p 'level prepare_vs? [nligands*ntargets: < 1K [0] | <1M [1] | >1M [2] ]: ' level
	ls $filepath_config
	read -p 'what config file use? (NOTE: if level=2, no rescoring and 1 docking software only) ' configFilename
	cp $filepath_config/$configFilename config.ini
	if [ $level -eq 2 ]; then
                read -p 'So you have chosen level 2,  which software do you want use (same reported in config file)? ' software
        	outputName=outputVS04_$software
	else
        	outputName=outputVS04
	fi
	echo ""
        read -p 'time single job: [format hh:mm:ss] ' timeSlurm
        read -p 'number of cores for execute single job (ie: #SBATCH --cpus-per-task): ' cores
	echo "prepare_vs of $singleSite STARTED"
#bring the numLigs variable inside the function, otherwise it will be overwritten
#PARALLELIZATION
	startPrepareVS $numLigs $siteDir $timeSlurm $cores $nligxJob $level $outputName $singleSite $configFilename &
	cd ..
}

function lessORmore2000lig(){
#It build and correct path where run.slurm (in case level 0) or run.sh (in case of level 1 or 2) are saved in the run general file (inside to_submit dir)
#if more than 2000 ligands exist, prepare_vs generate more subdirectorie: ie "..../output04/lig/lig/target/...."  instead of "..../output04/lig/target/...."
#the variable "file" will be really important for the fixing step
       	if [[ $1 -ge 2000 ]]
        then
                file="vs/lig*/lig*/target*/run.*"
        else
                file="vs/lig*/target*/run.*"
        fi
}

#It contains the correct path to run.* for every ligand (run.slurm in case level 0 or run.sh in case of level 1)
#if more than 1000 ligands exist, prepare_vs generate more subdirectorie: ie "..../output04/lig/lig/target/...."  instead of "..../output04/lig/target/...."
#moreover, prepare_vs mistakes target path

function startPrepareVS(){
#1 $numLigs
#2 $siteDir
#3 $timeSlurm
#4 $cores
#5 $nligxJob
#6 $level
#7 $outputName
#8 $singleSite (name of site)
#9 $configFilename
        mkdir $7
        cd $7
        prepare_vs -l $2/compounds.csv -r $mainDir/targets.csv -s $2/siteInfo.csv -w vs -f $2/config.ini -slurm time,$3,cpus-per-task,$4,nodes,1,account,def-jtus,partition,default -nligands-per-job $5 -level $6
        echo -e "\nprepare_vs of $8 COMPLETE. starting the FIXING STEP\n"
	echo -e "\n$1 $2 $3 $4 $5 $6 $7 $8\n"
# $1 : numLigs
	fixing $1 $6 $7 $8
	cd $mainDir
}

function fixing(){
#1 $numLigs
#2 $level
#3 $outputName
#4 $singleSite
        if [ $2 -eq 0 ]; then
#update the correct path
                lessORmore2000lig $1
                sed -i '/#SBATCH --nodes=1/a module load StdEnv/2018.3 intel/2016.4 openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1' $file
                sed -i '/module load/a source ~/envDockBox/bin/activate' $file
                sed -i 's=vs/lig=../vs/lig=g' to_submit_vs/submit_all.sh
                chmod +x to_submit_vs/submit_all.sh

        elif [ $2 -eq 1 ]
        then
                lessORmore2000lig $1

                command1="sed -i '/#SBATCH --nodes=1/a module load StdEnv/2018.3 intel/2016.4 openmpi/2.1.1 amber/16 cuda/9.0.176 openbabel/2.4.1'"
                command2="sed -i '/module load/a source ~/envDockBox/bin/activate'"
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

        sed -i "s=$4/$3/targets=targets=g;" $file
#after having generated all poses for each docking/rescoring program, in order to avoid to save, even temporarily, huge amount of file,
#extract right after rundbx the best pose among the selected programs based only on score function. I didnt consensus docking because
#it returns best pose for each used program but i dont care (like my life) (in the config file I selected moe, vina (knowledge-empirical),
#dock (forcefield based) and moe (just to use a proprietary program)

#extract_dbx_best_poses generate "results" dir in which there is the definitive pose
        sed -i '/rm -rf/a extract_dbx_best_poses -copy -sf moe dock vina -skip-errors' $file
        sed -i '/extract_dbx_best_poses/a tar -zcf DockRescExtr.tar.gz autodock dock moe poses rescoring vina run.sh --remove-files' $file
#in the end, DockRescExtr.tar.gz and results directory (which contain 3 files: best_poses.csv  ligand.mol2  poses.csv) will exist
        echo -e "\nfixing of $4 COMPLETE\n"
}



####################################----------------------------------------MAIN-------------------------------------########################################

mainDir=`pwd`
read -p "all input files (compounds.csv, ligands.mol2 and sito.csv) are ready yet? [true|false]: " ansInput
if ! $ansInput; then
	prepareInputFiles
#it should be save vectSite
else
#the sites directories already exist, check them
	vectSite=$(ls | grep "[0-9]_site[0-9]")
fi

read -p "Have you properly prepared the config file inside configFiles directory? [true|false]: " ansConfig
if ! $ansConfig; then echo "please prepare the config files, exiting...\n"; exit 1; fi;
read -p "path directory where CONFIG file are saved " filepath_config
for singleSite in ${vectSite[@]}; do
	settingsAndPrepareVS
done

wait
