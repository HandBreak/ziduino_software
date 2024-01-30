; *=============================================================================*
; *	Модуль программатора EEPROM						*
; *	Осуществляет запись микропрограмм в EEPROM				*
; *	Сам модуль размещается в ROM						*
; *=============================================================================*
;
	org	02fe5h 	;(3000 - 27 байт заголовка)
;       ================================================= Заголовок ==========================================
;	     преамбула     | Назв.16 байт     |конц|Смещение |Page|Адр.размщ|Длн.блока|КОДXXXXXX|маркер нач...
	defb 0x55,0xAA,0xAA,"Filemanager     ",0x00,0x00,0x00,0x00,0x00,0x30,0x89,0x07
;	======================================================================================================
;	- Смещение: 	Указывается 00, если код идёт сразу после заголовка (при запуске из ROM), либо абсолютный адрес, если запуск
;         		осуществляется из EEPROM (при этом предварительно все заголовки копируются в буфер)
;	- Page:		Номер страницы RAM в которую должен быть загружен код. По-умолчаниюю 00h (возможно 40h,80h,c0h,00h)
;	- Адрес размещ: Адрес с которого должен быть размещён и запущен указанный код. По-умолчанию c000h
;	- Длина блока:	Размер копируемого кода. Количество байт кода, в пределах 65535
;
; ==============================
; EEPROM Filemanager
; input
;	none
; output:
;	none
; ------------------------------
FM_INIT:
	ld a,(ix+menu_eepromid)	; Получить ID EEPROM
  FM_MAIN:	
	ld (fm_cur_eeprom),a	; Сохранить ID в локальной переменной
	call FM_INIT_SCR
	ld de,FM_MSG9		; Сообщить о начале сканирования пространства
	rst prn_wascr
	ld hl,0000h		; Адрес начала поиска места в EEPROM
	ld a,(fm_cur_eeprom)	; Указать адрес EEPROM
	ld c,a
	ld b,0			; Счетчик найденных записей
  FM_SCAN_EEPROM:
	ld d,h
	ld e,l			; Перед поиском сохраняем в DE предыдущее значение HL
	push de			; Сохраняем предыдущий адрес
	push bc			; Сохранить счетчик и адрес i2c
	call FIND_EEPROM_CONT	; Начинаем поиск преамбулы
	pop bc			; Восстановить счетчик и адрес i2c
	pop de			; Восстанавливем предыдущий адрес
	cp 55h			; Поиск завершен полностью ?
	jr z,FM_SCAN_END	; Если да, то перейти к... иначе завершить сканирование (
	inc b			; Увеличить счетчик на 1 найденную запись
	jr nz,FM_SCAN_EEPROM	; Повторять поиск пока не произойдёт переполнения (256 записей) или прежде выхода по окончании поиска  !!!! Исправлено Z->NZ
	ld de,FM_MSG8		; EEPROM переполнено записями
	rst prn_wascr
	ld b,0ffh		; Установить B=255 (максимум файлов)
	jr FM_SCAN_END
; ------------------------------
FM_INIT_SCR:
	call CLEAR_SCREEN	; Очистить экран
	ld hl,0000h		; Позиция вывода XY=0,0
	call PRINT_SETPOS	; Установить позицию и атрибуты
	ld de,FM_MSG1		; Название программы
	rst prn_wascr		; Сообщить название
	ld a,(fm_cur_eeprom)	; Прочитать ID
	or a
	jr z,FM_NOI2C		; Если 0, не найдено I2C устройств
	ld hl,FM_VAR1		; DE адрес буфера источника
	ld (hl),a		; Запишим преобразумое число в буфер
	ld de,FM_MSG4		; Адрес буфера для сохранения ASCII числа
	ld a,2			; Число ASCII знаков
	push de
	call CONV_BINTOHEX	; Преобразровать
	ld de,FM_MSG3		; Сообщение о активном устройстве
	rst prn_wascr
	pop de			; начало буфера с ASCII-> DE 
	rst prn_wascr		; Отобразить результат
	ret			; Выход из формирования шапки
; ------------------------------	
  FM_NOI2C:
	ld de,FM_MSG2
	rst prn_wascr
  FM_NOI2C_KEYWAIT:
	pop hl			; Коррекция стека для возврата в меню программ
	jp FM_WAIT_ANYKEY	; Ждём нажатия любой клавиши и выходим в основное меню
; ------------------------------
  FM_SCAN_END:
	ld hl,FM_VADR2
	ld (hl),e		; Сохраним младший байт начала последней записи
	inc hl
	ld (hl),d		; Сохраним старший байт начала последней найденной записи.
	ld hl,FM_VFILES
	ld (hl),b
	push de			; DE = Адрес начала текстового заголовка последнего найденного файла.  (0000, если пустая EEPROM)
	ld de,FM_MSG10+8	; Смещение на область строки после 'Files'
	xor a
	call CONV_BIN8TODEC	; Преобразовать число файлов в DEC формат
	ld de,FM_MSG10
	rst prn_wascr
	pop de			; Восстановить адрес начала свободной области
	ld a,d
	or e			; DE=0? (чистая флэш). Если нет, то DE=адресу названия последнего файла. Для вычисления начала свободного места потребуется получить добавить часть заголовка (24 байта) + размер файла
	jr z,FM_FREE_ST		; Сохранить значение 0000 в переменной FM_VADR1 (чистая EEPROM), иначе вычислить начало свободной области
	ld hl,22		; Смещение до байта с длиной файла
	add hl,de		; HL=Абсолютный адрес EEPROM, начиная с которого хранится информация о размере блока данных -> требуется считать для вычисления смещения
	ex de,hl		; Адрес поместить в DE
	ld bc,2			; размер блока данных для чтения (2байта)
	push de			; сохранить адрес начала записи о размере блока (+2 - начало самого блока данных)
	push bc
	ld hl,FM_VADR1		; адрес буфера в который произвести чтение размера программы (первый байт старший, второй младший!!!)
	ld a,(fm_cur_eeprom)	; Указать адрес EEPROM
	call I2C_EEPROM_RDDATA	; читать в буфер два байта,
	pop bc
	dec hl			; HL-следующей свободной ячейки буфера данных
	ld d,(hl)		; Считать старший байт размера из буфера
	dec hl
	ld e,(hl)		; Считать младший байт размера из буфера
	pop hl			; восстановить адрес размера блока
	add hl,bc		; HL - адрес начала блока данных
	add hl,de		; HL - адрес первого свободного байта в EEPROM
	ex de,hl		; Результат вычислений поместить в DE для последующей перезаписи в FM_VADR1
  FM_FREE_ST:
	ld hl,FM_VADR1		; DE адрес буфера источника
	ld (hl),d		; Запишем старший байт в буфер
	inc hl
	ld (hl),e		; Запишем младший байт в буфер
	dec hl
	ld de,FM_MSG4		; Адрес буфера для сохранения ASCII числа
	ld a,4			; Число ASCII знаков
	push de
	call CONV_BINTOHEX	; Преобразровать
	ld de,FM_MSG7		; Сообщение о активном устройстве
	rst prn_wascr
	pop de			; начало буфера с ASCII-> DE 
	rst prn_wascr		; Отобразить результат
	ld de,FM_MSG5		; Изменить адрес ?
	rst prn_wascr
; ------------------------------
  FM_WAIT_KEY:
	halt			; Ждём прерывания
	call PS2CODE_CONVERT	; Проверка буфера PS/2 клавиатуры
	ld a,(ix+scan_code)
	ld (ix+scan_code),00h	; Очистим буфер ввода
	cp "y"			; Нажата клавиша 'y' ?
	jr z,FM_CHANGE_ADR	; Вызвать подпрограмму ввода нового адреса
	cp "n"			; Нажата 'n'?
	jr nz,FM_WAIT_KEY	; Продолжаем ожидать нажатие клавиш, иначе продолжить программу
  FM_SELECT:
	ld hl,0002h		; Позиция вывода XY=0,0
	call PRINT_SETPOS	; Установить позицию и атрибуты
	call CLR_CURSTRING	; Очистить текущую строку
	ld de,FM_MSG11
	rst prn_wascr		; Отобразить меню выбора действий
	inc de			; Перейти к началу следующей записи
	ld a,(FM_VFILES)
	cp 0ffh
	jr nz,FM_SELECT_WAAPND	; Если файлов<>255, в DE адрес меню, начиная с пункта 1
	call CLR_CURSTRING	; Очистим следующую строку от 'Files'
	ld de,FM_MSG11_2	; Меню выбора, начиная со 2-го пункта
	inc (ix+prn_y)		; Оставим пустую строку там где должен быть первый пункт
  FM_SELECT_WAAPND:
	rst prn_wascr		; Отобразить продолжение меню выбора
	ld (ix+scan_code),00h	; Очистим буфер ввода  
  FM_WAIT_SELECT:
	halt			; Ждём прерывания
	call PS2CODE_CONVERT	; Проверка буфера PS/2 клавиатуры
	ld a,(ix+scan_code)	
	ld (ix+scan_code),00h	; Очистим буфер ввода
	or a
	jr z,FM_WAIT_SELECT
	cp "1"			; Нажата '1'?
	call z,FM_APPEND	; Вызвать подпрограмму добавления записи
	cp "2"			; Нажата '2'?
	call z,FM_OVERWRITE	; Вызвать подпрограмму перезаписи последнего файла
	cp "3"			; Нажата '3'?
	call z,FM_ERASEALL	; Вызвать подпрограмму очистки EEPROM
	cp "4"			; Нажата '4' ?
	call z,FM_SETAUTORUN	; Вызвать подпрограмму установки автозапуска
	cp 1bh			; Нажата 'ESC' ?
	ret z			; Выйти в меню выбора программ
	or a
	call nz,PS2_BUF_OVERFLOW; Воспроизвести звук ошибки, если A<>0 (ошибка выполнения подпрограммы или нет соответствующей подпрограммы)
	jr FM_SELECT		; Полный цикл, с перерисовкой меню (на случай возврата)
; ------------------------------
FM_CHANGE_ADR:
	ld hl,0006			; Установить позицию вывода сообщения X=0,Y=6 (необходимо при повторном запросе ввода после отмены)
	call PRINT_SETPOS
	ld de,FM_MSG6
	rst prn_wascr
  FM_CHANGE_ADR_ERR:
	ld de,FM_MSG12		; Адрес буфера с пробелами для удаления старых данных ввода
	ld l,(ix+prn_y)		; Считать позицию
	ld h,(ix+prn_x)		; И режим ввода
	call PRN_STRING		; Отобразить в области ввода актуальное значение переменной
	ld (ix+input_len),02h	; Ввод двух символов
	call FM_INPTOBUFF
	cp 1bh			; ESC ?
	jr nz,FM_CHANGE_CONT
	call CLR_CURSTRING	; Очистить строку ввода адреса
	jp FM_WAIT_KEY		; Выйти в запрос смены адреса
  FM_CHANGE_CONT:
	or a
	jr z,FM_CHANGE_ADR_ERR	; Пустая строка ? - повтор ввода
	ld de,FM_VAR1		; Сюда будет помещён результат преобразования
	push de			; Сохраним адрес
	call CONV_HEXTOBIN	; По указанному адресу будет сохран
	pop de
	jr c,FM_CHANGE_ADR_ERR	; Повторный ввод из-за ошибки данных
	ld a,(de)		; Получить число из буфера
	jp FM_MAIN		; И начать всё с начала 
; ------------------------------
FM_GETPARAM:
	ld hl,0003h		; Позиция вывода XY=0,3
	call PRINT_SETPOS	; Установить позицию и атрибуты
	call CLR_UNDERSTRING	; Удалить все строки под ней (без изменения текущей позиции)
	ld de,FM_MSG13		; Запросить адрес начала программного кода
	rst prn_wascr		; Отобразить
	ld (ix+input_len),04h	; Ввод четырёх символов
	call FM_INPTOBUFF	; Вызвать процедуру ввода в буфер
	cp 1bh			; Нажат ESC ?
	ret z			; Если да, вернёмся в основное меню
	or a
	jr z,FM_GETPARAM	; Пустая строка ? - повтор ввода
	ld de,FM_VAR_START	; Сюда будет помещён результат преобразования
	call CONV_HEXTOBIN	; По указанному адресу будет сохран
	jr c,FM_GETPARAM	; Повторный ввод из-за ошибки данных
	inc (ix+prn_y)		; Перейти к следующей строке
  FM_GETPARAM_LEN:		; Повтор ввода длины блока в случае неудачи
	xor a
	ld (ix+scan_code),a	; Очистить буфер
	ld hl,0004h		; Позиция вывода XY=0,4
	call PRINT_SETPOS	; Установить позицию и атрибуты
	call CLR_UNDERSTRING	; Удалить все строки под ней (без изменения текущей позиции)
	ld de,FM_MSG14		; Запросить длину кода
	rst prn_wascr		; Отобразить запрос
	ld (ix+input_len),05h	; Ввод до 5-и символов (DEC)
	call FM_INPTOBUFF	; Вызвать процедуру ввода из в буфер
	cp 1bh			; Нажат ESC ?
	jr z,FM_GETPARAM	; Если отменён ввод длины - возвращаемся к вводу адреса
	or a
	jr z,FM_GETPARAM_LEN	; Пустая строка ? - повтор ввода
	call CONV_DEC2BIN	; В DE будет сохранен результат преобразования (HL=адрес источника - буфер ввода)
	jr c,FM_GETPARAM_LEN	; В случае ошибки ввода, перейти к повторному запросу
	ld hl,FM_VAR_LNGHT	; По этому адресу будет помещён результат преобразования
	ld (hl),d
	inc hl
	ld (hl),e		; Сохранить размер данных в обратном порядке (Старший/младший)
	inc (ix+prn_y)		; Перейти к следующей строке
	call FM_CHECK_FREE	; Запросить наличие свободной памяти EEPROM (HL - конец буфера с размером блока)
	jr nc,FM_GETPARAM_PAGE	; Продолжить ввод данных, если места достаточно, иначе
	ld de,FM_MSG30		; Сообщение о недостатке свободного места
	rst prn_wascr		; Вывод сообщения
	call FM_WAIT_ANYKEY	; Ждать нажатия любой клавиши
	call CLR_CURSTRING	; Очистить текущую строку (c сообщением об ошибке)
	dec (ix+prn_y)		; Перейти к предыдущей строке	
	jr FM_GETPARAM_LEN	; Вернуться к началу ввода данных	; Из-за отсутствия полного выхода, возможно зацикливание, если свободной памяти <27 байт

  FM_GETPARAM_PAGE:		; Повтор ввода длины блока в случае неудачи
	xor a
	ld (ix+scan_code),a	; Очистить буфер
	ld hl,0005h		; Позиция вывода XY=0,4
	call PRINT_SETPOS	; Установить позицию и атрибуты
	call CLR_UNDERSTRING	; Удалить все строки под ней (без изменения текущей позиции)
	ld de,FM_MSG15		; Запросить номер страницы
	rst prn_wascr		; Отобразить запрос
	ld (ix+input_len),01h	; Ввод до 1-го символа
	call FM_INPTOBUFF	; Вызвать процедуру ввода из в буфер
	cp 1bh			; Нажат ESC ?
	jr z,FM_GETPARAM_LEN	; Если отменён ввод страницы - возвращаемся к вводу длины
	or a
	jr z,FM_GETPARAM_PAGE	; Пустая строка ? - повтор ввода
	ld de,FM_VAR_PAGE	; Сюда будет помещён результат преобразования
	call CONV_HEXTOBIN	; По указанному в HL адресу будет сохран
	jr c,FM_GETPARAM_PAGE	; В случае ошибки ввода, перейти к повторному запросу	
	ld a,(hl)
	cp 04h			; Номер страницы (0-3)
	jr nc,FM_GETPARAM_PAGE	; Если выходит за пределы диапазона - запросить повторный ввод
	rrca
	rrca			; Умножить на 64 (00-40-80-C0)
	ld (hl),a		; Сохранить номер страницы в FM_VAR_PAGE
	inc (ix+prn_y)		; Перейти к следующей строке
  FM_GETPARAM_FNAME:		; Повтор ввода длины блока в случае неудачи
	ld de,FM_MSG16		; Запросить имя файла
	rst prn_wascr		; Отобразить запрос
  FM_GETPARAM_FNAMERP:
	xor a
	ld (ix+scan_code),a	; Очистить буфер
	ld (ix+prn_x),a		; Установить позицию печати на начало строки
	call CLR_CURSTRING	; Очистить текущую строку
	ld (ix+input_len),0fh	; Ввод до 15-и символов имени (оставим один пробел в конце строки)
	call FM_INPTOBUFF	; Вызвать процедуру ввода из в буфер
	cp 1bh			; Нажат ESC ?
	jr z,FM_GETPARAM_PAGE	; Если отменён ввод имени файла - возвращаемся к вводу страницы	
	or a
	jr z,FM_GETPARAM_FNAMERP; Пустая строка ? - повтор ввода	
	ld hl,FM_MSG4		; адрес источника (буфер с названием)
	ld de,FM_VAR_NAME	; адрес буфера приёмника
	push de
	ld b,10h		; 16 циклов (заполняем буфер пробелами)
	ld a," "
  FM_GETPARAM_FNAME_L2:
	ld (de),a		; Очищаем буфер от предыдущих записей
	inc de
	djnz FM_GETPARAM_FNAME_L2
	pop de			; Восстановим адрес начала буфера
  FM_GETPARAM_FNAME_L1:
	ld a,(hl)
	or a
	ret z			; Выйти из подпрограммы для последующего перехода к присоединению или перезаписи
	ld (de),a
	inc hl
	inc de
	jr FM_GETPARAM_FNAME_L1	; Перейти к копированию следующего байта
	
 FM_GETPARAM_YN:
 	ld (ix+scan_code),00h	; Очистим буфер ввода
	halt			; Ждём прерывания
	call PS2CODE_CONVERT	; Проверка буфера PS/2 клавиатуры
	ld a,(ix+scan_code)
	ld (ix+scan_code),00h	; Очистим буфер ввода
	cp "y"			; Нажата клавиша 'y' ?
	jr z,FM_WRITE_PROC	; Вызвать подпрограмму ввода нового адреса
	cp "n"			; Нажата 'n'?
	jr nz,FM_GETPARAM_YN	; Продолжаем ожидать нажатие клавиш, иначе выйти из программы
	ld a,1bh		; Загрузить ESC для выхода в основное меню
	ret
; -----------------------------
  FM_WRITE_PROC:
	call FM_INIT_SCR	; Очистить экран и отобразить шапку с i2c ID
	ld hl,0003h		; Позиция вывода XY=0,3
	call PRINT_SETPOS	; Установить позицию и атрибуты
	ld de,FM_MSG31		; Сообщить о начале процесса записи данных
	rst prn_wascr		; Отобразить
; Тут вызвать процедуру записи	
	call FM_WRITE_DATA	; Вызвать процедуру записи данных
	ld hl,0003h		; Позиция вывода XY=0,3
	call PRINT_SETPOS	; Установить позицию и атрибуты
	ld de,FM_MSG32		; Сообщить о окончании записи
	jp FM_PRN_ANYKEY	; Перейти к сообщению о завершении и ожидании любой клавиши
; -----------------------------
FM_APPEND:
	ld a,(FM_VFILES)
	cp 0ffh
	ret z			; Не запускать APPEND, если обнаружено 255 или более файлов
	call FM_GETPARAM	; Запросить все прараметры для записи по адресу в (FM_VADR1)
	cp 1bh			; Ввод данных завершился нажатием ESC ?
	jr nz,FM_APPEND_CONT	; Если нет - продолжить обработку, иначе
	xor a			; Обнулить A перед возвратом в меню выбора
	ret			; Вернуться в основное меню
  FM_APPEND_CONT:
	call FM_APPEND_FNCP	; Запросить подтверждение дозаписи по адресу FM_VADR1
	jr FM_GETPARAM_YN	; Перейти к ожиданию подтверждения с последующим переходом к записи
; ----------------------------	
  FM_APPEND_FNCP:
	call FM_INIT_SCR  
	ld hl,0000h		; Позиция вывода XY=0,0
	call PRINT_SETPOS	; Установить позицию и атрибуты
	ld hl,FM_VADR1		; Здесь хранится адрес свободной ячейки данных (в двоичной форме)
	ld de,FM_MSG17+0bh	; смещение
	ld a,4			; Число ASCII знаков
	call CONV_BINTOHEX	; Преобразровать
	ld a,"?"
	ld (de),a		; Заменить после преобразования завершающий 00h знаком ?
	ld de,FM_MSG17		; Запрос прошивки
	rst prn_wascr		; Отобразить подтверждение прошивки с заданного адреса
	ld hl,0702h		; Позиция вывода XY=7,2
	call PRINT_SETPOS	; Установить позицию и атрибуты
	ld de,FM_MSG29
	rst prn_wascr		; Отобразить Да/Нет ?
	ret			; Завершить подпрограмму (последует переход к запросу Y/N и последующей записи)
; -----------------------------
FM_OVERWRITE:
	call FM_GETPARAM	; Запросить все прараметры для записи по адресу в (FM_VADR1)
	cp 1bh			; Ввод данных завершился нажатием ESC ?
	jr nz,FM_OVERWRITE_CONT	; Если нет - продолжить обработку, иначе
	xor a			; Обнулить A перед возвратом в меню выбора
	ret			; Вернуться в основное меню
  FM_OVERWRITE_CONT:	
	ld hl,FM_VADR2+1
	ld d,(hl)
	dec hl
	ld e,(hl)		; Считать в DE содержимое FM_VADR2 (начало последней найденной записи)
	dec hl
	ld a,e
	or d			; DE=0 ? Если да - перейти к сохранению в FM_VADR1
	jr z,FM_OVERWRITE_ZR
	dec de
	dec de
	dec de			; DE=DE-3  Вычислить адрес начала записи (с преамбулы)
  FM_OVERWRITE_ZR:
	ld (hl),e
	dec hl
	ld (hl),d		; Сохранить в FM_VADR1 (Следует перед FM_VADR2) содержимое DE В ОБРАТНОМ ПОРЯДКЕ !   Сначала идёт СТАРШИЙ байт, затем МЛАДШИЙ
	call FM_OVERWRITE_FNCP	; Запросить подтверждение дозаписи по адресу FM_VADR1
	jp FM_GETPARAM_YN	; Перейти к ожиданию подтверждения с последующим переходом к записи
; ----------------------------	
  FM_OVERWRITE_FNCP:
	call FM_INIT_SCR  
	ld hl,0000h		; Позиция вывода XY=0,0
	call PRINT_SETPOS	; Установить позицию и атрибуты
	ld hl,FM_VADR1		; Здесь хранится адрес свободной ячейки данных (в двоичной форме)
	ld de,FM_MSG22+15h	; смещение
	ld a,4			; Число ASCII знаков
	call CONV_BINTOHEX	; Преобразровать
	ld a," "
	ld (de),a		; Заменить после преобразования завершающий 00h знаком ?
	ld de,FM_MSG22		; Запрос прошивки
	rst prn_wascr		; Отобразить подтверждение прошивки с заданного адреса
	ld hl,0702h		; Позиция вывода XY=7,2
	ret			; Завершить подпрограмму (последует переход к запросу Y/N и последующей перезаписи)
; -----------------------------
FM_ERASEALL:
	call FM_INIT_SCR
	ld hl,0003h		; Позиция вывода XY=0,3
	call PRINT_SETPOS	; Установить позицию и атрибуты
	ld de,FM_MSG18		; Предупреждение о удалении данных
	rst prn_wascr		; Отобразить
	call CLR_CURSTRING	; Очистить следующую строчку	
  FM_ERASE_YN:
	halt			; Ждём прерывания
	call PS2CODE_CONVERT	; Проверка буфера PS/2 клавиатуры
	ld a,(ix+scan_code)	
	ld (ix+scan_code),00h	; Очистим буфер ввода
	cp "y"			; Нажата клавиша 'y' ?
	jr z,FM_ERASE_PROC	; Вызвать подпрограмму ввода нового адреса
	cp "n"			; Нажата 'n'?
	jr nz,FM_ERASE_YN	; Продолжаем ожидать нажатие клавиш, иначе продолжить программу
	xor a			; Выход в предыдущее меню
	ret
; -----------------------------
  FM_ERASE_PROC:
	ld hl,0003h		; Позиция вывода XY=0,3
	call PRINT_SETPOS	; Установить позицию и атрибуты
	ld de,FM_MSG19		; Сообщить о начале процесса удаления
	rst prn_wascr		; Отобразить
	call CLR_CURSTRING	; Очистить следующую строчку
	inc (ix+prn_y)		; Перейти на строку под ней
	call CLR_CURSTRING	; Очистить строчку
	ld hl,I2C_EEPROM_WRBUFF	; Адрес буфера записи в EEPROM
	ld b,128		; Длина буфера
	ld a,0ffh		; Код заполнения
  FM_ERASE_PREP:
	ld (hl),a		; Записать код FF по текущему адресу буфера
	inc hl			; Следующий адрес
	djnz FM_ERASE_PREP	; Выполнить 128 раз для заполнения буфера
	ld hl,0000h		; Адрес начала EEPROM для очистки
	ld bc,128
  FM_ERASE_SECT:
	ld a,(fm_cur_eeprom)	; Загрузить адрес EEPROM
	ex de,hl		; DE <-Адрес стираемого блока
	push de			; Сохранить адрес начала блока
	push bc			; Сохранить размер блока
	call I2C_EEPROM_WRPAGE	; Вызвать стирание EEPROM, путём перезаписи 128 байт содержимым буфера
	pop bc			; Восстановить размер блока
	pop hl			; Восстановить адрес начала блока в HL
	add hl,bc		; +128 к HL
	jr nc,FM_ERASE_SECT	; Стереть следующий 128-байт сектор, пока HL не пройдём весь цикл до HL=0000h
	ld hl,0003h		; Позиция вывода XY=0,3
	call PRINT_SETPOS	; Установить позицию и атрибуты
	ld de,FM_MSG20		; Сообщить о завершении процесса
	jr FM_PRN_ANYKEY	; Перейти к сообщению о завершении и ожидании любой клавиши
; -----------------------------
FM_WAIT_ANYKEY:
	ld (ix+scan_code),00h	; Очистим буфер ввода
  FM_WAIT_AKEY:
	halt			; Ждём прерывания
	call PS2CODE_CONVERT	; Проверка буфера PS/2 клавиатуры
	ld a,(ix+scan_code)
	or a			; В буфере код 00 ?
	jr z,FM_WAIT_AKEY	; Продолжаем пока нет других кодов
	xor a	
	ret
; -----------------------------
FM_PRN_ANYKEY:
	rst prn_wascr
	call CLR_CURSTRING	; Очистить следующую строчку
	inc (ix+prn_y)		; Перейти на строку под ней
	call CLR_CURSTRING	; Очистить строчку
	inc (ix+prn_y)		; Перейти на строку под ней
	ld de,FM_MSG21		; Нажмите любую клавишу
	rst prn_wascr		; Отобразить
	jr FM_WAIT_ANYKEY	; Перейти к ожиданию любой клавиши, с возвратом в основное меню
; -----------------------------	
FM_SETAUTORUN:
	ld a,(fm_cur_eeprom)	; Загрузить выбранный идентификатор i2c EEPROM
	cp (ix+menu_eepromid)	; Сравнить с системным
	jr z,FM_SETAUTORUNL0	; Если идентификаторы совпадают, продолжить работу, иначе
	call FM_INIT_SCR	; Очистить экран, вывести шапку с указанием номера выбранного i2c устройства
	ld de,FM_MSG45		; Уведомление о невозможности включить автостарт для несистемного EEPROM
	rst prn_wascr		; Отобразить
	jr FM_WAIT_ANYKEY	; Перейти к ожиданию клавиши с последующим выходом
  FM_SETAUTORUNL0:
	call FM_RD_AUTORUN	; Считать параметры автозапуска
  FM_SETAUTORUNL1:    
	push af			; Сохранить полученное значение
	ld hl,0003h		; Позиция вывода XY=0,3
	call PRINT_SETPOS	; Установить позицию и атрибуты
	call CLR_UNDERSTRING	; Удалить все строки под ней (без изменения текущей позиции)
	ld de,FM_MSG40		; Строка Autostart:
	rst prn_wascr		; Отобразить
	pop af
	push af
	ld de,FM_MSG42		; Строка OFF
	cp 0ffh			; Автозапуск отключен ?
	jr z,FM_SETAUTOPROFF
	or a			; Или некорректно установлен ?
	jr z,FM_SETAUTOPROFF
	ld de,FM_MSG41		; Строка ON
  FM_SETAUTOPROFF:
	rst prn_wascr		; Отобразить текущее состояние
	ld hl,0005h		; Позиция вывода XY=0,5
	call PRINT_SETPOS	; Установить позицию и атрибуты
	ld de,FM_MSG43		; Подсказка по дальнейшим действиям
	rst prn_wascr		; Отобразить текущее состояние
  FM_SETAUTOML1:  
	call FM_WAIT_ANYKEY	; Ждём любой клавиши
	pop bc			; Восстановить статус автозапуска в B
	ld a,(ix+scan_code)
	cp 1bh			; ESC ?
	jr z,FM_SETAUTOMEND	; Выйти в основное меню, если ESC
	cp " "
	jr nz,FM_SETAUTOSKP1
	ld a,b
	ld b,0ffh
	cp b
	ld a,b 
	jr nz,FM_SETAUTORUNL1	; Изменить на 0ffh (состояние таймер выключен) и отобразить его
	dec a
	jr FM_SETAUTORUNL1	; Перейти к состоянию таймер включен и отобразить его
  FM_SETAUTOSKP1:  
	cp 0ah			; Нажат ENTER ?
	jr nz,FM_SETAUTOML1	; Если нет, будем ждать нужную клавишу
	ld a,0ffh
	cp b
	ld de,0fffeh
	jp z,FM_WRITE_BYTE	; Если B=#FF (автозапуск выключить), записать данное значение в FFFE и выйти в основное меню
  FM_SETAUTOML2:
	call ROM_MENU		; Вызвать выбор файла из списка
	push af
	call FM_INIT_SCR
	pop af
	jr z,FM_SETAUTORUN	; Вернуться к переключению ON/OFF автостарта если был нажат ESC
	push af			; сохранить выбранный номер
	ld hl,0006h		; Позиция вывода XY=0,3
	call PRINT_SETPOS	; Установить позицию и атрибуты  
	ld de,FM_MSG44		; сообщение запроса ввода задержки автостарта
	rst prn_wascr		; отобразить сообщение
  FM_SETAUTOML3:
	ld (ix+input_len),01h	; Ввод до 1-го символа
	call FM_INPTOBUFF	; Вызвать процедуру ввода из в буфер
	pop bc
	cp 1bh			; Нажат ESC ?
	jr z,FM_SETAUTOML2	; Если отменён ввод задержки - возвращаемся к выбору файла
	or a
	push bc			; Сохранить номер программы
	jr z,FM_SETAUTOML3	; Пустая строка ? - повтор ввода
	ld de,FM_VAR_TIMER	; Сюда будет помещён результат преобразования
	call CONV_HEXTOBIN	; По указанному в HL адресу будет сохран
	jr c,FM_SETAUTOML3	; В случае ошибки ввода, перейти к повторному запросу	
	ld a,(hl)
	cp 0ah			; Длительность задержки (0-9 сек)
	jr nc,FM_SETAUTOML3	; Если выходит за пределы диапазона - запросить повторный ввод
	rlca
	rlca
	ld b,a			; Сохранить введённое значение x4
	rlca
	rlca
	add b			; A=A*20
	inc a			; Добавить 1 -> A=1...181
	ld de,0fffeh		; Адрес ячейки EEPROM для хранения параметров автостарта
	call FM_WRITE_BYTE	; записать значение таймера в FFFE
	pop af			; восстановить выбранный номер в A
	call FM_WRITE_BYTE  	; записать выбранный номер в FFFF
  FM_SETAUTOMEND:
	xor a			; Успешное завершение и выход на уровень выше
	ret
; -----------------------------
FM_INPTOBUFF:
	ld hl,FM_MSG4
	push hl			; Сохранить адрес начала буфера ввода
	ld (ix+input_buf_l),l
	ld (ix+input_buf_h),h	; Приёмный буфер
	ld l,(ix+prn_y)		; Установить позицию
	ld h,(ix+prn_x)		; И режим ввода
	call KEY_INPUT		; Вызвать клавиатурный ввода
				; Требуется проверка корректности ввода
	pop hl			; Восстановить адрес начала буфера ввода
	ret
; -----------------------------
FM_CHECK_FREE:
	ld e,(hl)		; Второй байт - младший
	dec hl			; Адрес первого байта
	ld d,(hl)		; Первый байт - старший, DE= Размер данных
	ld hl,FM_VADR1		; HL= Адрес переменной с началом свободной области
	ld b,(hl)		; Первый байт - старший
	inc hl			; Адрес второго байта
	ld c,(hl)		; BC= Адрес начала записи
	ex de,hl		; HL= Размер
	ld de,27+2		; Размер заголовка, на который увеличится записываемый блок данных + 2 последних байта (параметры автозапуска)
	add hl,bc		; Пробуем сложить размер данных с первым свободным адресом
	ret c			; Выйти сразу, если недостаточно место для записываемых данных
	add hl,de		; Увеличить размер блокаn на заголовок, CY=1 если недостаточно места в EEPROM
	ret			; Выйти из подпрограммы расчета свободного пространства. Если CY=1 - недостаточно свободной памяти!
; -----------------------------
FM_WRITE_DATA:
	ld hl,FM_VADR1		; HL= Адрес переменной с началом свободной области
	ld d,(hl)
	inc hl
	ld e,(hl)		; DE- Адрес начала области запис:  должен указывать на первый свободный байт EEPROM, куда следует начать писать заголовок
	push de			; Сохраним адрес начала области записи 
	ld a,55h
	call FM_WRITE_BYTE	; Записать содержимое A в текущий адрес
	ld a,0aah
	call FM_WRITE_BYTE
	ld a,0aah
	call FM_WRITE_BYTE	; Запись преамбулы
	ld b,11h		; 17 циклов (запись имени и завершающего 00h)
	ld hl,FM_VAR_NAME	; HL-> начало буфера с именем файла
  FM_WRITE_DL1:
	ld a,(hl)
	call FM_WRITE_BYTE	; Запись имени файла
	inc hl
	djnz FM_WRITE_DL1	; Цикл записи имени файла
				; Вычислим абсолютный адрес начала кода
	pop hl			; Восстановим адрес начала области записи в HL
	ld bc,27		; смещение
	add hl,bc		; HL = Абсолютный адрес начала исполняемого кода 
	ld a,l
	call FM_WRITE_BYTE	; Записать младший байт адреса размещения кода
	ld a,h
	call FM_WRITE_BYTE	; Записать старший байт адреса размещения кода
	ld a,(FM_VAR_PAGE)
	call FM_WRITE_BYTE	; Записать номер страницы
	ld a,(FM_VAR_START+1)
	ld l,a
	call FM_WRITE_BYTE	; Записать младший байт адреса размещения программы
	ld a,(FM_VAR_START)
	ld h,a
	call FM_WRITE_BYTE	; Записать старший байт адреса размещения программы
	ld a,(FM_VAR_LNGHT+1)
	ld c,a
	call FM_WRITE_BYTE	; Записать младший байт размера программы
	ld a,(FM_VAR_LNGHT)
	ld b,a
	call FM_WRITE_BYTE	; Записать старший байт размера программы и перейти к записи самого кода DE
  FM_WR_PERBYTE:
	ld a,e
	and 7fh			; Проверяем адрес на кратность 128.  (Если =0 или 128, переходим непосредственно к блочной записи).
				; BC Размер данных
				; HL Адрес начала данных
				; DE Адрес записи
	ld a,(fm_cur_eeprom)	; Адрес EEEPROM
	jp z,I2C_EEPROM_WRDATA	; Если кратное перейти к записи с последующим RET в основное меню
	ld a,(hl)		; читаем записываемые данные
	call FM_WRITE_BYTE	; пишем байт по текущему адресу
	inc hl			; выбираем следующий адрес с данными
	dec bc			; уменьшаем счетчик размера данных для записи
	ld a,b
	or c			; BC=0 ?
	jr nz,FM_WR_PERBYTE	; идём на повтор проверки на кратность 128 и записи следующего байта.  Если адрес EEPROM окажется кратным 128 -> завершаем через блочную запись. Если BC=0, запись закончена - выход
	ret
; -----------------------------
  FM_WRITE_BYTE:
	push hl
	push de
	push bc
	ld (I2C_EEPROM_WRBUFF),a; Поместить в буфер данные для записи
	ld a,(fm_cur_eeprom)	; Адрес EEEPROM
	call I2C_EEPROM_WRBYTE	; Записать байт по адресу DE
	pop bc
	pop de			; Восстановить адрес
	pop hl
	inc de			; Вычислить следующий
	ret
; -----------------------------
  FM_RD_AUTORUN:
	ld de,0fffeh		; DE=Адрес ячейки EEPROM для поиска (Предпоследний байт EEPROM)
	ld a,(fm_cur_eeprom)	; Загрузить идентификатор i2c EEPROM
	call I2C_EEPROM_RDBYTE	; Вызвать чтение байта из указанного адреса EEPROM в буфер HL
	ld a,(hl)		; A=считанный байт - признак включения (00/FF - запрещён / 01-FE значение таймера в 1/20 сек)
	ret
; -----------------------------
FM_MSG1:
	defb "EEPROM Flasher.",0dh,0ah,00h
FM_MSG2:
	defb "EEPROM Not FoundPress a key for exit!",0dh,0ah,00h
FM_MSG3:
	defb "I2C EEPROM:0x",00h
FM_MSG4:
	defs 10h,00h	
FM_MSG5:
	defb 0dh,0ah,"Change? (y/n)",0dh,0ah,00h
FM_MSG6:
	defb "Input addr:0x",00h
FM_MSG7:
	defb 0dh,0ah,"Free at:0x",00h
FM_MSG8:
	defb 0dh,"Records overflow",0dh,00h
FM_MSG9:
	defb 0dh,0ah,"Scanning   ",00h
FM_MSG10:
	defb 0dh,0ah,"File(s):    ",00h
FM_MSG11:
	defb 0ah
	defb "Please select:  ",00h
FM_MSG11_1:
	defb "1.Append record."
FM_MSG11_2:
	defb "2.Overwrite rec."
 	defb "3.Erase ALL rec."
	defb "4.Autostart set.",00h
FM_MSG12:
	defb 20h,20h,00h
FM_MSG13:
	defb "Start at:0x",00h
FM_MSG14:
	defb "Size,byte:",00h
FM_MSG15:
	defb "Memory page:0x",00h
FM_MSG16:
	defb 0dh
	defb " Filename:",0dh,0ah,00h
FM_MSG17:
	defb "Write at:0xXXXX?",00h	
FM_MSG18:
	defb "!!! WARNING !!! "
	defb "ALL DATA WILL BE"
	defb "     ERASED!    "
	defb "  Proceed? y/n  ",00h
FM_MSG19:
	defb "Erasing...      "
	defb "Please wait.    ",00h
FM_MSG20:
	defb " ERASE COMPLETE!",00h
FM_MSG21:
	defb "  Press a key.  ",00h
FM_MSG22:
	defb "Overwrite record"
	defb "at:0xXXXX (y/n?)",00h
FM_MSG29:
	defb "y/n",00h
FM_MSG30:
	defb 0dh
	defb "No free memory!",00h
FM_MSG31:
	defb "Writing...      "
	defb "please wait.    ",00h
FM_MSG32:
	defb " WRITE COMPLETE!",00h
FM_MSG40: 
	defb " Autostart: ",00h
FM_MSG41:
	defb "ON ",00h
FM_MSG42:	
	defb "OFF",00h
FM_MSG43:
	defb "Press SPACE for "
	defb "change and ENTER"
	defb "  to continue.",00h
FM_MSG44:
	defb "Input autostart "
	defb "delay(0-9sec):",00h
FM_MSG45:
	defb 0dh,0ah,0ah
	defb "Autostart can be"
	defb "enabled only for"
	defb " main EEPROM !  ",00h
FM_VFILES:
	defb 00h
FM_VAR1:
	defb 00h,00h
FM_VADR1:
	defb 00h,00h
FM_VADR2:
	defb 00h,00h
FM_VAR_START:
	defb 00h,00h
FM_VAR_LNGHT:
	defb 00h,00h
FM_VAR_PAGE:
	defb 00h
FM_VAR_NAME:
	defs 17,00h
FM_VAR_POS:
	defb 00h,00h
fm_cur_eeprom:
	defb 00h
FM_VAR_TIMER:
	defb 00h
