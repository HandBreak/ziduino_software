; *=============================================================================*
; * Библиотека управления контроллером i2c PCF8584				*
; *										*
; * Доступные функции:								*
; *	PCF_INIT		- инициализация контроллера i2c PCF8584 	*
; *	PCF_REPEAT		- переход из передачи в приём данных		*
; *	PCF_SETINT		- установка вектора и разрешение прерываний	*
; *	PCF_GETINT		- чтение вектора прерываний			*
; *	PCF_MASTER_TX		- передача содержимого буфера к i2c устройству  *
; *	PCF_MASTER_RX		- приём данных от i2c устройства в буфер данных *
; *	PCF_SLAVE_RXTX		- приём / передача данных в ведомом режиме	*
; *										*
; * Используемые переменные:							*
; *	PCF_S0_REG		- адрес регистра буфера данных/ регистра сдвига:*
; *				  1111111011111010b (0xFEFAh)			*
; *	PCF_S1_REG		- адрес регистра управления/состояния:		*
; *				  1111111111111010b (0xFFFAh)			*
; *=============================================================================*
;
; Аппаратные адреса устройств i2c: (младший бит признак чтения/записи, bit:3,2,1 - 000, пользовательский адрес)
I2C_8574:	equ	040h	; PCF8574 8-bit I/O Expander hardware address
I2C_8574A:	equ	070h	; PCF8574A 8-bit I/O Expander hardware address
I2C_SSD1306:	equ	078h	; SSD1306 OLED Display driver hardware address 78h (or 7ah)
I2C_EEPROM:	equ	0a0h	; SDE2516 or another EEPROM hardware address
I2C_MCP4725:	equ	0c4h	; MCP4725  Digital to analog converter hardware address
I2C_ADS1115_1:	equ	090h	; ADS1115 4-channel Analog to digital converter hardware address ADDR->GND
I2C_ADS1115_2:	equ	092h	; ADS1115 4-channel Analog to digital converter hardware address ADDR->VCC
I2C_ADS1115_3:	equ	094h	; ADS1115 4-channel Analog to digital converter hardware address ADDR->SDA
I2C_ADS1115_4:	equ	096h	; ADS1115 4-channel Analog to digital converter hardware address ADDR->SCL
I2C_RTC:	equ	0d0h	; DS3231SN Real time clock hardware address 		(1101000x)
I2C_RTC_EEPROM:	equ	0aeh	; 24C32 on RTC module hardware address			(1010111x)
; Аппаратные адреса контроллера i2c:
PCF_S0_REG:	equ	0fefah 
PCF_S1_REG:	equ	0fffah 
; ------------------------------
;
; ==============================
; PCF8584 Init
; input:
;	none
; output:
;	none
; ------------------------------
PCF_INIT:
	ld bc,PCF_S1_REG
	ld a,80h
	out (c),a		; Загружаем 80h в S1 (Serial interface off)
	ld bc,PCF_S0_REG
	ld a,55h
	out (c),a		; Загружаем 55h в S0 (effective own address)
	ld bc,PCF_S1_REG
	ld a,0a0h		
	out (c),a		; Загружаем A0 в S1 (Следующий байт устанавливает частоту в S2)
	ld bc,PCF_S0_REG
	ld a,14h		; S2 = 10100 (6Mhz, 90khz)
	out (c),a		; устанавливаем частоты
	ld bc,PCF_S1_REG
	ld a,0c1h		; Включаем интерфейсы, устанавливаем I2C в ожидание, SDA и SDL в HIGH
	out (c),a		; переходим в режим чтения/записи в data-регистр S0 (if A8=0)
	ret			; Конец инициализации PCF8584
