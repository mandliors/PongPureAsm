[BITS 32] ; 32-bit asm

; macro for importing functions from DLLs (import + extern)
%macro dll_import 2
    import %2 %1
    extern %2
%endmacro


; window constants
SW_SHOW				equ 5

PM_REMOVE			equ 0x0001

WM_CREATE			equ 0x0001
WM_DESTROY			equ 0x0002
WM_PAINT			equ 0x000F
WM_KEYDOWN			equ 0x0100
WM_KEYUP			equ 0x0101
WM_CLOSE			equ 0x0010
WM_QUIT				equ 0x0012


; data
section .data use32
	wKeyDown				dd 0
	sKeyDown				dd 0
	upArrowDown				dd 0
	downArrowDown			dd 0

	player1Score			dd 0
	player2Score			dd 0

	scoreStringBuffer		dw '6', '9', 0


; read-only data
section .rodata use32
	windowWidth				dd 800
	windowHeight			dd 600
	borderWidth				dd 6

	defaultFontName			db "Arial", 0

	windowClassName         db "door", 0
	windowName				db "nigus bigus", 0
	
	racketWidth				dd 10
	racketHeight			dd 60
	racketOffset			dd 30
	racketSpeed				dd 4

	ballSize				equ racketWidth
	
	ballSpeedMultiplier		dd 1.04
	speedBonusOnCollision	dd 4.0

	sigma 					db "the negus ruled Ethiopia until the coup of 1974", 10, 0
	sigma_length 			equ $-sigma

	minusOne				dd -1.0
	two						dd 2.0
	
; uninitialized static variables
section .bss use32
	windowHandle			resb 4
	messageBuffer			resb 7*4

	blackBrush				resb 4
	whiteBrush				resb 4

	defaultFont				resb 4

	racket1Pos				resb 4
	racket2Pos				resb 4

	ballPosX				resb 4
	ballPosY				resb 4
	ballVelX				resb 4
	ballVelY				resb 4


; text segment (or code segment) 
section .text use32 
	; library functions use __stdcall calling convention
    dll_import    user32.dll,   PeekMessageA
    dll_import    user32.dll,   TranslateMessage
    dll_import    user32.dll,   DispatchMessageA
    dll_import    user32.dll,   DefWindowProcA
    dll_import    user32.dll,   ShowWindow
    dll_import    user32.dll,   UpdateWindow
    dll_import    user32.dll,	PostMessageA
    dll_import    user32.dll,	PostQuitMessage
    dll_import    user32.dll,	DestroyWindow

	dll_import	  user32.dll, 	GetDC
	dll_import 	  user32.dll, 	ReleaseDC

    dll_import    user32.dll,	BeginPaint
    dll_import    user32.dll,	EndPaint
    dll_import    user32.dll,	GetClientRect
    dll_import    user32.dll,	FillRect
    dll_import    user32.dll,	DrawTextW
	
    dll_import    user32.dll,	GetKeyState
    
	dll_import    gdi32.dll,	CreateSolidBrush
	dll_import    gdi32.dll,	SetTextColor
	dll_import    gdi32.dll,	SetBkColor
	dll_import    gdi32.dll,	DeleteObject

    dll_import    kernel32.dll, Sleep
    dll_import    kernel32.dll, ExitProcess

	extern		  init
	extern		  register_window_class
	extern		  create_window
	extern		  print_to_stdout


; entry point
..start:
	; init everything (gets module handle, loads argv, gets stdout)
	call	init

	; register window class for the window (needed for creating a window)
	push	windowProcedure			; window procedura (event handler basically)
	push	windowClassName			; class name
	call	register_window_class
	add		esp, 8

	; create the window
	push	windowClassName			; window class name (previously created)
	push	windowName				; window name
	push 	dword [windowHeight]    ; height
	push 	dword [windowWidth]     ; width
	push 	windowHandle			; windows handle
	call 	create_window
	add		esp, 20

	; welcome text
	call	debug

	call	gameInit

