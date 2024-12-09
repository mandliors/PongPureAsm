[BITS 32] ; 32-bit asm

; macro for importing functions from DLLs (import + extern)
%macro dll_import 2
    import %2 %1
    extern %2
%endmacro


; window constants
SW_SHOW				equ 5

WM_CREATE			equ 0x0001
WM_DESTROY			equ 0x0002
WM_PAINT			equ 0x000F
WM_KEYDOWN			equ 0x0100
WM_KEYUP			equ 0x0101
WM_CLOSE			equ 0x0010


; read-only data
section .rodata use32
	windowClassName         db "door", 0
	windowName				db "nigus bigus", 0
	
	sigma 					db "the negus ruled Ethiopia until the coup of 1974", 0
	sigma_length 			equ $-sigma

	wKeyDown				db 0
	sKeyDown				db 0
	upArrowDown				db 0
	downArrowDown			db 0
	
; uninitialized static variables
section .bss use32
	windowHandle		resb 4
	messageBuffer		resb 7*4

	blackBrush			resb 4
	whiteBrush			resb 4


; text segment (or code segment) 
section .text use32 
	; library functions use __stdcall calling convention
    dll_import    user32.dll,   GetMessageA
    dll_import    user32.dll,   TranslateMessage
    dll_import    user32.dll,   DispatchMessageA
    dll_import    user32.dll,   DefWindowProcA
    dll_import    user32.dll,   ShowWindow
    dll_import    user32.dll,   UpdateWindow
    dll_import    user32.dll,	PostQuitMessage
    dll_import    user32.dll,	DestroyWindow

    dll_import    user32.dll,	BeginPaint
    dll_import    user32.dll,	EndPaint
    dll_import    user32.dll,	GetClientRect
    dll_import    user32.dll,	FillRect
	
    dll_import    user32.dll,	GetKeyState
    
	dll_import    gdi32.dll,	CreateSolidBrush
	dll_import    gdi32.dll,	DeleteObject

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
	push 	600						; height
	push 	800						; width
	push 	windowHandle			; windows handle
	call 	create_window
	add		esp, 20

	; welcome text
	push	sigma_length			; message length
	push 	sigma					; message
	call	print_to_stdout
	add		esp, 8

; main loop to poll events
mainMessageLoop:
	push	0
	push	0
	push	0
	push	messageBuffer
	call	[GetMessageA]
	cmp		eax, 0
	jle		quitProgram

	push	messageBuffer
	call	[TranslateMessage]
	
	push	messageBuffer
	call	[DispatchMessageA]

	jmp		mainMessageLoop

	
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

_onPaint:
	push 	ebx
	push	esi

	; BeginPaint(windowHandle, &paintStruct)
	sub		esp, 64 				; paintStruct
	push	esp						; &paintStruct
	push	dword [windowHandle]	; windowHandle
	call	[BeginPaint]
	mov		ebx, eax				; save hdc


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

	; player 1
	mov		dword [esp +0], 30
	mov		dword [esp +4], 250
	mov		dword [esp +8], 40
	mov		dword [esp+12], 350

	lea		ecx, [esp]
	push 	dword [whiteBrush]	 ; HBRUSH
	push	ecx					 ; &rect
	push	ebx					 ; hdc
	call	[FillRect]


	; EndPaint(windowHandle, &paintStruct)
	lea		eax, [esp+16]
	push	eax						; &paintStruct
	push	dword [windowHandle]	; windowHandle
	call	[EndPaint]

	add		esp, 16
	add		esp, 64
	pop		esi
	pop 	ebx

	mov		esp, ebp
	pop		ebp
	ret		16

_onKeyDown:
	cmp		dword [ebp_wparam], 0x57	; W key
	jne		_notWKeyDown
	mov		byte [wKeyDown], 1
_notWKeyDown:
	cmp		dword [ebp_wparam], 0x53	; S key
	jne		_notSKeyDown
	mov		byte [sKeyDown], 1
_notSKeyDown:
	cmp		dword [ebp_wparam], 0x26	; Up Arrow
	jne		_notUpArrowDown
	mov		byte [upArrowDown], 1
_notUpArrowDown:
	cmp		dword [ebp_wparam], 0x28	; Down Arrow
	jne		_notDownArrowDown
	mov		byte [downArrowDown], 1
_notDownArrowDown:
	mov		esp, ebp
	pop		ebp
	ret		16

_onKeyUp:
	cmp		dword [ebp_wparam], 0x57	; W key
	jne		_notWKeyUp
	mov		byte [wKeyDown], 0
_notWKeyUp:
	cmp		dword [ebp_wparam], 0x53	; S key
	jne		_notSKeyUp
	mov		byte [sKeyDown], 0
_notSKeyUp:
	cmp		dword [ebp_wparam], 0x26	; Up Arrow
	jne		_notUpArrowUp
	mov		byte [upArrowDown], 0
_notUpArrowUp:
	cmp		dword [ebp_wparam], 0x28	; Down Arrow
	jne		_notDownArrowUp
	mov		byte [downArrowDown], 0
_notDownArrowUp:
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

quitProgram:
	push	0
	call	[ExitProcess]
	ret