; ------------------------------
;
; ==============================
; PCF8584 Master Repeat
; input:
;	A - Адрес ведомого утройства
; output:
;	none
; ------------------------------
PCF_REPEAT:
	push af			; Сохраним адрес передатчика
	ld bc,PCF_S1_REG	; PCF8584 сконфигурирован как ведущий передатчик
	ld a,45h
	out (c),a		; Загружаем 45h в S1 (Repeat 'START condition' only)
	ld bc,PCF_S0_REG
	pop af			; Восстановим адрес передатчика
	set 0,a			; Установить R/W=1
	out (c),a		; Загружаем SLAVE в S0 (effective own address)
	ret			; Конец повторения START после передачи перед переходом в режим приёма
; ------------------------------
;
; ==============================
; PCF8584 Interrupt Vector Set
; input:
;	A - Разреш/запрет:FF/00
;	H - Старший байт адреса вектора прерываний
;	L - Адрес для SLAVE режима
; output:
;	none
; ------------------------------
PCF_SETINT:
	or a			; Проверяем флаг запрета / разрешения ENI
	ld bc,PCF_S1_REG
	ld a,80h
	out (c),a		; Загружаем 80h в S1 (Serial interface off)
	ld bc,PCF_S0_REG
	ld a,l
	out (c),a		; Загружаем адрес в S0 (effective own address)
	ld bc,PCF_S1_REG
	ld a,90h		
	out (c),a		; Загружаем 90h в S1 (Следующий байт устанавливает вектор в S3)
	ld bc,PCF_S0_REG
	ld a,h			; Загружаем старший байт вектора прерываний
	out (c),a		; Записываем вектор в S3
	ld bc,PCF_S1_REG
	ld a,0c1h		; Включаем интерфейсы, устанавливаем I2C в ожидание, SDA и SDL в HIGH
	jr z,PCF_DI		; Запретить прерывания? Если да, отправить в PCF как есть, иначе
	set 3,a			; Установить бит разрешения ENI
  PCF_DI:
	out (c),a		; Переходим в режим чтения/записи в data-регистр S0 (if A8=0)
	ret			; Конец установки вектора прерываний
; ------------------------------
;
; ==============================
; PCF8584 Get Interrupt Vector
; input:
;	none
; output:
;	A - Старший байт адреса вектора прерываний
; ------------------------------
PCF_GETINT:
	ld bc,PCF_S1_REG
	ld a,90h		
	out (c),a		; Загружаем 90h в S1 (Режим чтения/записи вектора из/в S3)
	ld bc,PCF_S0_REG
	in a,(c)		; Читаем вектор из S3
	ret			; Конец чтения вектора
; ------------------------------
;
; ==============================
; PCF8584 Master Transmitter Mode
; input:
;	HL - Адрес буфера данных
;	D  - Адрес устройства i2c 
;	E  - Длина передаваемой последовательности (max = ffh)
; output:
;	HL - Адрес следующего байта в буфера после передачи блока
; ------------------------------
PCF_MASTER_TX:
	ld bc,PCF_S1_REG
  PCF_TRANS_READ_LOOP:	
	in a,(c)		; Читаем байт из S1
	bit 0,a			; BB=0 ?
	jr z,PCF_TRANS_READ_LOOP; Шина занята ? (=0?)
	ld bc,PCF_S0_REG
	ld a,d			; Адрес устройства (например: A0h EEPROM WRITE)
	and 0feh		; Всегда bit0 (R/W)=0 (WRITE)
	out (c),a		; Загружаем в S0
	ld bc,PCF_S1_REG
	ld a,0c5h		; Команда START (код C5h)
	out (c),a		; Загружаем в S1
	ld d,00h		; Счетчик переданных байт
  PCF_TRANS_SEND_LOOP:
	ld bc,PCF_S1_REG	
	in a,(c)		; Читаем байт из S1 (Состояние передачи)
	bit 7,a			; Если bit7 (PIN)<>0, перечитываем состояние 
	jr nz,PCF_TRANS_SEND_LOOP
	bit 3,a			; Если bit3 (LRB)<>0, завершаем передачу
	jr nz,PCF_TRANS_SEND_END
	ld a,e			; В "A" длину отправляемой серии байт
	cp d			; Сверяем всё ли передано, завершаем передачу если ДА
	jr z,PCF_TRANS_SEND_END
	inc d			; Увеличиваем счетчик переданных данных
	ld bc,PCF_S0_REG
	ld a,(hl)		; Считываем байт для передачи из буфера
	inc hl			; Следующий байт буфера
	out (c),a		; Отправляем в i2c устройство
	jr PCF_TRANS_SEND_LOOP	; Повторяем цикл до конца передачи
  PCF_TRANS_SEND_END:
	ld a,0c3h		; В S1 отправляем команду STOP (код C3h)
	out (c),a
	ret			; Конец процедуры отправки данных
