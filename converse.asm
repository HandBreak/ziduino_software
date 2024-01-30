; *=============================================================================*
; * Библиотека функций конвертации данных					*
; *										* 
; * Доступные функции:								*
; *	CONV_BINTOHEX	v							*
; * 	CONV_BINTODEC								*
; *	CONV_BIN8TODEC  v							*
; *	CONV_HEXTOBIN								*
; *	CONV_DECTOBIN								*
; *	CONV_DECTOHEX								*
; *	CONV_HEXTODEC								*
; *	CONV_BCDTOHEX	v							*
; *	CONV_DECTOBCD								*
; *	CONV_BCDTOHEX								*
; *										*
; * Используемые переменные:							*
; *										*
; * ============================================================================*
;
;
; ------------------------------
CONV_HEXTOSYM:
	rld			; Ah=Al=старший разряд (содержимое [hl] меняется!!)
	push af			; сохранить состояние A
	and 0fh			; Оставляем собственно значение 0-15
	cp 0ah			; Меньше 10 ? (Преобразовывать в букву ?)				 \	
	jr c,CONV_HEXTOSYM_NOSYM; Если меньше то перейти к непосредственному преобраобразованию в ASCII  - заменить на DAA (+6 если A>9)
	add 07h			; Добавить 7, для перехода от чисел к символам в таблице ASCII		 /  (если требуется преобразование в HEX)
  CONV_HEXTOSYM_NOSYM:
	add 30h			; Добавим 30h (ASCII код '0' для получения кода символа)
	ld (de),a		; Запишем результат по текущему адресу буфера
	inc de			; Вычислить адрес следующей ячейки
	pop af			; Восстановить состояние A
	ret
