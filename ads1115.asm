; *=============================================================================*
; * Библиотека взаимодействия с i2c ADС преобразователем ADS1115		*
; *										*
; * Доступные функции:								*
; *										*
; * Используемые переменные:							*
; *=============================================================================*
;
; Команда сброса
ADS_RESET_CMD:	equ 	00000110b	;(06h)
; Указатели регистров
ADS_CONV_REG:	equ	00000000b	;(00h)  16-bit MSB,LSB,RO (D15-D0)
ADS_CONF_REG:	equ	00000001b	;(01h)	16-bit,MSB,LSB,RW (OS,MUX2,MUX1,MUX0,PGA2,PGA1,PGA0,MODE,DR2,DR1,DR0,COMP_MODE,COMP_POL,COMP_LAT,COMP_QUE1,COMP_QUE0) default = 8583h
;Bit [15] OS: Operational status/single-shot conversion start
;	This bit determines the operational status of the device.
;	This bit can only be written when in power-down mode.
;	For a write status:
;	0 : No effect
;	1 : Begin a single conversion (when in power-down mode)
;	For a read status:
;	0 : Device is currently performing a conversion
;	1 : Device is not currently performing a conversion
;Bits [14:12] MUX[2:0]: Конфигурация входов (ADS1115 only)
;	These bits configure the input multiplexer. They serve no function on the ADS1113/4.
;	000 : AINP = AIN0 and AINN = AIN1 (default)	100 : AINP = AIN0 and AINN = GND
;	001 : AINP = AIN0 and AINN = AIN3 		101 : AINP = AIN1 and AINN = GND
;	010 : AINP = AIN1 and AINN = AIN3 		110 : AINP = AIN2 and AINN = GND
;	011 : AINP = AIN2 and AINN = AIN3 		111 : AINP = AIN3 and AINN = GND
;Bits [11:9] PGA[2:0]: Programmable gain amplifier configuration (ADS1114 and ADS1115 only)
;	These bits configure the programmable gain amplifier. They serve no function on the ADS1113.
;	000 : FS = ±6.144V(1) 100 : FS = ±0.512V
;	001 : FS = ±4.096V(1) 101 : FS = ±0.256V
;	010 : FS = ±2.048V (default) 110 : FS = ±0.256V
;	011 : FS = ±1.024V 111 : FS = ±0.256V
;Bit [8] MODE: Device operating mode
;	This bit controls the current operational mode of the ADS1113/4/5.
;	0 : Continuous conversion mode
;	1 : Power-down single-shot mode (default)
;Bits [7:5] DR[2:0]: Data rate
;	These bits control the data rate setting.
;	000 : 8SPS  100 : 128SPS (default)
;	001 : 16SPS 101 : 250SPS
;	010 : 32SPS 110 : 475SPS
;	011 : 64SPS 111 : 860SPS
;Bit [4] COMP_MODE: Comparator mode (ADS1114 and ADS1115 only)
;	This bit controls the comparator mode of operation. It changes whether the comparator is implemented as a
;	traditional comparator (COMP_MODE = '0') or as a window comparator (COMP_MODE = '1'). It serves no
;	function on the ADS1113.
;	0 : Traditional comparator with hysteresis (default)
;	1 : Window comparator
;Bit [3] COMP_POL: Comparator polarity (ADS1114 and ADS1115 only)
;	This bit controls the polarity of the ALERT/RDY pin. When COMP_POL = '0' the comparator output is active
;	low. When COMP_POL='1' the ALERT/RDY pin is active high. It serves no function on the ADS1113.
;	0 : Active low (default)
;	1 : Active high
;Bit [2] COMP_LAT: Latching comparator (ADS1114 and ADS1115 only)
;	This bit controls whether the ALERT/RDY pin latches once asserted or clears once conversions are within the
;	margin of the upper and lower threshold values. When COMP_LAT = '0', the ALERT/RDY pin does not latch
;	when asserted. When COMP_LAT = '1', the asserted ALERT/RDY pin remains latched until conversion data
;	are read by the master or an appropriate SMBus alert response is sent by the master, the device responds with
;	its address, and it is the lowest address currently asserting the ALERT/RDY bus line. This bit serves no
;	function on the ADS1113.
;	0 : Non-latching comparator (default)
;	1 : Latching comparator
;Bits [1:0] COMP_QUE: Comparator queue and disable (ADS1114 and ADS1115 only)
;	These bits perform two functions. When set to '11', they disable the comparator function and put the
;	ALERT/RDY pin into a high state. When set to any other value, they control the number of successive
;	conversions exceeding the upper or lower thresholds required before asserting the ALERT/RDY pin. They
;	serve no function on the ADS1113.
;	00 : Assert after one conversion
;	01 : Assert after two conversions
;	10 : Assert after four conversions
;	11 : Disable comparator (default)
;
; SET TEST CONFIGURATION 
; 15(1) - Begin single conversion
; 14(1) \
; 13(0) - Analog Input = AIN0 + AINn=GND
; 12(0) /
; 11(0) \
; 10(1) - Set +/- 2.048v gain amplifier
;  9(0) /
;  8(0) - Режим постоянного преобразования
;  7(1) \
;  6(1) - 860SPS Частота преобразования 860 измерений / секунду
;  5(1) /
;  4(0) - Стандартный компаратор с гистирезисом (1 - оконный режим)
;  3(0) - Уровень активного сигнала на выходе компаратора
;  2(0) - Не использовать триггер на компараторе
;  1(1) \
;  0(1) - Компаратор выключен
ADS_CONFIG_HI:	equ	11000100b	;(C4h)
ADS_CONFIG_LO:	equ	11100011b	;(E3h)
;
ADS_HITHR_REG:	equ	00000011b	;(03h)
ADS_LOTHR_REG:	equ	00000010b	;(02h)
;
; Промежуточный буфер для формирования отправляемых команд
ADS_EXCHANGE_BUFF:
	defs 03,00h		; буфер размером 3 байт для записи результата преобразования и команд управления