; ------------------------------
;
; ==============================
; PCF8584 Master Receiver mode
; input
;	HL - Адрес буфера данных
;	D  - Адрес устройства i2c
;	E  - Размер буфера для приёма (max = ffh)
; output:
;	HL - Адрес последнего байта в буфере
;	flags:
;	Z  - Чтение завершено успешно
;	NZ - Прервано из-за ошибки чтения
; ------------------------------
PCF_MASTER_RX:
	ld bc,PCF_S0_REG
	ld a,d			; Адрес устройства (например: A1h EEPROM READ)
	or 01h			; Всегда bit0 (R/W)=1 (READ)
	out (c),a		; Загружаем в S0
	ld bc,PCF_S1_REG
  PCF_RECEIVE_BUSY:
	in a,(c)		; Читаем регистр статуса S1
	bit 0,a			; Проверяем занята ли шина. 
	jr z,PCF_RECEIVE_BUSY	; BB = 0 ? пока "ДА" ожидаем освобождения, иначе передаём START
	ld a,0c5h
	out (c),a		; Отправляем команду START в S1 (код C5h)
	ld d,00h		; Счетчик принятых байт (обратный отсчет с 255 для dummy read)
	dec e			; Число циклов чтения = Количество читаемых байт - 1  (один байт будет прочтен в любом случае при завершении цикла)
  PCF_RECEIVE_LOOP:
	ld bc,PCF_S1_REG	; Выбираем регистр статуса S1
	in a,(c)
	bit 7,a			; Проверяем bit7 (PIN)
	jr nz,PCF_RECEIVE_LOOP	; Если PIN=1, продолжаем ожидать готовность
	bit 3,a			; LRB = 0?  (Ведомый отвечает ACK ?) Если да, то сравним счетчики, иначе завершим приём по ошибке
	jr nz,PCF_RECEIVE_ERROR
	ld a,d			; В "A" число передаваемых данных (количество переданных байт)
	cp e			; Сравним с заданным, при совпадении переходим к завершению передачи
	jr nz,PCF_RECEIVE_CONT
	ld a,40h		; Передаём в S1 (PCF_S1_REG) 40h (Set ACK bit S1 to 0 for negative acknowledgement) 
	out (c),a
PCF_RECEIVE_CONT:
	ld a,d
	or a			; Первый цикл чтения ?
	ld bc,PCF_S0_REG	; Иначе выполним
	ex af,af'
	in a,(c)
	ex af,af'
	jr z,PCF_RECEIVE_DUMMY
	ex af,af'
	ld (hl),a		; Сохранем считанный байт в буфер
	inc hl			; Выбираем адрес следующей ячейки буфера	