; main loop
mainMessageLoop:
	; pop a message
	push	PM_REMOVE			; remove the message from the queue
	push	0
	push	0
	push	0
	push	messageBuffer
	call	[PeekMessageA]

	cmp		eax, 0				; no message left
	je		_messageLoopEnd

	; for some reason, for me the WM_QUIT disappears into the ether (so I need to handle it here)
	cmp		dword [messageBuffer+4], WM_QUIT
	je		_onQuit

	; handle the message normally
	push	messageBuffer
	call	[TranslateMessage]

	push	messageBuffer
	call	[DispatchMessageA]

	jmp 	mainMessageLoop

_messageLoopEnd:
	call	gameLoop

	push	8					; approximately 120 FPS (1s / 8ms ~= 120)
	call	[Sleep]

	jmp		mainMessageLoop
	
	
gameInit:
	push	ebp
	mov		ebp, esp

	; half width and height
	mov		ecx, dword [windowWidth]
	shr		ecx, 1
	mov		edx, dword [windowHeight]
	shr		edx, 1
	
	; rackets
	mov		dword [racket1Pos], edx
	mov		dword [racket2Pos], edx

	; ball
	mov		dword [ballPosX], ecx
	mov		dword [ballPosY], edx

	push	3
	push	0
	fild	dword [esp]
	fild	dword [esp+4]	
	fstp	dword [ballVelX]
	fstp	dword [ballVelY]
	add		esp, 8

	mov		esp, ebp
	pop 	ebp
	ret

gameLoop:
	push	ebp
	mov		ebp, esp

	push 	ebx
	push	esi

	mov		ecx, 0 				; player1 movement
	mov		edx, 0 				; player2 movement

; update
; check racket movement directions
	; racket 1
	cmp		dword [wKeyDown], 1
	jne		_update_NotW
	add		ecx, -1
_update_NotW:
	cmp		dword [sKeyDown], 1
	jne		_update_NotS
	add		ecx, 1
_update_NotS:
	; racket 2
	cmp		dword [upArrowDown], 1
	jne		_update_NotUp
	add		edx, -1
_update_NotUp:
	cmp		dword [downArrowDown], 1
	jne		_update_NotDown
	add		edx, 1
_update_NotDown:

; update racket positions
	imul	ecx, dword [racketSpeed]
	imul	edx, dword [racketSpeed]

	; racket 1
	mov		eax, dword [racket1Pos]
	add		eax, ecx	
	mov		dword [racket1Pos], eax

	mov		ecx, dword [racketHeight]
	shr		ecx, 1
	cmp		dword [racket1Pos], ecx
	jge		_update_racket1TopGood
	mov		dword [racket1Pos], ecx

_update_racket1TopGood:
	mov		ecx, dword [racketHeight]
	shr		ecx, 1
	imul	ecx, -1
	add		ecx, dword [windowHeight]
	cmp		dword [racket1Pos], ecx
	jle 	_update_racket1BottomGood
	mov		dword [racket1Pos], ecx

_update_racket1BottomGood:

	; racket 2
	mov		eax, dword [racket2Pos]
	add		eax, edx	
	mov		dword [racket2Pos], eax

	mov		ecx, dword [racketHeight]
	shr		ecx, 1
	cmp		dword [racket2Pos], ecx
	jge		_update_racket2TopGood
	mov		dword [racket2Pos], ecx

_update_racket2TopGood:
	mov		ecx, dword [racketHeight]
	shr		ecx, 1
	imul	ecx, -1
	add		ecx, dword [windowHeight]
	cmp		dword [racket2Pos], ecx
	jle 	_update_racket2BottomGood
	mov		dword [racket2Pos], ecx

