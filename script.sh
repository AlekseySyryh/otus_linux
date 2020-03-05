#!/bin/sh
lock_file=/tmp/lock
access_log=access.log
last_run=/var/tmp/last_run
unprocessed_log_file=/tmp/unprocessed_log
mail_file=/tmp/mail

email=$1
x=$2
y=$3

if [[ $# -ne 3 ]]; then
	echo "Параметры запуска:"
	echo "script.sh email x y"
	exit -1
fi

get_first_line() {
	if [ -f $last_run ]; then
    		local last_run_time=`cat $last_run`
		local first_line=`cat -n $access_log | grep "$last_run_time" | cut -f 1`;
	else
		local first_line=0
	fi
	if [[ -z $first_line ]]; then
    		local first_line=0;
	else
    		local first_line=$((first_line + 1))
	fi;
	echo $first_line
}

while [ -f $lock_file ]; do
    echo "Идет фоновый процесс - ждем 10 секунд"
    sleep 10
done
trap 'rm -f "$lock_file";rm -f "$unprocessed_log_file";rm -f "$mail_file"; exit $?' INT TERM EXIT
touch $lock_file

first_line=$(get_first_line)
last_line=`cat $access_log | wc -l`

if [[ $first_line -lt $last_line ]]; then
    sed -n "$first_line,$last_line p" $access_log > $unprocessed_log_file

    first_time=`head -n 1 $unprocessed_log_file | sed -E 's/^.*\[(.+?)\].*/\1/'`
    last_time=`tail -n 1 $unprocessed_log_file | sed -E 's/^.*\[(.+?)\].*/\1/'`

    echo Статистика за период с $first_time по $last_time > $mail_file
    echo " " >> $mail_file
    echo 1. $x IP адресов с наибольшим кол-вом запросов >> $mail_file
    echo " " >> $mail_file
    cat $unprocessed_log_file | sed -E "s/^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}).+$/\1/" | sort | uniq -c | sort -rn | head -n $x | awk '{print "IP Адрес " $2 " сделал " $1 " запросов"}' >> $mail_file
    echo " " >> $mail_file
    echo 2. $y запрашиваемых адресов с наибольшим кол-вом запросов >> $mail_file
    echo " " >> $mail_file
    cat $unprocessed_log_file | grep -E "GET|POST|HEAD" | sed -E 's/^.+(GET|POST|HEAD) ([^ ]+).+$/\2/' | sort | uniq -c | sort -rn | head -n $y | awk '{print "Адрес " $2 " запрошен " $1 " раз"}' >> $mail_file
    echo " " >> $mail_file
    echo 3. Ошибки >> $mail_file
    echo " " >> $mail_file
    cat $unprocessed_log_file | grep -E '^.+".+" [45]' | sed -E 's/^.+\[([^ ]+).+\] (".+") ([0-9]{3}).+$/\1 ошибка \3 при запросе \2/' >> $mail_file
    echo " " >> $mail_file
    echo 4. Коды возврата >> $mail_file
    echo " " >> $mail_file
    cat $unprocessed_log_file | sed -E 's/^.+".*" ([0-9]{3}).+$/\1/' | sort | uniq -c | sort -rn | awk '{print "Код " $2 " встретился " $1 " раз"}' >> $mail_file

    mail -s "Статистика" $email < $mail_file
    echo $last_time > $last_run
fi

rm -f "$lock_file"
rm -f "$unprocessed_log_file"
rm -f "$mail_file"

trap - INT TERM EXIT
