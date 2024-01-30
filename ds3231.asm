; *=============================================================================*
; * Пример использования библиотеки PCF8584 для взаимодействия с RTC DS3231SN	*
; * Чтение даты времени и температуры с выводом на экран. Установка времени	*
; * ============================================================================*
;
; Регистры контроллера DS3231
DS3231_SECONDS:	equ	00h	; Address 'Seconds' register		(00-59) BCD
DS3231_MINUTES:	equ	01h	; Address 'Minutes' register		(00-59) BCD
DS3231_HOURS:	equ	02h	; Address 'Hours' register		(1-12 + PM/AM or 00-23) BCD
DS3231_DAYS:	equ	03h	; Address 'DAYS' register		(1-7) BCD
DS3231_DATE:	equ	04h	; Address 'DATE' register		(01-31) BCD
DS3231_MONTH:	equ	05h	; Address 'Month/Country' register	(01-12 + Country) BCD
DS3231_YEAR:	equ	06h	; Address 'Year' register		(00-99) BCD
DS3231_A1SEC:	equ	07h	; Address 'Alarm_1 Seconds' register	(00-59)	BINtoBCD
DS3231_A1MIN:	equ	08h	; Address 'Alarm_1 Minutes' register	(00-59)	BCD
DS3231_A1HRS:	equ	09h	; Address 'Alarm_1 Hours' register	(1-12 + PM/AM or 00-23) BCD
DS3231_A1DATE:	equ	0ah	; Address 'Alarm_1 date' register	(1-7) BCD or (00-59) BCD  (bit 7 = DY/!DT)
DS3231_A2MIN:	equ	0bh	; Address 'Alarm_2 Minutes' register	(00-59)	BCD
DS3231_A2HRS:	equ	0ch	; Address 'Alarm_2 Hours' register	(1-12 + PM/AM or 00-23) BCD
DS3231_A2DATE:	equ	0dh	; Address 'Alarm_2 date' register	(1-7) BCD or (00-59) BCD  (bit 7 = DY/!DT)
DS3231_CONTROL:	equ	0eh	; Address 'Control' Register: 		!EOSC,BBSQW,CONV,RS2,RS1,INTCN,A2IE,A1IE
DS3231_STATUS:	equ	0fh	; Address 'Status' Register: 		OSF,0,0,0,EN32kHz,BSY,A2F,A1F
DS3231_MTEMP:	equ	11h	; Address 'Aging Offset' register	SIGN + 7-bit data
DS3231_MTEMP:	equ	11h	; Address 'Temperature int' register	SIGN + 7-bit data
DS3231_LTEMP:	equ	12h	; Address 'Temperature 1/4' register	2-bit fract data 0.25C
; Буфер данных для передаче контроллеру
RTC_TIMEBUFFER:
	defb 00h,00h,37h,18h,05h,18h,11h,16h
;	     REG,SEC,MIN,HOU,DAY,DTE,MTH,YEA
RTC_TMTXTBUFF:
	defb "00:00:00 AM " 
;
; Задействуем библиотеку контроллера i2c:
	include "pcf8584.asm"
; ------------------------------
;
; ==============================
; DS3231 Read Current time
;	 to buffer
; input:
;	none
; output:
;	none
; ------------------------------
RTC_TIMEREAD:
	ld hl,RTC_TIMEBUFFER	; Адрес буфера времени
	ld (hl),DS3231_SECONDS	; Читать данные начиная с регистра 00h
	ld e,01h		; Отправить один байт (адрес регистра - значение '00h' первого байта TIMEBUFFER)
	ld d,I2C_RTC		; Адрес контроллера RTC
	call PCF_MASTER_TX	; Устанавливаем адрес регистра (00) с которого начнет роизводиться чтение
	ld e,07h		; Прочесть в буфер данные 7-ми регистров начиная с секунд и заканчивая годом
	ld d,I2C_RTC
	call PCF_MASTER_RX	; Читаем данные в буфер
	ret			; Выход из процедуры - буфер содержит текущее время