_update_racket2BottomGood:

	; update ball
	mov		eax, dword [ballSize]
	shr		eax, 1

	sub		esp, 8
	fld		dword [ballVelX]
	fistp	dword [esp]
	fld		dword [ballVelY]
	fistp	dword [esp+4]

	mov		ecx, dword [ballPosX]
	add		ecx, dword [esp]
	mov		dword [ballPosX], ecx
	
	mov		edx, dword [ballPosY]
	add		edx, dword [esp+4]
	mov		dword [ballPosY], edx

	add		esp, 8

	; check gameOver
	call	checkGameOver
	cmp		eax, 0						; no game over
	jne		_update_return
	
	; check bottom and top bounce
	mov		ecx, dword [ballPosX]
	mov		eax, dword [ballSize]
	shr		eax, 1
	sub		ecx, eax
	sub		edx, eax
	mov		eax, dword [ballSize]

	cmp 	edx, dword [borderWidth]
	jle		_update_flipBallYVel

	add		edx, dword [ballSize]
	mov		eax, dword [windowHeight]
	sub		eax, dword [borderWidth]
	cmp		edx, eax
	jl		_update_noFlipBallYVel

_update_flipBallYVel:
	fld		dword [ballVelY]
	fld		dword [minusOne]
	fmul
	fstp	dword [ballVelY]

	; check left side bounce
_update_noFlipBallYVel:
	mov		eax, dword [racketOffset]
	add		eax, dword [racketWidth]

	cmp		eax, ecx
	jle		_update_noLeftBounce

	sub		eax, dword [ballSize]
	cmp		ecx, eax
	jle		_update_noLeftBounce
	
	; in the left bouncing area horizontally, now check racket collision
	mov		eax, dword [racket1Pos]		; racketY
	mov		ecx, dword [racketHeight]
	shr		ecx, 1
	sub		eax, ecx
	mov		edx, dword [ballPosY]
	mov		ecx, dword [ballSize]
	shr		ecx, 1
	add		edx, ecx
	cmp		edx, eax
	jle		_update_noLeftBounce

	add		eax, dword [racketHeight]
	sub		edx, dword [ballSize]
	cmp		eax, edx
	jle 	_update_noLeftBounce

	; now bounce on the left
	mov		eax, dword [racketOffset]
	add		eax, dword [racketWidth]
	mov		edx, dword [ballSize]
	shr		edx, 1
	add		eax, edx
	mov		dword [ballPosX], eax

	; calculate new ballVelY:
	mov		ecx, dword [racketHeight]
	shr		ecx, 1
	mov		eax, dword [racket1Pos]
	mov		edx, dword [racket1Pos]
	sub		eax, ecx					; racket top
	add		edx, ecx					; racket bottom
	mov		ecx, dword [ballPosY]		; ballY
										; [eax]×××××[ecx]-------[edx]
	sub		edx, eax					; edx = ×××××-------
	sub		ecx, eax					; ecx = ×××××

	; ballVelY += (ecx/edx * 2 - 1) * speedBonusOnCollision
	sub		esp, 8						; for ecx and edx
	mov		dword [esp], ecx
	mov		dword [esp+4], edx
	fild	dword [esp]
	fild	dword [esp+4]
	fdiv
	fld		dword [two]
	fmul
	fld		dword [minusOne]
	fadd
	fld		dword [speedBonusOnCollision]
	fmul	
	fld		dword [ballVelY]
	fadd
	fstp	dword [ballVelY]	
	add		esp, 8

	fld		dword [ballVelX]
	fld		dword [minusOne]
	fmul
	fld		dword [ballSpeedMultiplier]
	fmul
	fstp	dword [ballVelX]

	; check right side bounce
