; z80dasm 1.1.3
; command line: z80dasm -a --origin=0h --output list.txt ./bios_z80.bin

	org	00000h
	include "init.asm"	; Инициализация регистров управдления и таймера
	include "memory.asm"	; Тест базовой памяти
	include "interrupt.asm" ; Обработчик прерывания на адресе 0038h - сканирование клавиатуры
; Memory error proc		  Процедура уведомления об ошибке памяти - не может быть перемещена в другой адрес из-за короткого перехода в "memory.asm", размер которой не может быть изменён
MERROR:	
	jp MERRMSG
;				; Memory.asm осуществляет вызов INIT короткой функцией JR, соответственно перед INIT не допускается вставка кода!!!!!!!
;===============================
; Main loop
;===============================
INIT:
; Set base memory page
	ld a,0ffh		; (   ) Выбираем порт для которого воспроизводится чтение (A14=A15=1, A7=1 RESET)
	in a,(0bdh)		; Читаем из порта (подключаем свободную страницу памяти в область #C000) (по умолчанию дублируется с #0000-#4000)
	ld a,03h		; Устанавливаем D0D1 в 1 для разрешения миниклавиатуры
	out (11110110b),a	; (#F6) Записываем его в порт данных PS/2  (KD0,KD1=1)
	out (11110110b),a	; (#F6) Записываем его в порт данных PS/2  (KD2,KD3=1)
; Clear memory upper address 32768
	ld hl,08000h		; Загружаем адрес начала очищаемого блока памяти
	ld de,08001h		; Загружаем адрес следующей за ним ячейки блока
	ld bc,07fffh		; Загружаем размер блока-1
	xor a			; Очищаем аккумулятор
	ld (hl),a		; Пишем 0 в первый адрес блока
	ldir			; "Растягиваем" содержимое первого адреса по всему блоку
; Keyboard driver init
	ld a,03h		; Минимальное время удержание клавиши =A/25 
	ld hl,8002h		; Адрес переменной длительности задержки
	ld (hl),a		; Установить значение переменной
	inc hl			; Вычислить адрес дополнительной переменной
	ld (hl),a		; Загрузить значение времени.
	ei			; Разрешить прерывания
; Call Display Init
	call DISP_INIT		; Инициализировать дисплей (сброс кристаллов)
	call DISP_ON		; Включить оба кристалла
	call CLEAR_SCREEN	; Выполнить очистку экрана
	call INVERSE_SCREEN
	ld hl,0000h		; Установить позицию вывода XY=0,0
	set 7,l
	ld de,INITSTR		; Установить адрес строки приветствия.
	call PRN_STRING		; Вывести сообщение о готовности
	halt			; 
; ==============================
; end of main loop
; ==============================
;
	push hl
; Тут что-нибудь тестируем:
	ld a,80h			; знаковое
	ld de,CONV_OUT
	ld hl,CONV_DATA
	call CONV_BIN8TODEC
	ex de,hl
	pop hl
	call PRN_STRING
	
	jp KEY_INPUT
; - Например конвертор BINtoHEX
TEST_LOOP:
	push hl
	ld hl,CONV_DATA
	inc hl
	inc hl
	inc (hl)
	ex af,af'
	dec hl
	ex af,af'
	jr nz,TEST_LOOP_SKIP1
	inc (hl)
TEST_LOOP_SKIP1:
	dec hl 
TEST_LOOP_SKIP:	
	ld de,CONV_OUT
	push de
	ld a,83h
	inc hl
	call CONV_BINTOHEX
	pop de
	pop hl
	push hl
	call PRN_STRING
TEST_LOOP_WAIT:
	ld b,20
TEST_LOOP_WAIT1:
;	halt
	djnz TEST_LOOP_WAIT1
	ld a,"*"
	ld hl,8006h
	cp (hl)
	jr nz,TEST_LOOP_WAIT
	pop hl
	jr TEST_LOOP
	
	
CONV_DATA:
	defs 05,080h
CONV_OUT:
	defb "        "




;	l - номер строки 0-63
;	h - номер столбца 0-127
;	call PIXEL_SET (зажигает пиксел по указанным координатам)

; ---- ТЕСТИРУЕМ ADC1115 - ПРИМИТИВНЫЙ ОСЦИЛЛОГРАФ
; - инициализация ADC
	call PCF_INIT
	call ADS_RESET
	call ADS_SETCONFIG
; - чтение данных из ADC в буфер
screen_loop:
	halt
	call CLEAR_SCREEN	; очистка экрана перед циклом отрисовки
	ld h,0			; первый слева столбец
pixel_loop:
	ld a,(ADS_EXCHANGE_BUFF); читаем старший байт
	srl a
	srl a			; делим на 4 (0-FF -> 0-40)
	ld l,a
	neg
	add 11100000b	; (E0h)
	and 00111111b	; (3Fh)
	ld l,a			; Загружаем результат расчета
	push hl
	call PIXEL_SET
	call ADS_READDATA
	pop hl
	inc h
	ld a,h
	cp 128
	jr z,screen_loop
	jr pixel_loop
; ---- КОНЕЦ - ПРИМИТИВНЫЙ ОСЦИЛЛОГРАФ

; ----Тестируем ADC1115
;	call PCF_INIT
;	call ADS_RESET
;	call ADS_SETCONFIG
;readloop:
;	call ADS_READDATA
;	ld hl,ADS_EXCHANGE_BUFF
;	ld de,TXT_BUFF
;
;	call BINtoHEX
;	call BINtoHEX
;	inc hl
;	call BINtoHEX
;	call BINtoHEX
;	inc hl
;	xor a
;	ld (hl),a
; вывод результата на дисплей в HEX формате
;	ld hl,0000h
;	set 7,l
;	ld de,TXT_BUFF
;	call PRN_STRING	
;	halt
;	halt
;	halt
;	halt
;	halt
;	jr readloop
;
;BINtoHEX:
;	ld a,(hl)
;	rld
;	and 0fh
;	cp 0ah
;	jr c,DECSYM
;	add 7h
;DECSYM:
;	add 30h
;	ld (de),a
;	inc de
;	ret
;
;TXT_BUFF:	defs 05h,00h	
; ----- КОНЕЦ ADC1115

; ----Тестируем OLED	
;	call PCF_INIT
;	call OLED_INIT
;	ld a,0b0h		; Адрес стартовой страницы B0 = PAGE0 (0-7)
;	call OLED_SEND_COMMAND
;	ld a,00h		; Адрес младшего полубайта начала по X (0-F)
;	call OLED_SEND_COMMAND
;	ld a,10h		; Адрес старшего полубайта начала по X (10-1F)
;	call OLED_SEND_COMMAND
;	ld hl,SYMBOL_DATA+0100h
;	ld bc,0400h
;	call OLED_SEND_STRING
;	ld a,0a7h		; Инверсия изображения
;flash_loop:
;	push af
;	call OLED_SEND_COMMAND
;	pop af
;	ld b,10
;wait_state:
;	halt
;	djnz wait_state
;	xor 1
;	jr flash_loop
;	
;	ld b,127
;sendloop:
;	push bc
;	ld a,b
;	call OLED_SEND_BYTE
;	pop bc
;	halt
;	djnz sendloop
;  ----


;	call PCF_ILLUMINATE
;	call PCF_DACWRITE

 ;call test
 ;jp KEY_INPUT
 
; ---- Тестируем RTC
; set time
;	push hl
;	call PCF_INIT
;	call RTC_TIMEWRITE
;	pop hl
; end of set time
;	push hl
;	call PCF_INIT
;	call RTC_TEMPREAD
;	call RTC_TEMPTOSTR
;	ld de,RTC_TMTXTBUFF
;	pop hl
;	push hl
;	call PRN_STRING
;	pop hl
;	inc l
;	
;RTC_UPDATE_LOOP:
;	push hl			; Сохранить текущую позицию курсора
;	call PCF_INIT		; Инициализируем PCF8584
;	call RTC_TIMEREAD	; Читаем время в буфер
;	call RTC_TMTOSTR	; Преобразуем полученные данные в текстовую строку формата:  'HH:MM:SS'00h
;	pop hl			; восстановить текущую позицию курсора
;	push hl
;	ld de,RTC_TMTXTBUFF	; Установить адрес строки времени
;	call PRN_STRING		; Вывести данные на дисплей:
;	pop hl
;	push hl
;	call RTC_ALARM1READ
;	call RTC_TMTOSTR	; Преобразуем полученные данные в текстовую строку формата:  'HH:MM:SS'00h
;	pop hl
;	push hl
;	inc l
;	ld de,RTC_TMTXTBUFF
;	call PRN_STRING
;	pop hl
;	ld b,25
;UPDATE_WAIT:
;	halt
;	djnz UPDATE_WAIT
;	jr RTC_UPDATE_LOOP
; -----
	pop hl
	jp KEY_INPUT		; Переходим на цикл опроса клавиатуры
; =============================
; Test memory Error print
; =============================
;
MERRMSG:	
	call DISP_INIT		; Инициализируем дисплей
	call CLEAR_SCREEN	; Очищаем дисплей
	call DISP_ON		; Включаем дисплей
	ld hl,0000h		; Загружаем координаты и режим вывода на дисплей в пару HL
	ld de,ERRSTR		; Загружаем адрес строки с сообщением об ошибке памяти
	call PRN_STRING		; Вызываем печать сообщения на дисплее
	halt			; Останавливаем работу.
	jr MERRMSG		; Если пришло прерывание,  повторям цикл вывода сообщения об ошибке
;
; -------------------------------
	include "display.asm"
	include "ps2_input.asm"
	include "key9_input.asm"
	include "memtotty.asm"
	include "font.asm"
	include "oled.asm"
;	include "pcf_illuminate.asm"
;	include "pcf_dac.asm
;	include "ds3231.asm"
	include "pcf8584.asm"
	include "ads1115.asm"
;	include "eeprom.asm"
	include "converse.asm"
; -------------------------------
; SYSTEM MESSAGES		'
; -------------------------------
INITSTR:
	defb "Test passed.",0dh,0ah,0ah,"System",0dh,0ah,"initialized.",0dh,0ah,">",00h
ERRSTR:
	defb "Memory testing",0dh,0ah,"error!",0dh,0ah,"System halted.",00h
end