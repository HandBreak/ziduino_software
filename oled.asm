; *=============================================================================*
; * Библиотека управления i2c OLED дисплеем на контроллере SSD1306		*
; *										*
; * Доступные функции:								*
; *										*
; * Используемые переменные:							*
; *=============================================================================*
;
SSD1306_DATA:	equ	11000000b	; Co=1, D=on  (0xC0 - следом идет один байт данных)
SSD1306_CMD:	equ	10000000b	; Co=1, D=off (0x80 - следом идёт один байт команды. Вставляется перед каждой командой)
SSD1306_MEM:	equ	01000000b	; Co=0, D=on  (0x40 - следом идет множество байт данных в видеопамять)
;
; Промежуточный буфер для формирования отправляемых команд
OLED_WRITE_BUFF:
	defs 0x81,0		; буфер размером 129 байт заполненных нулями
OLED_INT_STRING:
	defb 0x80,0xa8,0x80,0x3f,0x80,0xd3,0x80,0x00,0x80,0x40,0x80,0xA1,0x80,0xC8,0x80,0xDA,0x80,0x12,0x80,0x81,0x80,0xFF,0x80,0xA4,0x80,0xA6,0x80,0xD5,0x80,0x80,0x80,0x8D,0x80,0x14,0x80,0x20,0x80,0xA0,0x80,0xAF
;	     MUX Ratio,Ratio=3Fh,DspOffset,value=00h,DspStLine,SegmRemap,StScanDir,PinsHwCfg,Pins-A4=1,StContrst,value=FFh,EntDispON,StNormDsp,StDispClk,value=def,dcdcONOFF,value= ON,SetAdrMod,=HorAdrMd,SetDispON
; ------------------------------
;
; ==============================
; OLED INIT
; Строка полной инициализации и
; включения дисплея (для тести-
; рования
; input:
;	none
; output:
;	none
; ------------------------------
OLED_INIT:
	ld e,40			; Количество отправляемых байт в серии
	ld d,I2C_SSD1306	; Адрес контроллера SSD1306
	ld hl,OLED_INT_STRING
	call PCF_MASTER_TX	; пишем в устройство
	ret			; Выход из процедуры записи
; ------------------------------
;
; ==============================
; OLED Send command to SSD1306
; input:
;	A - Command byte
; output:
;	none
; ------------------------------
OLED_SEND_COMMAND:
	ld e,02h		; Количество отправляемых байт в серии
	ld d,I2C_SSD1306	; Адрес контроллера SSD1306
	ld hl,OLED_WRITE_BUFF+1	; Адрес буфера с данными для записи
	ld (hl),a		; Сохраняем байт данных
	dec hl			; Выбираем адрес ячейки управляющей команды
	ld (hl),SSD1306_CMD	; Сохраняем управляющую команду - передача управляющего слова
	call PCF_MASTER_TX	; пишем в устройство
	ret			; Выход из процедуры записи
; ------------------------------
;
; ==============================
; OLED Send one data byte to SSD1306
; input:
;	A - data byte
; output:
;	none
; ------------------------------
OLED_SEND_BYTE:
	ld e,02h		; Количество отправляемых байт в серии
	ld d,I2C_SSD1306	; Адрес контроллера SSD1306
	ld hl,OLED_WRITE_BUFF+1	; Адрес буфера с данными для записи
	ld (hl),a		; Сохраняем байт данных
	dec hl			; Выбираем адрес ячейки управляющей команды
	ld (hl),SSD1306_DATA	; Сохраняем управляющую команду - передача байта данных
	call PCF_MASTER_TX	; пишем в устройство
	ret			; Выход из процедуры записи
; ------------------------------
;
; ==============================
; OLED Send data string to SSD1306
; input:
;	hl - data buffer address
;	bc - lenght buffer
; output:
;	none
; ------------------------------
OLED_SEND_STRING:
	ld de,OLED_WRITE_BUFF+1	; адрес буфера со смещением на 1 для вставки управляющей команды
	ld a,80h		; Максимальный размер передаваемого блока данных (128 байт - одна строка)
  OLED_SSTING_NXBYTE:
	ex af,af'		; сохранить число требующих передачи байт
	ld a,c			
	or b			; BC = 0 ?
	jr z,OLED_SSTING_ENDDATA; Если конец данных, перейти к выводу на дисплей
	ldi			; переместить 1 байт из (HL) в (DE) и уменьшить BC
	ex af,af'		; Вернуться к счетчику байт в блоке
	dec a			; уменьшить счетчик
	jr nz,OLED_SSTING_NXBYTE; пока не равен нулю повторить цикл
	ex af,af'		; иначе переключиться на альтернативный А, чтобы затем вернуться к счетчику
  OLED_SSTING_ENDDATA:
	ex af,af'		; вернуться к счетчику в регистре A
	ld e,a			; Сохранить результат в E
	ld a,81h		; Размер буфера с учетом байта управления
	sub e			; Количество отправляемых байт в серии (128 байт данных + 1 упр.байт)
	cp 1			; Были данные для отправки ? Если = 1, то нет
	ret z			; Закончить цикл, если для передачи больше нет данных (81-80 - только CONTROL)
	ld e,a			; e <-длина буфера отправки
	push hl			; сохранить адес следующего блока данных
	push bc			; сохранить оставшуюся длину буфера данных
	ld d,I2C_SSD1306	; Адрес контроллера SSD1306
	ld hl,OLED_WRITE_BUFF	; Адрес буфера с данными для записи
	ld (hl),SSD1306_MEM	; Сохраняем управляющую команду - передача строки данных
	call PCF_MASTER_TX	; пишем в устройство
	pop bc
	pop hl
	jr OLED_SEND_STRING	; выполнять весь цикл заново
; ------------------------------