PCF_RECEIVE_DUMMY:
	inc d
	ld a,d
	dec a
	cp e
  	jr nz,PCF_RECEIVE_LOOP	; Перейдём к новому циклу чтения
	ld bc,PCF_S1_REG
  PCF_RECEIVE_COMPLETE_LOOP:
	in a,(c)		; Читаем регистр статуса S1
	bit 7,a			; Проверяем bit7 (PIN) = 0 ? если не 0, ждём  нуля!  Иначе переходим к завершению
	jr nz,PCF_RECEIVE_COMPLETE_LOOP
  PCF_RECEIVE_ERROR:
	ld a,0c3h		; Отправляем команду STOP
	out (c),a		; C3h -> PCF_S1_REG
	ld bc,PCF_S0_REG	; Выбираем регистр S0
	in a,(c)		; Читаем последний байт из буфера данных S0 (ранее загруженный туда чтением из i2c)
	ld (hl),a		; Записываем полученные данные в буфер
	ret			; Завершаем процедуру приёма данных!
; ------------------------------
;
; ==============================
; PCF8584 Slave RX/TX Mode
; input
;	HL - Адрес буфера данных
;	DE - Размер буфера
; output:
;	DE - Размер данных
;	HL - Свободных байт
; ------------------------------
PCF_SLAVE_RXTX:
	push de			; Сохранить размер буфера
	ld bc,PCF_S1_REG
  PCF_SLAVE_AAS_LOOP:
	in a,(c)
	bit 2,a			; AAS=1?, повторить чтение пока <>1
	jr z,PCF_SLAVE_AAS_LOOP
  PCF_SLAVE_PIN_LOOP:
	in a,(c)
	bit 7,a			; PIN=0?, повторить чтение, пока не равен
	jr nz,PCF_SLAVE_PIN_LOOP
	ld bc,PCF_S0_REG
	in a,(c)
	bit 0,a			; LSB (R/!W)=0?, если да - режим приема, мначе передача
	jr z,PCF_SLAVE_RX

PCF_SLAVE_TX:  
	ld bc,PCF_S1_REG
  PCF_SLAVE_TX_LOOP:
	in a,(c)
	bit 7,a			; PIN=0?, повторить чтение пока <>0
	jr nz,PCF_SLAVE_TX_LOOP
	ld bc,PCF_S0_REG
	bit 3,a			; LRB=1? (ACK received?), если да - последний байт
	ld a,(hl)		; Считать содердимое буфера
	out (c),a		; Отправить данные в S0 для передачи
	jr nz,PCF_SLAVE_TX_END
	inc hl			; Выбрать следующий адрес буфера
	dec de			; Уменьшить счетчик свободного места в буфере
	ld a,d
	or e			; Буфер заполнен ?
	jr nz,PCF_SLAVE_TX	; Перейти к передаче следующего байта
  PCF_SLAVE_TX_END:
	pop hl			; восстановить размер буфера в HL !
	ccf			; сбросить флаг CY перед вычитанием
	sbc hl,de		; РАЗМЕР-ОСТАТОК=ПЕРЕДАНО
	ex de,hl		; 
	ret			; Конец передачи
	
PCF_SLAVE_RX:
	ld bc,PCF_S1_REG
  PCF_SLAVE_RX_LOOP:
	in a,(c)
	bit 7,a			; PIN=0?, повторить чтение пока <>0
	jr nz,PCF_SLAVE_RX_LOOP
	ld bc,PCF_S0_REG
	bit 5,a			; STS=1?, если да - читать последний байт, иначе повторить
	in a,(c)		; Получить байт данных в S0
	ld (hl),a		; Сохранить данные в текущий адрес буфера
	jr nz,PCF_SLAVE_RX_END
	inc hl			; Выбрать следующий адрес буфера
	dec de			; Уменьшить счетчик свободного места в буфере
	ld a,d
	or e			; Буфер заполнен ?
	jr nz,PCF_SLAVE_RX	; Если нет, перейти к передаче следующего байта
  PCF_SLAVE_RX_END:
	pop hl			; восстановить размер буфера в HL !
	ccf			; сбросить флаг CY перед вычитанием
	sbc hl,de		; РАЗМЕР-ОСТАТОК=ПЕРЕДАНО
	ex de,hl		; 
	ret			; Конец приёма
