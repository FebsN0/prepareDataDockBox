#!/bin/bash

#SEARC IF EVERY SCORE GIVEN EXIST

read -p 'which site? [12]_sito[23]: ' risp1
read -p 'There are more than 1000 ligands? ' risp2
sorg1=`pwd`
cd $risp1/output04/vs

function findOK_ERRORs(){
	sorg2=`pwd`
	for j in lig*
	do
		cd $j/target001/rescoring
		if [[ -e autodock.score && -e vina.score && -e moe.score && -e autodock.score && -e dsx.score ]]
		then
			echo "$j ok" >> $sorg1/result_$risp1
		else
			echo "$j error" >> $sorg1/result_$risp1
		fi
		cd $sorg2
	done
}

#se ci sono piu di mille ligandi, si creano ulteriori subdirs. lig*/lig*
if [ $risp2 = yes ] #piu di mille ligandi
then
	for i in lig*
	do
		cd $i
                findOK_ERRORs
		cd ..
	done
elif [ $risp2 = no ]
then
	findOK_ERRORs
fi
