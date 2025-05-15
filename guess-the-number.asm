org 100h
jmp inicio

; --------------------------------
; Seccion de Datos
; --------------------------------
secreto             db 0
intentos            db 5
inputBuffer         db 3,0,3 dup(0)
MIN                 db 1
MAX                 db 10
RANGO               db 0
MILIS               db 0

mensajeMenu          db 13,10,'Iniciar juego? (y/n): ',0
mensajeRango         db 13,10,'Establezca el rango:',13,10,0

mensajeNumIntentos   db 13,10,'Ingresa numero de intentos: ',0
mensajeErrorIntentos db 13,10,'Error: debes ingresar al menos 1 intento.',13,10,0

mensajeErrorTexto    db 13,10,'Error: solo digitos, sin texto ni signos.',13,10,0

mensajeIni           db 13,10,'Limite inferior: ',0
mensajeFin           db 13,10,'Limite superior: ',0
mensajeErrorRango    db 13,10,'Error: Rango Incorrecto',13,10,0

mensajeAdivinar      db 13,10,'== Adivina el numero ==',13,10,0
mensajeIntentos      db 13,10,'Intentos restantes: ',0
mensajePide          db 13,10,'Ingresa un numero: ',0
mensajeBajo          db 13,10,'Muy bajo!',13,10,0
mensajeAlto          db 13,10,'Muy alto!',13,10,0
mensajeGanaste       db 13,10,'Felicidades, adivinaste!',13,10,0
mensajeGameOver      db 13,10,'Game Over! El numero era: ',0
mensajeRepetir       db 13,10,'Volver a jugar? (y/n): ',13,10,0
mensajeSalir         db 13,10,'Presiona ESC para salir...',13,10,0

lineaNueva           db 0Dh,0Ah,'$'

; --------------------------------
; Código
; --------------------------------
inicio:
    mov ax, cs
    mov ds, ax
    mov si, OFFSET mensajeMenu
    call imprimir
    call esperaInputJuego

pedirRango:
    mov si, OFFSET mensajeRango
    call imprimir

    ; --- Leer MIN con validación de dígitos ---
readMin:
    mov si, OFFSET mensajeIni
    call imprimir
    call pedirNumero
    mov cl, [inputBuffer+1]      ; longitud de entrada
    lea si, inputBuffer+2
checkMinChars:
    mov dl, [si]
    cmp dl, '0'
    jb badLimChars
    cmp dl, '9'
    ja badLimChars
    inc si
    dec cl
    jnz checkMinChars
    mov [MIN], bl
    jmp readMax

badLimChars:
    mov si, OFFSET mensajeErrorTexto
    call imprimir
    jmp readMin

    ; --- Leer MAX con validación de dígitos ---
readMax:
    mov si, OFFSET mensajeFin
    call imprimir
    call pedirNumero
    mov cl, [inputBuffer+1]
    lea si, inputBuffer+2
checkMaxChars:
    mov dl, [si]
    cmp dl, '0'
    jb badLimChars2
    cmp dl, '9'
    ja badLimChars2
    inc si
    dec cl
    jnz checkMaxChars
    mov [MAX], bl
    jmp checkRange

badLimChars2:
    mov si, OFFSET mensajeErrorTexto
    call imprimir
    jmp readMax

    ; --- Validar rango y generar secreto ---
checkRange:
    mov al, [MAX]
    cmp al, [MIN]
    jb .errorRango
    sub al, [MIN]
    inc al
    mov [RANGO], al

    mov ah, 2Ch
    int 21h
    mov [MILIS], dl
    xor ah, ah
    mov al, [MILIS]
    div [RANGO]
    add ah, [MIN]
    mov [secreto], ah
    call limpiarPantalla
    jmp pedirIntentos

.errorRango:
    mov si, OFFSET mensajeErrorRango
    call imprimir
    jmp pedirRango

    ; --- Pedir intentos (>=1, solo dígitos) ---
pedirIntentos:
    mov si, OFFSET mensajeNumIntentos
    call imprimir
    call pedirNumero

    mov cl, [inputBuffer+1]
    lea si, inputBuffer+2
