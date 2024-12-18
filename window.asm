[BITS 32] ; 32-bit asm

; macro for importing functions from DLLs (import + extern)
%macro dll_import 2
    import %2 %1
    extern %2
%endmacro


; window constants
CS_VREDRAW			equ 0x0001
CS_HREDRAW			equ 0x0002
IDI_APPLICATION		equ 32512
IDC_ARROW			equ 32512
COLOR_WINDOW		equ 5

MB_OK				equ 0x00000000
MB_ICONEXCLAMATION	equ 0x00000030

WS_SYSMENU			equ 0x00080000
WS_MINIMIZEBOX      equ 0x00020000
WS_MAXIMIZEBOX      equ 0x00010000
WS_SIZEBOX          equ 0x00040000
WS_CAPTION			equ 0x00C00000
WS_DEFAULT          equ WS_SYSMENU | WS_MINIMIZEBOX | WS_CAPTION

STD_OUTPUT_HANDLE	equ -11


; read-only data
section .rodata use32
	error_title				db "bruh", 0
	error_registerClassEx	db "failed to register class", 0
	error_createWindowEx	db "failed to create window", 0
	
; uninitialized static variables
section .bss use32
	hInstance			resb 4
	commandLine			resb 4
	stdHandle			resb 4
	windowClassExBuffer	resb 12*4


; text segment (or code segment)
section .text use32
    dll_import    user32.dll,   LoadIconA
    dll_import    user32.dll,   LoadCursorA
    dll_import    user32.dll,   RegisterClassExA
    dll_import    user32.dll,   MessageBoxA
    dll_import    user32.dll,   CreateWindowExA
    dll_import    user32.dll,   AdjustWindowRectEx

    dll_import    kernel32.dll, ExitProcess
    dll_import    kernel32.dll, GetModuleHandleA
    dll_import    kernel32.dll, GetCommandLineA
	dll_import    kernel32.dll, GetStdHandle
	dll_import    kernel32.dll, WriteFile

	dll_import	  kernel32.dll, CreateFileA	

    global        init
    global        register_window_class
    global        create_window
    global        print_to_stdout


; void init()
init:
    push    ebp
    mov     ebp, esp

	; get instance
	push	0
	call 	[GetModuleHandleA]
	mov 	dword [hInstance], eax
	
	; get command line arguments
	call 	[GetCommandLineA]
	mov 	dword [commandLine], eax

	; get stdout
	push    STD_OUTPUT_HANDLE
    call    [GetStdHandle]
    mov     dword [stdHandle], eax

    mov     esp, ebp
    pop     ebp
    ret


; void register_window_class(
;    LPCSTR lpszClassName, 
;    LRESULT CALLBACK (*WindowProc)(HWND, UINT, WPARAM, LPARAM)
; )
register_window_class:
    push    ebp
    mov     ebp, esp

	; fill WNDCLASSEX struct
	mov		dword [windowClassExBuffer + 0], 12*4                       ; cbSize
	mov		dword [windowClassExBuffer + 4], CS_VREDRAW + CS_HREDRAW    ; style
	
    mov     ecx, dword [ebp+12]                                         ; WindowProc
    mov		dword [windowClassExBuffer + 8], ecx                        ; lpfnWndProc
	
    mov		dword [windowClassExBuffer + 12], 0                         ; cbClsExtra
	mov		dword [windowClassExBuffer + 16], 0                         ; cbWndExtra
	mov		eax, dword [hInstance]
	mov		dword [windowClassExBuffer + 20], eax                       ; hInstance

	push	IDI_APPLICATION
	push	0                                                           ; standard icon
	call	[LoadIconA]
	mov		dword [windowClassExBuffer + 24], eax                       ; hIcon

	push	IDC_ARROW
	push	0                                                           ; standard cursor
	call	[LoadCursorA]
	mov		dword [windowClassExBuffer + 28], eax                       ; hCursor

	mov		dword [windowClassExBuffer + 32], COLOR_WINDOW              ; hbrBackground
	mov		dword [windowClassExBuffer + 36], 0                         ; lpszMenuName

    mov     ecx, dword [ebp+8]                                          ; lpszClassName
	mov		dword [windowClassExBuffer + 40], ecx                       ; lpszClassName

	push	IDC_ARROW
	push	dword [hInstance]
	call	[LoadCursorA]
	mov		dword [windowClassExBuffer + 44], eax                       ; hIconSm

	; try to register the class
	push    windowClassExBuffer
	call	[RegisterClassExA]
	cmp		eax, 0
	je		registerClassError

    mov     esp, ebp
    pop     ebp
    ret

; void create_window(HWND* hWnd, int nWidth, int nHeight, LPCTSTR lpWindowName, LPCTSTR lpClassName)
create_window:
    push    ebp
    mov     ebp, esp

	; calculate the actual size (so the client area size, not the whole window size)
	sub		esp, 4*4			; alloc space for rect
	mov		dword [esp+0], 0
	mov		dword [esp+4], 0
	mov		ecx, dword [ebp+12]
	mov		dword [esp+8], ecx	; width
	mov		ecx, dword [ebp+16]
	mov		dword [esp+12], ecx	; height
	mov		ecx, esp

	push	0
	push	0
	push	WS_DEFAULT
	push	ecx
	call	[AdjustWindowRectEx]

	; ecx := clientWidth, edx := clientHeight
	mov		ecx, dword [esp+8]	; rect.right
	sub		ecx, dword [esp+0]	; rect.left
	mov		edx, dword [esp+12] ; rect.bottom
	sub		edx, dword [esp+4]	; rect.top
	add		esp, 4*4
	
	; now create the window
	push	0					; LPVOID lpParam
	push	0					; HINSTANCE hInstance
	push	0					; HMENU hMenu
	push	0					; HWND hWndParent
	push	edx		; int nHeight
	push	ecx		; int nWidth
	push	69					; int y
	push	420					; int x
	push	WS_DEFAULT			; DWORD dwStyle
	push	dword [ebp+20]		; LPCTSTR lpWindowName
	push	dword [ebp+24]      ; LPCTSTR lpClassName
	push	0					; DWORD dwExStyle
	call	[CreateWindowExA]
	mov		ecx, dword [ebp+8]
	mov		dword [ecx], eax	; save handle to hWnd
	cmp		eax, 0
	je		createWindowError

    mov     esp, ebp
    pop     ebp
    ret

; print_to_stdout(message, message_len)
print_to_stdout:
	push	ebp
	mov		ebp, esp

	sub		esp, 4
	mov		ecx, esp

	push 	0
	push	ecx
	push	dword [ebp+12]
	push 	dword [ebp+8]
	push 	dword [stdHandle]
	call	[WriteFile]
	add		esp, 4

	mov		esp, ebp
	pop		ebp
	ret

; error handler for RegisterClassEx
registerClassError:
	push	MB_OK + MB_ICONEXCLAMATION
	push	error_title
	push	error_registerClassEx
	push	0
	call	[MessageBoxA]
	jmp		quitProgram
	
; error handler for CreateWindowEx
createWindowError:
	push	MB_OK + MB_ICONEXCLAMATION
	push	error_title
	push	error_createWindowEx
	push	0
	call	[MessageBoxA]
	
; quit program routine
quitProgram:
	push	0
	call	[ExitProcess]
	ret