; ------------------------------	
;
; ==============================
; Преобразование двоичного числа
; в шестнадцатиричный формат
;
; input:
;	HL - Адрес данных в двоичном
;	     формате начиная со
;	     старшего разряда
;	DE - Адрес буфера для сохранения
;	     результата преобразования
;	A  - bit 3-0: Размерность числа (max 8 (32bit)
;	     в 16-ричных разрядах (тетрадах)
;	     bit 7: Тип (Знаковый - только HEX / безнаковый)
;	     bit 6: Ведущие нули (пропускать / нет)
; output:
;	HL - Адрес
;	DE - Адрес конца буфера (с '00h')
; ------------------------------
CONV_BINTOHEX:
CONV_BCDTOHEX:
	bit 0,a			; Количество тетрад четное ?
	jr z,CONV_BINTOHEX_MLP	; Если четное, то стандартная процедура преобразования (минимум два цикла)
	ex af,af'		; сохраним A для последующей обработки
	ld a,(hl)		; Загрузим актуальное значение в аккумулятор
	rld			; произведём нечетный цикл ротации.- в основном цикле первым символом пойдёт содержимое младшей тетрады
  CONV_BINTOHEX_ELP:
	ex af,af'		; вернём A на место
  CONV_BINTOHEX_MLP:
	and 0fh			; Оставить только счетчик тетрад (16-ричных разрядов)
	ret z			; Если преобразовывать нечего (А=0), выйти из подпрограммы конвертации
	
	ex af,af'		; сохранить счетчик
	ld a,(hl)		; Считать двоичное число из буфера по текущему адресу
	ex af,af'
  CONV_BINTOHEX_SLP:
	ex af,af'
	call CONV_HEXTOSYM
	ex af,af'		; восстановить счетчик
	dec a			; уменьшить счетчик тетрад
	ld (de),a		; Предварительно записываем код завершения строки (пока А<>0 он будет затираться символом, при A=0 процедура завершится)
	bit 0,a			; Следующий цикл чётный ?
	jr nz,CONV_BINTOHEX_SLP	; Если нечётный, то передём к его обработке, иначе
	ex af,af'
	rld
	inc hl			; Выбираем следующий байт данных
	jr CONV_BINTOHEX_ELP	; Переходим к обработке
; ------------------------------
;
; ==============================
; Преобразование двоичного знакового
; 8-bit числа  в десятичный формат
;
; input:
;	HL - Адрес данных в двоичном
;	     формате начиная со
;	     старшего разряда
;	DE - Адрес буфера для сохранения
;	     результата преобразования
;	A  - bit 7: Тип (Знаковый / безнаковый)
;	     
; output:
;	HL - Адрес
;	DE - Адрес конца буфера (с '00h')
; ------------------------------
CONV_BIN8TODEC:
	bit 7,a			; Знаковый ?
	jr z,CONV_BIN8UNSIGN	; Если нет, то перейти к преобразованию, иначе
	bit 7,(hl)		; + или - ?
	ld a,"+"		
	jr z, CONV_BIN8SIGN
	ld a,"-"
	jr CONV_BIN8SIGN
  CONV_BIN8UNSIGN:
  	xor a
  CONV_BIN8SIGN:  	
	ex de,hl		; HL - приёмный буфер, DE - входные данные
	ld bc,0005h		;
	add hl,bc		; HL на конец буфера
	push hl			; Сохранить вычесленный адрес конца буфера
	ld (hl),a		; помещаем в него 0 + или -
	cp "-"
	ld a,(de)		; A = Делимое
	jr nz,CONV_BIN8_NEXT	; Если не знак "-", обойти NEG
	neg
  CONV_BIN8_NEXT:
	push hl			; Сохранить адрес буфера
	ld h,a			; Делимое в H
	call div8		; Разделить на 10
	pop hl			; Восстановить адрес буфера
	add 30h			; Преобразовать остаток в ASCII кода
	dec hl			; Выбрать предыдущий адрес буфера
	ld (hl),a		; Сохранить результат
	ld a,e			; Частное в A
	or a			; =0 ?
	jr nz,CONV_BIN8_NEXT	; Пока не 0 делить частное ещё на 10
	pop de
	ld a,(de)		; Считаем сохраненный знако (0, + или -)
	or a			; 0-?
	ret z			; Выход, если 0 (de)=конец строки, hl=начало строки
	dec hl			; начало на символ раньше
	ld (hl),a		; Запишем туда + или -
	xor a
	ld (de),a		; Запишем код конца строки
	ret
; ------------------------------	
div8:				; H = делимое
	ld l,10			; Делитель
	ld b,8			; счетчик циклов
	xor a			; остаток
	ld e,a			; частное
  div8_l2:
	or a			; Сбросим CY
	rl h			; делимое H x2  ( 7<-0<-CY)
	rl a			; остаток A x2  ( 7<-0<-H)
	sub l			; вычтем делитель
	jr nc,div8_l1		; если нет переноса, то частное x2, иначе
	add l			; вернём делимое в исходное
	scf			; Установим CY (будет сброшено в 0 при последующем умножении частного)
  div8_l1:
	ccf			; Инвертируем CY
	rl e			; Умножим частное на 2 с записью переноса
	djnz div8_l2		; Повторим для обработки всех 8 бит
	ret
; ------------------------------
;
; ==============================
; Преобразование двоичного 16-bit числа
; в десятичный формат
;
; input:
;	DE - Двоичное 16-bit число
;	HL - Адрес буфера для сохранения
;	     результата преобразования
;	     (до 5 байт + завершающий 00h)
; output:
;	none
; ------------------------------
CONV_BIN2DEC:
	ld b,5			; Количество байт буфера, заполняемых пробелом
  CONV_B2D_CLRBUFF:
	ld (hl)," "		; Записать SPACE
	inc hl
	djnz CONV_B2D_CLRBUFF	; Очистить буфер
	ld (hl),00h		; Записать конец строки в 6-ю позицию
  CONV_B2D_NEXDEC:
	dec hl			; Перейти к позиции на разряд старше / младшего разряда в первой итерации
	push hl			; Сохранить адрес буфера
	call CONV_B2D_DIV16	; Вызвать деление DE на 10
	ex de,hl
	add 30h			; К остатку прибавить 30h для получения знака
	pop hl			; восстановить адрес буфера
	ld (hl),a		; Записать младшую декаду в буфер
	ld a,e
	or d
	jr nz,CONV_B2D_NEXDEC	; Пока DE<>0 делить частное ещё на 10
	ret			; завершить преобразование.  HL=Начало ASCII числа
; ------------------------------
  CONV_B2D_DIV16:		; DE = Делимое
	ld bc,100ah		; B = Счетчик циклов (16), C = Делитель (10)
	xor a			; Обнулить остаток
	ld h,a
	ld l,a			; Обнулить частное
  CONV_B2D_L2:
	or a			; Сброс CY
	rl e
	rl d			; делимое DE x 2
	rl a			; остаток A x2 (7<-0<-DE)
	sub c			; вычтем делитель
	jr nc,CONV_B2D_L1	; Если нет переноса (Остаток =>10), то частное x2, иначе
	add c			; Восстановим делимое в исходное состояние
	scf			; Установим CY (будет сброшено умножением частного)
  CONV_B2D_L1:
	ccf			; CY=!CY
	adc hl,hl		; Умножим частное на 2 с записью переноса
	djnz CONV_B2D_L2	; Повторим для обработки всего числа
	ret			; A=Остаток, HL=Частное
; ------------------------------	
;
; ==============================
; Преобразование шестнадцатиричного
; текстового числа в двоичный формат
;
; input:
;	HL - Адрес данных в HEX
;	     формате начиная со
;	     старшего разряда, заканчивается '0'
;	DE - Адрес буфера для сохранения
;	     результата преобразования
; output:
;	HL - Адрес последнего байта выходного буфера
;	DE - Адрес конца входного буфера (с '00h')
;	CY=1 - ошибка
; ------------------------------
CONV_HEXTOBIN:
	ex de,hl
  CONV_HEXTOBIN_L2:
	xor a
	ld b,0ffh		; счетчик символов = -1
	ld (hl),a		; Записать в конец буфера 0
  CONV_HEXTOBIN_L1:
  	inc b			; увеличить счетчик
	rld
	ld a,(de)		; считать символ
	or a			; конец строки ?
	ret z			; Выход если да

	cp 67h			; Меньше 'g' ?
	ccf
	ret c			; Выход с CY, если >'f'
	cp 30h			
	ret c			; Выход с CY, если <'0'
	cp 3ah
	jr c,CONV_HEXTOBIN_GO	; Если ,<='9',но >'0' - перейти к непосредственному преобразованию
	cp 41h
	ret c			; Выход с CY, если <'A'
	cp 47h
	jr c,CONV_HEXTOBIN_GO	; Если <='G', но =>'A' - перейти к непосредственному преобразованию
	cp 61h
	ret c			; Если <'a', выйти с CY=1, иначе (61-67), продолжить обработку
	
  CONV_HEXTOBIN_GO:
	and 1fh
	sub 10h
	jr nc,CONV_HEXTOBIN_SKIP
	add a,19h
  CONV_HEXTOBIN_SKIP:
	inc de			; Следующий символ в буфере
	bit 1,b			; Четный проход ? (2-ой, 4-ый и т.д.)
	jr z,CONV_HEXTOBIN_L1	; Если нет (1-й, 3-й), то обрабатываем следующий символ такущего байта, иначе
	inc hl			; Следующий адрес выходного буфера
	dec de
	jr CONV_HEXTOBIN_L2	; Иначе (если четный) пишем в следующий адрес сначала 0, затем повторяем цикл, пока не достигнем 00h на входе
; ------------------------------
;
; ==============================
; Преобразование
; десятичного текстового числа 
; в BCD формат
;
; input:
;	HL - Адрес данных в текстовом
;	     формате начиная со 
;	     старшего разряда, заканчивается 00h
;	DE - Адрес буфера для сохранения
;	     результата преобразования
; output:
;	HL - Адрес последнего байта выходного буфера
;	CY=1 - ошибка
; ------------------------------
CONV_DEC2BCD:
	xor a
	ld c,a			; Счетчик разрядов
  CONV_DEC2BCD_COUNT:
	cp (hl)			; Конец строки ?
	jr z,CONV_DEC2BCD_PROC	; Если достигнут конец строки перейти к преобразованию (HL)=0, C=количество знаков
	inc hl			; Следующий знак 1000->100->10->1...
	inc c			; Увеличить счетчик знаков
	jr CONV_DEC2BCD_COUNT	; Повторять цикл
  CONV_DEC2BCD_PROC:
	ex de,hl
  CONV_DEC2BCD_PRL1:
	ld (hl),00h		; Гарантировать 0 в приёмном буфере
	dec de			; Перейти на разряд старше (В первом цикле к 1-ому разряду)
	call CONV_DEC2BCD_CHR	; Получить в A неупакованное BCD. CY=1, если ошибка преобразования
	ret c			; Выйти с CY в случае ошибки
	rrd			; Al->(HL)h, (HL)h->(HL)l->(HL)l->Al
	dec de			; Выбрать предыдущий байт
	dec c			; Уменьшить счетчки разрядов на 1
	call nz,CONV_DEC2BCD_CHR
	ret c			; Выйти с CY в случае ошибки преобразования
	rrd			; - Повторный цикл Al->(HL)h, (HL)h->(HL)l->(HL)l->Al  вне зависимости от количества символов на входе
	ld a,c
	or a			; C=0 ? 
	ret z			; Преобразование успешно завершено Z=1, HL=Адрес старшего байта в BCD слове
	dec c			; Уменьшить счетчки разрядов на 1
	ret z			; Завершить если достигнут конец строки
	inc hl			; HL Указывает на конец приёмного буфера
	jr CONV_DEC2BCD_PRL1	; Продолжить преобразование для следующего разряда
; ------------------------------
  CONV_DEC2BCD_CHR:
	ld a,(de)		; Считать символ
	cp 30h
	ret c			; Выйти с ошибкой, если код символа <'0'
	cp 3ah
	ccf			; CY<-!CY
	ret c			; Выйти с ошибкой если код символа => "Следующий за 9"
	sub 30h			; Преобразовать в неупакованный BCD  '00-09'
	ret
; ------------------------------	
;
; ==============================
; Преобразование
; десятичного текстового числа
; (до 5 символов) в двоичное 16bit
;
; input:
;	HL - Адрес данных в текстовом
;	     формате начиная со 
;	     старшего разряда, 
;	     заканчивается 00h
;	DE - Результат преобразования
; output:
;	CY=1 - ошибка
; ------------------------------
CONV_DEC2BIN:
	xor a
	ld c,a			; Счетчик разрядов
	ld b,a			; Количество умножений на 10
	ld d,a
	ld e,a			; DE - Результат преобразования
  CONV_DEC2BIN_COUNT:
	cp (hl)			; Конец строки ?
	jr z,CONV_DEC2BIN_PROC	; Если достигнут конец строки перейти к преобразованию (HL)=0, C=количество знаков
	inc hl			; Следующий знак 1000->100->10->1...
	inc c			; Увеличить счетчик знаков
	jr CONV_DEC2BIN_COUNT	; Повторять цикл
  CONV_DEC2BIN_PROC:
	ex de,hl		; DE<-Указатель адреса буфера (Указывает на 00h при первом входе) HL<-Результат преобразования (пока=0000h)
  CONV_DEC2BIN_LOOP:
	dec de			; Перейти к младшему разряду
	call CONV_DEC2BCD_CHR	; Получить в A неупакованное BCD. CY=1, если ошибка преобразования
	ret c			; Выйти с CY в случае ошибки
	ex af,af'
	push hl			; Сохранить текущий результат преобразования (0000 в первой итерации)
	ld a,b			; Через A перенести в альтернативный набор порядок множителя
	exx
	ld b,a			; B=Порядок умножения
	ex af,af'		; Получить значение числа в B разряде
	ld l,a
	ld h,0			; HL'=16bit Произведение входного числа A*10
  CONV_D2BMULX:
	ld e,l
	ld d,h			; Сохранить в DE множитель (для последующего добавления)
	ld a,b
	or a
	jr z,CONV_D2BMULX1	; Если счетчик был равен 0 (множитель x1), обойти умножение: HL= младший разряд 0..9)
	add hl,hl
	add hl,hl
	add hl,hl		; 'HL'x8
	add hl,de		; HL+DE(исходное HL) (*9)
	add hl,de		; HL+DE(исходное HL) (*10)
	djnz CONV_D2BMULX	; Повторить x10, если больше 1-го порядка
  CONV_D2BMULX1:
	pop bc			; Восстановить текущий результат преобразования
	add hl,bc		; Суммировать предыдущее вычисленное значение с актуальным
	push hl			; Передаём результат
	exx			; Переходим к основному набору регистров
	pop hl			; Результат операции в HL (перезапишем прежнее значение HL(DE), сохраненное в стеке
	inc b			; Увеличить порядок множителя x10,x100,x1000,x10000
	dec c			; Уменьшить счётчик десятичных разрядов
	jr nz,CONV_DEC2BIN_LOOP	; Повторить цикл, пока не достигнут 0
	ex de,hl
	ret			; Завершить преобразование DE=результат
; ------------------------------
