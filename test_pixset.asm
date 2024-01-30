;TEST PIXEL_SET
;	ld a,7
;	call SET_STARTLINE
	push hl
	ld h,05h
	ld l,03h
	call PIXEL_INV
	ld h,09h
	ld l,02h
	call PIXEL_RES
	ld hl,2008h
	ld bc,4020h
	ld a,0
	call AREA_FILL
	ld de,PICTURE_DATA
	ld hl,0000h		; hl = адрес верхнего левого пиксела
	ld bc,8040h		; bc = Количество выводимых столбцовXстрок (128x64)
	call MEM_TO_DISP
	ld de,0xA000
	ld hl,0000h
	ld bc,8040h
	call DISP_TO_MEM
	call CLEAR_SCREEN
	ld de,0xA000
	ld hl,0000h
	ld bc,8040h
	call MEM_TO_DISP
	ld hl,NewBitmap
L1:
	ld (ADDR_FR_BUFFER),hl
	ld a,1
	ld (FR_BUFFER_ON),a
	ld bc,0001h
	add hl,bc
	halt	
	jr L1
	pop hl
;	DI
;	HALT
;END OF TEST