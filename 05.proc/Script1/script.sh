#!/bin/bash
clock_ticks=$(getconf CLK_TCK)
echo "  PID TTY      STAT   TIME COMMAND"
for pid in `ls -1 /proc/ | egrep '^[0-9]+$' | sort -h`; do
	if [ -d "/proc/$pid" ]; then
		
		#TTY
		ttyid=`awk '{print $7}' /proc/$pid/stat`
		if [ $ttyid -eq 0 ]; then
			tty='?'
		else
			major=$((ttyid / 256))
			minor=$((ttyid % 256))
			if [ $major -eq 4 ]; then
				tty="tty$minor"
			elif [ $major -eq 136 ]; then
				tty="pts/$minor"
			else
				tty='?'
			fi
		fi

		#Status
		status=`awk '{print $3}' /proc/$pid/stat`
		
		#High/low priority
		pnice=`awk '{print $19}' /proc/$pid/stat`
		if [ $pnice -lt 0 ]; then
			status="${status}<"
		elif [ $pnice -gt 0 ]; then
			status="${status}N"
		fi

		#has pages locked into memory
		lock=`egrep 'VmLck:.+[1-9]' /proc/$pid/status | wc -l`
		if [ $lock -gt 0 ]; then
			status="${status}L"
		fi

		#session leader
		sid=`awk '{print $6}' /proc/$pid/stat`
		if [ $pid -eq $sid ]; then
			status="${status}s"
		fi

		#multi-threaded
		threads=`awk '{print $20}' /proc/$pid/stat`
		if [ $threads -gt 1 ]; then
			status="${status}l"
		fi


		#foreground process group
		tpgid=`awk '{print $8}' /proc/$pid/stat`
		if [ $pid -eq $tpgid ]; then
			status="${status}+"
		fi

		#time
		utime=`awk '{print $14}' /proc/$pid/stat`
	        stime=`awk '{print $15}' /proc/$pid/stat`
		cutime=`awk '{print $16}' /proc/$pid/stat`
	       	cstime=`awk '{print $17}' /proc/$pid/stat`
		time=$(((utime+stime+cutime+cstime)/clock_ticks))
		min=$((time / 60))
		sec=$((time % 60))

		printf '%5d %-8s %-6s %d:%02d ' $pid $tty $status $min $sec
		#cmdline
		cmdline=`head -c 100 /proc/$pid/cmdline  | tr '\0' ' '`
		if [[ -z $cmdline ]]; then
			cmdline=`awk '{gsub("\(","[",$2);gsub("\)","]",$2);print $2}' /proc/$pid/stat`
		fi
		echo $cmdline
	fi
done