;	     MSB,LSB
;	     RGP,POINTER
; ------------------------------
;
; ==============================
; ADS1115  Reset command
; Set registers to default
; input:
;	none
; output:
;	none
; ------------------------------
ADS_RESET:
	ld e,01h		; Количество отправляемых байт в серии
	ld d,I2C_ADS1115_1	; Адрес контроллера ADS1115 (Вход ADDRESS подключен к GND)
	ld hl,ADS_EXCHANGE_BUFF	; Адрес буфера для отправки данных
	ld (hl),ADS_RESET_CMD	; Команда сброса регистров ADS
	call PCF_MASTER_TX	; пишем в устройство
	ret			; Выход из процедуры записи
; ------------------------------
;
; ==============================
; ADS1115  Set user configuration
; Set registers to test mode
; input:
;	none
; output:
;	none
; ------------------------------
ADS_SETCONFIG:
	ld e,03h		; Количество отправляемых байт в серии
	ld d,I2C_ADS1115_1	; Адрес контроллера ADS1115 (Вход ADDRESS подключен к GND)
	ld hl,ADS_EXCHANGE_BUFF	; Адрес буфера для отправки данных
	ld (hl),ADS_CONF_REG	; Команда выбора конфигурационного регистра
	push hl			; Сохраним адрес начала буфера
	inc hl
	ld (hl),ADS_CONFIG_HI	; Загружаем старший байт конфигурационного регистра
	inc hl
	ld (hl),ADS_CONFIG_LO	; Загружаем младший байт конфигурационного регистра
	pop hl
	call PCF_MASTER_TX	; пишем в устройство
	ret			; Выход из процедуры записи
; ------------------------------
;
; ==============================
; ADS1115  Read AD 
; conversion data
; input:
;	none
; output:
;	none
; ------------------------------
ADS_READDATA:
	ld e,01h		; Количество отправляемых байт в серии
	ld d,I2C_ADS1115_1	; Адрес контроллера ADS1115 (Вход ADDRESS подключен к GND)
	ld hl,ADS_EXCHANGE_BUFF	; Адрес буфера для отправки данных
	ld (hl),ADS_CONV_REG	; Команда выбора регистра преобразования DC
	push hl			; Сохраним адрес начала буфера
	call PCF_MASTER_TX	; пишем в устройство
	pop hl
	ld e,02h		; Количество считываемых байт в серии
	ld d,I2C_ADS1115_1	; Адрес контроллера ADS1115 (Вход ADDRESS подключен к GND)
	call PCF_MASTER_RX	; Читаем из устройства
	ret			; Выход из процедуры записи
; ------------------------------
