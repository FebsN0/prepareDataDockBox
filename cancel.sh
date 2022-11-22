#!/bin/bash

read -p 'which site cancel? [1_sito2 | 2_sito3 ] ' name
cd $name/output04/vs/lig2*
for i in lig*
do
	rm -r $i &
	i=$(($i+1))
	if [ $(($i%32)) -eq 0 ]
	then
		wait
	fi
done
wait