checkIntentChars:
    mov dl, [si]
    cmp dl, '0'
    jb badIntentChars
    cmp dl, '9'
    ja badIntentChars
    inc si
    dec cl
    jnz checkIntentChars

    cmp bl, 0
    jne okIntentos

    mov si, OFFSET mensajeErrorIntentos
    call imprimir
    jmp pedirIntentos

badIntentChars:
    mov si, OFFSET mensajeErrorTexto
    call imprimir
    jmp pedirIntentos

okIntentos:
    mov [intentos], bl

    mov si, OFFSET mensajeAdivinar
    call imprimir
    jmp ciclo

ciclo:
    mov si, OFFSET mensajeIntentos
    call imprimir
    mov al, [intentos]
    call imprimirNumero
    call pedirNumero
    call comparar
    cmp al, 0
    je ganado
    dec byte ptr [intentos]
    cmp byte ptr [intentos], 0
    jne ciclo

gameover:
    mov si, OFFSET mensajeGameOver
    call imprimir
    mov bl, [secreto]
    call printDecByte
    call jugarDeNuevo

ganado:
    mov si, OFFSET mensajeGanaste
    call imprimir
    call jugarDeNuevo

jugarDeNuevo:
    mov si, OFFSET mensajeRepetir
    call imprimir
    jmp esperaInputJuego

esperaInputJuego:
    mov ah, 01h
    int 21h
    cmp al, 'y'
    je limpiarYJugar
    cmp al, 'Y'
    je limpiarYJugar
    cmp al, 'n'
    je mostrarSalir
    cmp al, 'N'
    je mostrarSalir
    jmp esperaInputJuego

limpiarYJugar:
    call limpiarPantalla
    jmp pedirRango

mostrarSalir:
    call limpiarPantalla
    mov si, OFFSET mensajeSalir
    call imprimir
    call esperaESC
    int 20h

esperaESC:
    mov ah, 0
.waitEsc:
    int 16h
    cmp al, 27
    jne .waitEsc
    ret

; --------------------------------
; Subrutinas auxiliares
; --------------------------------
pedirNumero:
    mov si, OFFSET mensajePide
    call imprimir
    mov ah, 0Ah
    lea dx, inputBuffer
    int 21h
    mov cl, [inputBuffer+1]
    xor ch, ch
    lea si, inputBuffer+2
    xor ax, ax
.conv:
    mov dl, [si]
    sub dl, '0'
    mov dh, 0
    mov bx, ax
    shl ax, 1
    shl ax, 1
    add ax, bx
    shl ax, 1
    add ax, dx
    inc si
    loop .conv
    mov bl, al
    ret

comparar:
    cmp bl, [secreto]
    je .ok
    jb .bajo
    mov si, OFFSET mensajeAlto
    call imprimir
    mov al, 1
    ret
.bajo:
    mov si, OFFSET mensajeBajo
    call imprimir
    mov al, 1
    ret
.ok:
    mov al, 0
    ret

imprimir:
    push ax
    push si
.nextChar:
    lodsb
    cmp al, 0
    je .end
    mov ah, 0Eh
    int 10h
    jmp .nextChar
.end:
    pop si
    pop ax
    ret

imprimirNumero:
    add al, '0'
    mov ah, 0Eh
    int 10h
    ret

printDecByte:
    push ax
    push bx
    push cx
    push dx
    xor cx, cx
    mov al, bl
.nextD:
    xor dx, dx
    mov bx, 10
    div bx
    push dx
    inc cx
    cmp al, 0
    jne .nextD
.printD:
    pop dx
    add dl, '0'
    mov ah, 0Eh
    mov al, dl
    int 10h
    loop .printD
    pop dx
    pop cx
    pop bx
    pop ax
    ret

limpiarPantalla PROC NEAR
    push ax
    push bx
    push cx
    push dx
    mov cx,25
.lin2:
    mov ah,09h
    mov dx,OFFSET lineaNueva
    int 21h
    loop .lin2
    pop dx
    pop cx
    pop bx
    pop ax
    ret
limpiarPantalla ENDP
