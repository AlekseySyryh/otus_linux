#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "Требуются root права."
 	exit 1
fi

if [[ -f 'cpu' ]]; then
	echo "Программа cpu найдена."
else
	isGCCFound=`whereis gcc | grep '/gcc' | wc -l`
	if [[ $isGCCFound -eq 0 ]]; then
		echo "gcc не найден. Установите его, либо скопилируйте cpu.c в cpu самостоятельно."
		exit 1
	else
		gcc -o cpu cpu.c -lm -lpthread
		echo "Программа cpu скомпилирована."
	fi
fi

echo "Запустим программу."
\time -f 'Программа отработала за %E.' ./cpu

echo "Запустим две программы с равным приоритетом."
#Если оба процесса будут писать в одну консоль, весьма вероятно состояние гонки. Придется костылить...
\time -f 'Процесс 1 отработал за %E.' -o r1 ./cpu &
\time -f 'Процесс 2 отработал за %E.' -o r2 ./cpu &
wait
cat r1
rm r1
cat r2
rm r2

echo "Запустим две программы с разным приоритетом."
#Тут гонка маловероятна, но для чистоты эксперимента пусть будет как раньше
\time -f 'Процесс c высшимим приоритетом отработал за %E.' -o r1 nice -n -50 ./cpu &
\time -f 'Процесс c низшимим приоритетом отработал за %E.' -o r2 nice -n 50 ./cpu &
wait
cat r1
rm r1
cat r2
rm r2
