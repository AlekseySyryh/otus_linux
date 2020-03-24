#!/bin/bash
#lsof -t [file-name] 

help() {
	echo 'Возможные параметры запуска'
	echo './script.sh -u [username]'
	echo './script.sh -p [PID]'
	echo './script.sh -t [file-name]'
}

byUser() {
	for pid in `ls -l /proc | egrep "^d.+$user" | sed -E 's/^.+ ([0-9]+)$/\1/' | sort -n`; do
		byPid
	done
}

byPid() {
	if [ -r /proc/$pid ]; then
		echo "PID $pid"
		if [ -r /proc/$pid/fd ]; then
			for f in `ls -l /proc/$pid/fd | egrep '\/' | sed -E 's/^[^\/]+(.+)$/\1/' | sort | uniq`; do
				echo $f
			done
		else
			echo "Permission denied"
		fi
	fi
}

byFile() {
	for pid in `ls -1 /proc/ | egrep '^[0-9]+$' | sort -h`; do
		if [ -r /proc/$pid/fd ]; then
			for f in `ls -l /proc/$pid/fd | egrep '\/' | sed -E 's/^[^\/]+(.+)$/\1/' | sort | uniq`; do
				cnt=`ls -l /proc/$pid/fd | egrep "$file" | wc -l`
				if [ $cnt -gt 0 ]; then
					echo "PID $pid using file"				
				fi
			done
		else
			echo "PID $pid Permission denied"
		fi	
	done
}

if [[ $# -ne 2 ]]; then 
	help
elif [[ $1 == '-u' ]]; then
	user=$2
	byUser	
elif [[ $1 == '-p' ]]; then
	pid=$2
	byPid	
elif [[ $1 == '-t' ]]; then
	file=$2
	byFile	
else
	help
fi;
