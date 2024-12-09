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

	racket1Pos				dd 300
	racket2Pos				dd 300

; read-only data
section .rodata use32
	windowWidth				dd 800
	windowHeight			dd 600

	windowClassName         db "door", 0
	windowName				db "nigus bigus", 0
	
	racketWidth				dd 10
	racketHeight			dd 100
	racketOffset			dd 30
	racketSpeed				dd 3

	sigma 					db "the negus ruled Ethiopia until the coup of 1974", 0
	sigma_length 			equ $-sigma
	
; uninitialized static variables
section .bss use32
	windowHandle		resb 4
	messageBuffer		resb 7*4

	blackBrush			resb 4
	whiteBrush			resb 4


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
	
    dll_import    user32.dll,	GetKeyState
    
	dll_import    gdi32.dll,	CreateSolidBrush
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
	push	sigma_length			; message length
	push 	sigma					; message
	call	print_to_stdout
	add		esp, 8

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

	push	16					; approximately 60 FPS (1s / 16ms ~= 60)
	call	[Sleep]

	jmp		mainMessageLoop
	
	
gameLoop:
	push	ebp
	mov		ebp, esp

	push 	ebx
	push	esi

_update:
	cmp		dword [wKeyDown], 1
	jne		_update_NotW
	mov		eax, dword [racket1Pos]
	sub		eax, dword [racketSpeed]
	mov 	dword [racket1Pos], eax
_update_NotW:
	cmp		dword [sKeyDown], 1
	jne		_update_NotS
	mov		eax, dword [racket1Pos]
	add		eax, dword [racketSpeed]
	mov 	dword [racket1Pos], eax
_update_NotS:
	cmp		dword [upArrowDown], 1
	jne		_update_NotUp
	mov		eax, dword [racket2Pos]
	sub		eax, dword [racketSpeed]
	mov 	dword [racket2Pos], eax
_update_NotUp:
	cmp		dword [downArrowDown], 1
	jne		_update_NotDown
	mov		eax, dword [racket2Pos]
	add		eax, dword [racketSpeed]
	mov 	dword [racket2Pos], eax
_update_NotDown:
	; update ball

_render:
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

	; racket offset
	mov		eax, dword [racketHeight]
	mov		edx, 2
	div 	dl							; ax := al / dl
	movzx	esi, ax						; offset in esi

	; player 1
	mov		ecx, dword [racket1Pos]
	
	mov		eax, dword [racketOffset]
	mov		dword [esp +0], eax
	
	mov		eax, ecx
	sub		eax, esi
	mov		dword [esp +4], eax
	
	mov		eax, dword [racketOffset]
	add		eax, dword [racketWidth]
	mov		dword [esp +8], eax
	
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
	mov		dword [esp +0], eax
	
	mov		eax, ecx
	sub		eax, esi
	mov		dword [esp +4], eax

	mov		eax, dword [windowWidth]
	sub		eax, dword [racketOffset]
	mov		dword [esp +8], eax

	mov		eax, ecx
	add		eax, esi
	mov		dword [esp+12], eax

	lea		ecx, [esp]
	push 	dword [whiteBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]

	; ReleaseDC(hwnd, hdc) [hwnd is already on the stack]
	push	ebx
	push 	dword [windowHandle]
	call	[ReleaseDC]

	pop 	esi
	pop 	ebx

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
	push	dword [blackBrush]
	call 	[DeleteObject]

	push	dword [whiteBrush]
	call 	[DeleteObject]

	push	dword [ebp_hwnd]
	call	[DestroyWindow]

	mov		esp, ebp
	pop		ebp
	ret		16

_onQuit:
	push	0
	call	[ExitProcess]
	ret