; ------------------------------
;
; ==============================
; DS3231 Write Current time
;	 from buffer
; input:
;	none
; output:
;	none
; ------------------------------
RTC_TIMEWRITE:
	ld hl,RTC_TIMEBUFFER	; Адрес буфера времени
	ld (hl),DS3231_SECONDS	; Писать данные начиная с регистра 00h
	ld e,08h		; Отправить 8 байт (адрес регистра - значение '00h' первого байта TIMEBUFFER + 7 байт строка с датой)
	ld d,I2C_RTC		; Адрес контроллера RTC
	call PCF_MASTER_TX	; Пишем содержимое буфера начиная с установки регистра адреса 00h
	ret			; Выход из процедуры - буфер содержит текущее время
; ------------------------------
;
; ==============================
; DS3231 Read Current Temperature
;	 to buffer
; input:
;	none
; output:
;	none
; ------------------------------
RTC_TEMPREAD:
	ld hl,RTC_TIMEBUFFER	; Адрес буфера времени
	ld (hl),DS3231_MTEMP	; Читать данные начиная с регистра 11h
	ld e,01h		; Отправить один байт (адрес регистра - значение '11h' первого байта TIMEBUFFER)
	ld d,I2C_RTC		; Адрес контроллера RTC
	call PCF_MASTER_TX	; Устанавливаем адрес регистра (11) с которого начнет роизводиться чтение
	ld e,02h		; Прочесть в буфер данные 7-ми регистров начиная с секунд и заканчивая годом
	ld d,I2C_RTC
	call PCF_MASTER_RX	; Читаем данные в буфер
	ret			; Выход из процедуры - буфер содержит текущую температуру
; ------------------------------
;
; ==============================
; DS3231 Set Alarm_1 time
;	 from buffer
; input:
;	none
; output:
;	none
; ------------------------------
RTC_ALARM1SET:
	ld hl,RTC_TIMEBUFFER	; Адрес буфера времени
	ld (hl),DS3231_A1SEC	; Писать данные начиная с регистра 07h
	ld e,05h		; Отправить 5 байт (адрес регистра - значение '07h' первого байта TIMEBUFFER + 4 байта строка начиная с секунд и заканчивая датой)
	ld d,I2C_RTC		; Адрес контроллера RTC
	call PCF_MASTER_TX	; Пишем содержимое буфера начиная с установки регистра адреса 07h
	ret			; Выход из процедуры
; ------------------------------
;
; ==============================
; DS3231 Set Alarm_2 time
;	 from buffer
; input:
;	none
; output:
;	none
; ------------------------------
RTC_ALARM1SET:
	ld hl,RTC_TIMEBUFFER	; Адрес буфера времени
	ld (hl),DS3231_A2MIN	; Писать данные начиная с регистра 0bh
	ld e,04h		; Отправить 4 байта (адрес регистра - значение '0bh' первого байта TIMEBUFFER + 3 байта строка начиная с минут и заканчивая датой)
	ld d,I2C_RTC		; Адрес контроллера RTC
	call PCF_MASTER_TX	; Пишем содержимое буфера начиная с установки регистра адреса 0bh
	ret			; Выход из процедуры
; ------------------------------
;
; ==============================
; DS3231 Read Current Alarm 1
;	 to buffer
; input:
;	none
; output:
;	none
; ------------------------------
RTC_ALARM1READ:
	ld hl,RTC_TIMEBUFFER	; Адрес буфера времени
	ld (hl),DS3231_A1SEC	; Читать данные с регистра 07h
	ld e,01h		; Отправить один байт (адрес регистра - значение '07h' первого байта TIMEBUFFER)
	ld d,I2C_RTC		; Адрес контроллера RTC
	call PCF_MASTER_TX	; Устанавливаем адрес регистра (07) с которого начнет роизводиться чтение
	ld e,04h		; Прочесть в буфер данные 4-х регистров начиная с секунд и заканчивая днём
	ld d,I2C_RTC
	call PCF_MASTER_RX	; Читаем данные в буфер
	ret			; Выход из процедуры - буфер содержит текущую установку будильника N1