_update_noLeftBounce:
	mov		eax, dword [windowWidth]
	sub		eax, dword [racketOffset]
	sub		eax, dword [racketWidth]
	
	mov		ecx, dword [ballPosX]
	mov		edx, dword [ballSize]
	shr		edx, 1
	add		ecx, edx

	cmp		ecx, eax
	jle		_update_noRightBounce

	add		eax, dword [ballSize]
	cmp		eax, ecx
	jle		_update_noRightBounce
	
	; in the right bouncing area horizontally, now check racket collision
	mov		eax, dword [racket2Pos]		; racketY
	mov		ecx, dword [racketHeight]
	shr		ecx, 1
	sub		eax, ecx
	mov		edx, dword [ballPosY]
	mov		ecx, dword [ballSize]
	shr		ecx, 1
	add		edx, ecx
	cmp		edx, eax
	jle		_update_noRightBounce

	add		eax, dword [racketHeight]
	sub		edx, dword [ballSize]
	cmp		eax, edx
	jle 	_update_noRightBounce

	; now bounce on the right
	mov		eax, dword [windowWidth]
	sub		eax, dword [racketOffset]
	sub		eax, dword [racketWidth]
	mov		edx, dword [ballSize]
	shr		edx, 1
	sub		eax, edx
	dec		eax
	mov		dword [ballPosX], eax
	
	; calculate new ballVelY:
	mov		ecx, dword [racketHeight]
	shr		ecx, 1
	mov		eax, dword [racket2Pos]
	mov		edx, dword [racket2Pos]
	sub		eax, ecx					; racket top
	add		edx, ecx					; racket bottom
	mov		ecx, dword [ballPosY]		; ballY
										; [eax]×××××[ecx]-------[edx]
	sub		edx, eax					; edx = ×××××-------
	sub		ecx, eax					; ecx = ×××××

	; ballVelY += (ecx/edx * 2 - 1) * speedBonusOnCollision
	sub		esp, 8						; for ecx and edx
	mov		dword [esp], ecx
	mov		dword [esp+4], edx
	fild	dword [esp]
	fild	dword [esp+4]
	fdiv
	fld		dword [two]
	fmul
	fld		dword [minusOne]
	fadd
	fld		dword [speedBonusOnCollision]
	fmul	
	fld		dword [ballVelY]
	fadd
	fstp	dword [ballVelY]	
	add		esp, 8

	fld		dword [ballVelX]
	fld		dword [minusOne]
	fmul
	fld		dword [ballSpeedMultiplier]
	fmul
	fstp	dword [ballVelX]

_update_noRightBounce:

; render
	; hdc = GetDC(hwnd)
	push	dword [windowHandle]
	call	[GetDC]
	mov		ebx, eax

	sub		esp, 16				 ; rect
	
	; background 
	push	esp					 ; &rect
	push	dword [windowHandle] ; windowHandle
	call 	[GetClientRect]

	lea		ecx, [esp]
	push 	dword [blackBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]
	
	; top border
	mov		eax, dword [borderWidth]
	mov		ecx, dword [windowWidth]
	mov		edx, dword [windowHeight]

	mov		dword [esp+0], 0
	mov		dword [esp+4], 0
	mov		dword [esp+8], ecx
	mov		dword [esp+12], eax

	lea		ecx, [esp]
	push 	dword [whiteBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]

	; bottom border
	mov		ecx, dword [windowWidth]
	mov		edx, dword [windowHeight]
	mov		eax, edx
	sub		eax, dword [borderWidth]

	mov		dword [esp+0], 0
	mov		dword [esp+4], eax
	mov		dword [esp+8], ecx
	mov		dword [esp+12], edx

	lea		ecx, [esp]
	push 	dword [whiteBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]

	; left border
	mov		eax, dword [borderWidth]
	mov		ecx, dword [windowWidth]
	mov		edx, dword [windowHeight]

	mov		dword [esp+0], 0
	mov		dword [esp+4], 0
	mov		dword [esp+8], eax
	mov		dword [esp+12], edx

	lea		ecx, [esp]
	push 	dword [whiteBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]

	; right border
	mov		ecx, dword [windowWidth]
	mov		edx, dword [windowHeight]
	mov		eax, ecx
	sub		eax, dword [borderWidth]

	mov		dword [esp+0], eax
	mov		dword [esp+4], 0
	mov		dword [esp+8], ecx
	mov		dword [esp+12], edx

	lea		ecx, [esp]
	push 	dword [whiteBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]

	; draw center dots
	mov		ecx, dword [windowWidth]
	shr		ecx, 1
	mov		eax, dword [racketWidth]
	shr		eax, 1
	sub		ecx, eax					; start x coord
	mov		edx, 0						; start y coord
	mov		eax, dword [racketWidth]	; increment
