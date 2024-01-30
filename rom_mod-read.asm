; *=============================================================================*
; * Пример использования библиотеки PCF8584 для управления гирляндой из 8-ми	*
; * светодиодов, подключенных  к расширителю портов ввода-вывода PCF8574A	*
; * ============================================================================*
;
;
	org	0bfe5h 	;(c000 - 27 байт заголовка)
;       ================================================= Заголовок ==========================================
;	     преамбула     | Назв.16 байт     |конц|Смещение |Page|Адр.размщ|Длн.блока|КОДXXXXXX|маркер нач...
	defb 0x55,0xAA,0xAA,"EEPROM Read blk ",0x00,0x00,0x00,0x00,0x00,0xC0,0x20,0x00
;	======================================================================================================
;	- Смещение: 	Указывается 00, если код идёт сразу после заголовка (при запуске из ROM), либо абсолютный адрес, если запуск
;         		осуществляется из EEPROM (при этом предварительно все заголовки копируются в буфер)
;	- Page:		Номер страницы RAM в которую должен быть загружен код. По-умолчаниюю 00h (возможно 40h,80h,c0h,00h)
;	- Адрес размещ: Адрес с которого должен быть размещён и запущен указанный код. По-умолчанию c000h
;	- Длина блока:	Размер копируемого кода. Количество байт кода, в пределах 65635

; ==============================
;
; input:
;	none
; output:
;	none
; ------------------------------
EEPROM_READ:
	ld hl,0d000h
	push hl
	ld de,0000h
	ld bc,0100h
	push bc
	ld a,(ix+menu_eepromid)	
	call I2C_EEPROM_RDDATA	
	pop de
	pop hl
	call FT_BLOCKOUT
	ret