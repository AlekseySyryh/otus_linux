# Задание 1. Уменьшить том под / до 8G

Основная идея - т.к. уменьшать размер xfs раздела нельзя, то план такой:

1. Cоздадим временный раздел
2. Перенесем на него /
3. Загрузимся с него
4. Удалим старый раздел
5. Создадим новый (меньший) раздел
6. Перенесем на него /
7. Загрузимся с него
8. Удалим временный раздел

Воспроизведение

    scriptreplay -ttiming -sscript -m.5