_gameLoop_centerDotsLoopStart:
	mov		dword [esp+0], ecx
	mov		dword [esp+4], edx
	add		ecx, eax
	add		edx, eax
	mov		dword [esp+8], ecx
	mov		dword [esp+12], edx
	sub		ecx, eax

	push	eax
	push	ecx
	push	edx

	lea		ecx, [esp+3*4]
	push 	dword [whiteBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]

	pop		edx
	pop		ecx
	pop		eax

	add		edx, eax
	add		edx, eax
	cmp		edx, dword [windowHeight]
	jle	_gameLoop_centerDotsLoopStart

	; set text colors
	push	0x00000000
	push	ebx
	call	[SetBkColor]

	push	0x00FFFFFF
	push	ebx
	call	[SetTextColor]

	; draw player 1 score
	mov		ecx, dword [windowWidth]
	shr		ecx, 2
	mov		dword [esp+0], ecx
	mov		dword [esp+4], 100
	add		ecx, 100
	mov		dword [esp+8], ecx
	mov		dword [esp+12], 150
	
	; set the score buffer
	mov		eax, dword [player1Score]
    mov		ecx, 10
	mov		edx, 0
    div		ecx

	add		eax, 48
	mov		word [scoreStringBuffer], ax
	cmp		eax, 48
	jne		_gameLoop_player1ScoreGreaterThan10
	mov		word [scoreStringBuffer], 32
_gameLoop_player1ScoreGreaterThan10:
	add		edx, 48
	mov		word [scoreStringBuffer+2], dx

	; draw the score text
	lea		ecx, [esp]
	push	0
	push	ecx
	push	-1
	lea		ecx, dword [scoreStringBuffer]
	push	ecx
	push	ebx
	call	[DrawTextW]

	; draw player 2 score
	mov		ecx, dword [windowWidth]
	shr		ecx, 2
	imul	ecx, 3
	mov		dword [esp+0], ecx
	mov		dword [esp+4], 100
	add		ecx, 100
	mov		dword [esp+8], ecx
	mov		dword [esp+12], 150
	lea		ecx, [esp]
	
	; set the score buffer
	mov		eax, dword [player2Score]
    mov		ecx, 10
	mov		edx, 0
    div		ecx

	add		eax, 48
	mov		word [scoreStringBuffer], ax
	cmp		eax, 48
	jne		_gameLoop_player2ScoreGreaterThan10
	mov		word [scoreStringBuffer], 32