; ------------------------------
;
; ==============================
; DS3231 Read Current Alarm 2
;	 to buffer
; input:
;	none
; output:
;	none
; ------------------------------
RTC_ALARM2READ:
	ld hl,RTC_TIMEBUFFER	; Адрес буфера времени
	ld (hl),DS3231_A2MIN	; Читать данные с регистра 0bh
	ld e,01h		; Отправить один байт (адрес регистра - значение '0bh' первого байта TIMEBUFFER)
	ld d,I2C_RTC		; Адрес контроллера RTC
	call PCF_MASTER_TX	; Устанавливаем адрес регистра (0b) с которого начнет роизводиться чтение
	ld e,03h		; Прочесть в буфер данные 3-х регистров начиная с минут и заканчивая днём
	ld d,I2C_RTC
	call PCF_MASTER_RX	; Читаем данные в буфер
	ret			; Выход из процедуры - буфер содержит текущую установку будильника N1
; ------------------------------
;
; ==============================
; Convert timedata to text
; ТРЕБУЕТСЯ ДОРАБОТКА !!!
; НЕ ОБРАБАТЫВАБТСЯ AM/PM
; (КОНЕЦ СТРОКИ УСТАНАВЛИВАЕТСЯ 
; ПЕРЕД ЭТИМ ПОЛЕМ ВНЕ ЗАВИСИМОСТИ
; ОТ РЕЖИМА
; input:
;	none
; output:
;	none
; ------------------------------
RTC_TMTOSTR:
	ld hl,RTC_TIMEBUFFER + 3	; Указатель конца буфера на часы
	ld de,RTC_TMTXTBUFF		; Указатель буфера для преобразования в текст
	ld a,(hl)
	rld				; Al <- (HL)h, rotate (HL)  В старшей и младшей тетраде A получаем содержимое старшей тетрады.
	bit 2,a				; 12/24 режим работы
	push af				; Сохраним A в неизменном виде
	jr z,RTC_24			; Если = 1, то отображать как AM/PM, иначе
	bit 1,a				; AM или PM ?
	call RTC_SETAMPM
	and 01h				; Выделить биты  AM/PM или 10/20 из младшей тетрады
  RTC_24:
	and 03h				; Сохранить только значения в диапазоне 0-7
	add 30h				; Сложить полученное значение (0-2) с ASCII '0' для получения старшего разряда часов
	ld (de),a			; Записываем первый символ (десятки часов)
	inc de				; Следующаяя ячейка буфера
	pop af				; Восстановим A
	call TMTXT_SHIFT		; Преобразуем десятичный разряд
	ld a,":"			; загрузим разделитель
	call TMTXT_CONV			; установим разделитель, преобразуем и запишем в буфер 10-ки и 1-цы
	ld a,":"			; загрузим разделитель
	call TMTXT_CONV			; установим разделитель, преобразуем и запишем в буфер 10-ки и 1-цы
	xor a				; Символ конца строки
	ld (de),a			; Записали символ конца строки в конец буфера
	ret				; Конец преобразования, выходим из подпрограммы

  RTC_SETAMPM:
	push hl				; Сохраним адрес начала буфера
	ld hl,RTC_TMTXTBUFF + 9		; Адрес символа A или P
	ld (hl),"A"			; Предварительно запишем туда символ "A"
	jr z,RTC_SETAM			; Но если bit1 = 1, то 
	ld (hl),"P"			; перезапишем на "P"
  RTC_SETAM:
	pop hl				; Восстановим адрес начала буфера
	ret

  TMTXT_CONV:
	ld (de),a			; Устанавливаем разделитель
	inc de				; Пропускаем разделитель ':'
	dec hl				; Указатель буфера на байт минут
	ld a,(hl)			; Читаем значение полученное от DS
	call TMTXT_SHIFT		; Записали в текстовый буфер десятки минут
	call TMTXT_SHIFT		; Записали в текстовый буфер единицы минут
	ret

; ------------------------------	
  TMTXT_SHIFT:	
  jp CONV_HEXTOSYM
;	rld				; Десятки часов/минут/секунд в младшую тетраду
;	and 0fh				; Оставляем содержимое только младшей тетрады
;	add 30h				; Сложим полученное значение (0-9) с ASCII '0'
;	ld (de),a			; Записываем десятки часов/минут/секунд в текущую позицию текстового буфера
;	inc de				; Выбираем следующую ячейку текстового буфера (единицы часов/минут/секунд)
;	ret				; Выход из подпрограмм	
; ------------------------------
;
; ==============================
; Convert tempdata to text
; ТРЕБУЕТСЯ ДОРАБОТКА !!!
; НЕКОРРЕКТНО ПРЕОБРАЗУЮТСЯ ЗНАЧЕНИЯ
; В ДИАПОЗОНЕ 120-122 C
; input:
;	none
; output:
;	none
; ------------------------------
RTC_TEMPTOSTR:
	ld de,RTC_TIMEBUFFER + 1	; Указатель начала буфера на единицы градусов
	ld hl,RTC_TMTXTBUFF		; Указатель буфера для преобразования в текст
	ld (hl),"+"			; По умолчанию температура плюсовая (+)
	ld a,(de)			; Читаем байт целой части температуры
	bit 7,a				; Знак температуры +/-
	jr z,RTC_CHSIGN_SKIP		; Если не "1", то оставляем + иначе
	ld (hl),"-"			; Знак (-)
  RTC_CHSIGN_SKIP:
	inc hl				; Следующее знакоместо в буфере
	and 7fh				; Очищаем бит знака температуры
	call BINTOBCD			; Вызываем преобразование BINtoBCD
	jr nc,RTC_3DEC_SKIP
	ld (hl),"1"			; Если >99, добавим разряд с сотнями
	inc hl				; Следующее знакоместо в буфере
  RTC_3DEC_SKIP:
	ex de,hl			; Приведём назначение регистров к общей форме
	ld (hl),a			; Сохраним для RLD преобразования BCD число в ячейку где хранилось BIN значение температуры
	call TMTXT_SHIFT		; Преобразуем старшую тетрату в число, сохраним в буфер (DE) и вычислим следующий адрес буфера
	call TMTXT_SHIFT		; Преобразуем младшую тетрату в число, сохраним в буфер (DE) и вычислим следующий адрес буфера
	xor a
	ld (de),a			; записать конец строки
	ret

; ------------------------------
  BINTOBCD:	
	ld b,a
  table_print:
	xor a				; Начинаем вычисление корректировки младшей декады в зависимости от значений в старшей тетраде.
	bit 4,b
	jr z,skip_add6
	add 6h
  skip_add6:
	bit 5,b
	jr z,skip_add2
	add 12h
  skip_add2:
	bit 6,b
	jr z,skip_add4
	add 24h
  skip_add4:
	ld c,a
	ld a,b
	or a				; Установка флагов в корректное состояние для операции DAA
	daa				; Десятичная коррекция младшей тетрады
	add c				; Добавить в разряд единиц перенос из старших разрядов (16 + 32 + 64)
	daa				; Десятичная коррекция младшей тетрады после двоичного сложения
	ret

; ------------------------------
;
; КОД ДЛЯ ТЕСТИРОВАНИЯ ПРЕОБРАЗОВАНИЯ BINtoBCD (от 127 до 0 преобразует в BCD и результат отправляет в TTY)
;
test:	
	ld b, 127
print:
	push bc
	ld a,b
	call BINTOBCD
	out (0f2h),a
	pop bc
	djnz print
	ret