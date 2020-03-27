#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "Требуются root права." 
 	exit 1
fi

if [[ -f 'io' ]]; then
	echo "Программа io найдена."
else
	isGCCFound=`whereis gcc | grep '/gcc' | wc -l`
	if [[ $isGCCFound -eq 0 ]]; then
		echo "gcc не найден. Установите его, либо скопилируйте io.c в io самостоятельно."
		exit 1
	else
		gcc -o io io.c
		echo "Программа io скомпилирована."
	fi
fi

if [[ -f file ]]; then
	echo "Файл данных существует."
else
	echo "Файл данных не существует. Создаем."
	dd if=/dev/urandom of=file bs=1G count=1 iflag=fullblock status=none
  	sync #На всякий пожарный, что-бы точно с диска читать.
	echo "Файл создан."
fi

echo "Запустим программу."
\time -f 'Программа отработала за %E.' ./io

echo "Запустим две программы с равным приоритетом."
#Если оба процесса будут писать в одну консоль, весьма вероятно состояние гонки. Придется костылить...
\time -f 'Процесс 1 отработал за %E.' -o r1 ./io &
\time -f 'Процесс 2 отработал за %E.' -o r2 ./io &
wait
cat r1 
rm r1
cat r2
rm r2

echo "Запустим две программы с разным приоритетом."
#Тут гонка маловероятна, но для чистоты эксперимента пусть будет как раньше
\time -f 'Процесс c высшим приоритетом отработал за %E.' -o r1 ionice -c 1 ./io &
\time -f 'Процесс c низшим приоритетом отработал за %E.' -o r2 ionice -c 3 ./io &
wait
cat r1
rm r1
cat r2
rm r2