_gameLoop_player2ScoreGreaterThan10:
	add		edx, 48
	mov		word [scoreStringBuffer+2], dx

	; draw the score text
	lea		ecx, [esp]
	push	0
	push	ecx
	push	-1
	lea		ecx, dword [scoreStringBuffer]
	push	ecx
	push	ebx
	call	[DrawTextW]

	; racket offset
	mov		esi, dword [racketHeight]
	shr		esi, 1						; divide by 2

	; player 1
	mov		ecx, dword [racket1Pos]
	
	mov		eax, dword [racketOffset]
	mov		dword [esp+0], eax
	
	mov		eax, ecx
	sub		eax, esi
	mov		dword [esp+4], eax
	
	mov		eax, dword [racketOffset]
	add		eax, dword [racketWidth]
	mov		dword [esp+8], eax
	
	mov		eax, ecx
	add		eax, esi
	mov		dword [esp+12], eax

	lea		ecx, [esp]
	push 	dword [whiteBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]

	; player 2
	mov		ecx, dword [racket2Pos]

	mov		eax, dword [windowWidth]
	sub		eax, dword [racketOffset]
	sub		eax, dword [racketWidth]
	mov		dword [esp+0], eax
	
	mov		eax, ecx
	sub		eax, esi
	mov		dword [esp+4], eax

	mov		eax, dword [windowWidth]
	sub		eax, dword [racketOffset]
	mov		dword [esp+8], eax

	mov		eax, ecx
	add		eax, esi
	mov		dword [esp+12], eax

	lea		ecx, [esp]
	push 	dword [whiteBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]

	; ball
	mov		eax, dword [ballSize]
	shr 	eax, 1

	mov		ecx, dword [ballPosX]
	sub		ecx, eax
	mov		dword [esp+0], ecx

	mov		edx, dword [ballPosY]
	sub		edx, eax
	mov		dword [esp+4], edx

	mov		eax, dword [ballSize]
	
	add		ecx, eax
	mov		dword [esp+8], ecx

	add		edx, eax
	mov		dword [esp+12], edx
	lea		ecx, [esp]
	
	push 	dword [whiteBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]

	add		esp, 16

	; ReleaseDC(hwnd, hdc) [hwnd is already on the stack]
	push	ebx
	push 	dword [windowHandle]
	call	[ReleaseDC]

_update_return:
	pop 	esi
	pop 	ebx

	mov		esp, ebp
	pop		ebp
	ret

checkGameOver:
	push	ebp
	mov		ebp, esp

	; left collision
	mov		eax, dword [ballPosX]
	mov		ecx, dword [ballSize]
	shr		ecx, 1
	sub		eax, ecx
	cmp		eax, dword [borderWidth]
	jge 	_checkGameOver_noLeftGameOver
	call	gameInit					; reset
	mov		eax, 2 						; player 2 scroes
	mov		ecx, dword [player2Score]
	inc		ecx
	mov		dword [player2Score], ecx
	jmp		_checkGameOver_return

_checkGameOver_noLeftGameOver:

	; right collision
	add		eax, dword [ballSize]
	mov		ecx, dword [windowWidth]
	sub		ecx, dword [borderWidth]
	cmp		eax, ecx
	jle		_checkGameOver_noRightGameOver
	call	gameInit					; reset
	mov		eax, 1						; player 1 scroes
	mov		ecx, dword [player1Score]
	inc		ecx
	mov		dword [player1Score], ecx
	jge		_checkGameOver_return

_checkGameOver_noRightGameOver:
	mov		eax, 0

_checkGameOver_return:
	mov		esp, ebp
	pop		ebp
	ret

; main window procedure
windowProcedure:
	push	ebp
	mov		ebp, esp
	
	%define		ebp_hwnd 	 ebp+8
	%define		ebp_message  ebp+12
	%define		ebp_wparam 	 ebp+16
	%define		ebp_lparam 	 ebp+20
	
	; switch table
	cmp		dword [ebp_message], WM_CREATE
	je		_onCreate
	cmp		dword [ebp_message], WM_DESTROY
	je		_onDestroy
	cmp		dword [ebp_message], WM_PAINT
	je		_onPaint
	cmp		dword [ebp_message], WM_KEYDOWN
	je		_onKeyDown
	cmp		dword [ebp_message], WM_KEYUP
	je		_onKeyUp
	cmp		dword [ebp_message], WM_CLOSE
	je		_onClose
	cmp		dword [ebp_message], WM_QUIT
	je		_onQuit
	
_defaultProcedure:
	push	dword [ebp_lparam]
	push	dword [ebp_wparam]
	push	dword [ebp_message]
	push	dword [ebp_hwnd]
	call	[DefWindowProcA]

	mov		esp, ebp
	pop		ebp
	ret		16