; ------------------------------
;
; ==============================
; PCF8584 Master Scan mode
; input
;	D  - Адрес устройства i2c
; output:
;	flags:
;	Z & A=00  - Шина занята
;	Z & A=FF  - Нет ответа
;	NZ - Найдено устройство
; ------------------------------
PCF_MASTER_SCAN:
	ld bc,PCF_S1_REG
	xor a			; Сбросить счетчик циклов ожидания шины
  PCF_BUSY_TEST:
	in e,(c)		; Читаем регистр статуса S1
	bit 0,e			; Проверяем занята ли шина. 
	jr nz,PCF_SEND_SLAVE	; BB = 0 ? если "НЕТ" передаём START, иначе жем освобождения
	inc a			; Увеличить счетчик ожидания
	jr nz,PCF_BUSY_TEST	; Повторять чтение 256 циклов
	ret 
  PCF_SEND_SLAVE:
  	ld bc,PCF_S0_REG
	ld a,d			; Адрес устройства (например: A1h EEPROM READ)
	and 0feh		; Всегда bit0 (R/W)=0 (WRITE)
	out (c),a		; Загружаем в S0
	ld bc,PCF_S1_REG
	ld a,0c5h
	out (c),a		; Отправляем команду START в S1 (код C5h)
	ld e,0			; обнулим счетчик циклов ожидания
  PCF_WAIT_PIN:
	in a,(c)		; Читаем статус из S1
	bit 7,a			; PIN=0?, повторить пока <>0
	jr z,PCF_ENDWAIT_PIN
	inc e			; Увеличить счетчик ожидания
	jr nz,PCF_WAIT_PIN	; Ждём ответа
	ld a,0ffh		; Код ошибки (нет ответа + Z)
	ret
  PCF_ENDWAIT_PIN:
	push af			; Сохраняем результат проверки
	ld a,0c3h		; Отправляем команду STOP
	out (c),a		; C3h -> PCF_S1_REG
	pop af			; Восстанавливаем результат проверки
	cpl			; Инвертировать A,  теперь 
	bit 3,a			; Проверяем bit3 (LRB=1? (ACK received?), )
	ret nz			; NZ - получен ответ, Z - устройство не ответило
	ld a,0ffh		; Код ошибки (нет ответа + Z)
	ret
; ------------------------------	
;
; ==============================
; PCF8584 Acknowledge Polling Flow
; input
;	D  - Адрес устройства i2c
; output:
;	none
; ------------------------------	
PCF_EEPROM_WAITWR:
	ld bc,PCF_S1_REG
  PCF_EEPROM_WWR_LOOP:	
	in a,(c)		; Читаем байт из S1
	bit 0,a			; BB=0 ?
	jr z,PCF_EEPROM_WWR_LOOP; Шина занята ? (=0?)
	ld bc,PCF_S0_REG
	ld a,d			; Адрес устройства (например: A0h EEPROM WRITE)
	and 0feh		; Всегда bit0 (R/W)=0 (WRITE)
	out (c),a		; Загружаем в S0
	ld bc,PCF_S1_REG
  PCF_EEPROM_ACK_LOOP2:
	ld a,0c5h		; Команда START (код C5h)
	out (c),a		; Загружаем в S1
  PCF_EEPROM_ACK_LOOP1:
	in a,(c)		; Читаем байт из S1 (Состояние передачи)
	bit 7,a			; Если bit7 (PIN)<>0, перечитываем состояние 
	jr nz,PCF_EEPROM_ACK_LOOP1
	bit 3,a			; Если bit3 (LRB)<>0, (Slave ACK=0 ?) повторяем команду СТАРТ
	jr nz,PCF_EEPROM_ACK_LOOP2
	ld a,0c3h		; Отправляем команду STOP
	out (c),a		; C3h -> PCF_S1_REG
	ret			; Как только ACK=0 (Запись закончена), выйти из цикла ожидания