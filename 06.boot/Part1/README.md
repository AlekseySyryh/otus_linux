# Попасть в систему без пароля несколькими способами

Все перечисленные варианты работают только при наличии физического доступа к компьютеру.
Для их применения нужно перезагрузиться, и при выборе варианта загрузке отредактировать его удалив в строке linux16 параметры console=... и добавив один из вариантов

## 1. init=/bin/sh

Мы попадем в конревую систему (по видимому это такой специальный sh, который сам делает chroot), но она смонтирована в ro ее нужно перемонтировать в rw

    mount -o remount,rw /

## 2. init=/bin/sh и заменить ro на rw

Аналогично п.1, но никаких действий не требуется

## 3. rd.break

В / смонтирована временная фс, нужная нам корневая фс смонтирована в /sysroot в ro, перемонтируем в rw

    mount -o remount,rw /sysroot
    
Затем переходим к п. 4

## 4. rd.break и заменить ro на rw

В / смонтирована временная фс, нужная нам корневая фс смонтирована в /sysroot 

Пора переключаться

    chroot /sysroot

## 5. init=/sysroot/bin/sh

Ситуация аналогична п.3

## 6. init=/sysroot/bin/sh и заменить ro на rw

Ситуация аналогична п.4

В результате мы вошли в систему без пароля.