_onCreate:
	; create brushes
	push	0x00000000
	call	[CreateSolidBrush]
	mov		dword [blackBrush], eax

	push	0x00FFFFFF
	call	[CreateSolidBrush]
	mov		dword [whiteBrush], eax

	; show and update the window
	push	SW_SHOW
	push	dword [ebp_hwnd]
	call	[ShowWindow]

	push	dword [ebp_hwnd]
	call	[UpdateWindow]
	
	mov		esp, ebp
	pop		ebp
	ret		16

_onDestroy:
	push	0
	call	[PostQuitMessage]

	mov		esp, ebp
	pop		ebp
	ret		16

_onPaint: ; empty paint code
	sub		esp, 64 				; paintStruct

	; BeginPaint(windowHandle, &paintStruct)
	push	esp						; &paintStruct
	push	dword [windowHandle]	; windowHandle
	call	[BeginPaint]
	mov		ebx, eax				; save hdc

	; EndPaint(windowHandle, &paintStruct)
	lea		eax, [esp+16]
	push	eax						; &paintStruct
	push	dword [windowHandle]	; windowHandle
	call	[EndPaint]

	mov		esp, ebp
	pop		ebp
	ret		16

_onKeyDown:
	cmp		dword [ebp_wparam], 0x57	; W key
	jne		_onKeyDown_NotW
	mov		byte [wKeyDown], 1
_onKeyDown_NotW:
	cmp		dword [ebp_wparam], 0x53	; S key
	jne		_onKeyDown_NotS
	mov		byte [sKeyDown], 1
_onKeyDown_NotS:
	cmp		dword [ebp_wparam], 0x26	; Up Arrow
	jne		_onKeyDown_NotUpArrow
	mov		byte [upArrowDown], 1
_onKeyDown_NotUpArrow:
	cmp		dword [ebp_wparam], 0x28	; Down Arrow
	jne		_onKeyDown_NotDownArrow
	mov		byte [downArrowDown], 1
_onKeyDown_NotDownArrow:
	cmp		dword [ebp_wparam], 0x1B	; Escape
	jne		_onKeyDown_NotEscape
	push	0
	call	[PostQuitMessage]
_onKeyDown_NotEscape:
	mov		esp, ebp
	pop		ebp
	ret		16

_onKeyUp:
	cmp		dword [ebp_wparam], 0x57	; W key
	jne		_onKeyUp_NotW
	mov		byte [wKeyDown], 0
_onKeyUp_NotW:
	cmp		dword [ebp_wparam], 0x53	; S key
	jne		_onKeyUp_NotS
	mov		byte [sKeyDown], 0
_onKeyUp_NotS:
	cmp		dword [ebp_wparam], 0x26	; Up Arrow
	jne		_onKeyUp_NotUpArrow
	mov		byte [upArrowDown], 0
_onKeyUp_NotUpArrow:
	cmp		dword [ebp_wparam], 0x28	; Down Arrow
	jne		_onKeyUp_NotDownArrow
	mov		byte [downArrowDown], 0
_onKeyUp_NotDownArrow:
	mov		esp, ebp
	pop		ebp
	ret		16

_onClose:
	; delete brushes
	lea		ecx, [blackBrush]
	push	ecx
	call 	[DeleteObject]

	lea		ecx, [whiteBrush]
	push	ecx
	call 	[DeleteObject]

	; destroy the window
	push	dword [ebp_hwnd]
	call	[DestroyWindow]

	mov		esp, ebp
	pop		ebp
	ret		16

_onQuit:
	push	0
	call	[ExitProcess]
	ret


debug:
	push	ebp
	mov		ebp, esp

	push	sigma_length
	push	sigma
	call	print_to_stdout
	add		esp, 8

	mov		esp, ebp
	pop		ebp
	ret