org 100h
jmp start

; ================================
;          Data Section
; ================================
secretNumber        db 0                ; The random number to guess
attemptsLeft        db 5                ; Number of tries remaining
inputBuffer         db 3,0,3 dup(0)     ; Input buffer for DOS function 0Ah
rangeMin            db 1                ; Minimum limit of the range
rangeMax            db 10               ; Maximum limit of the range
rangeSize           db 0                ; range = max - min + 1
randomSeed          db 0                ; Value from clock for randomness

; ========== Text Messages ==========
msgStartGame        db 13,10,'Start game? (y/n): ',0
msgSetRange         db 13,10,'Set the number range:',13,10,0

msgAskAttempts      db 13,10,'Enter number of attempts: ',0
msgErrorAttempts    db 13,10,'Error: You must enter at least 1 attempt.',13,10,0

msgErrorInput       db 13,10,'Error: Only digits are allowed.',13,10,0

msgRangeMin         db 13,10,'Lower limit: ',0
msgRangeMax         db 13,10,'Upper limit: ',0
msgErrorRange       db 13,10,'Error: Invalid range.',13,10,0

msgGuessStart       db 13,10,'== Guess the number ==',13,10,0
msgAttemptsLeft     db 13,10,'Attempts left: ',0
msgAskNumber        db 13,10,'Enter a number: ',0
msgTooLow           db 13,10,'Too low!',13,10,0
msgTooHigh          db 13,10,'Too high!',13,10,0
msgYouWin           db 13,10,'Congratulations, you guessed it!',13,10,0
msgGameOver         db 13,10,'Game Over! The number was: ',0
msgPlayAgain        db 13,10,'Play again? (y/n): ',13,10,0
msgPressEsc         db 13,10,'Press ESC to exit...',13,10,0

newLine             db 0Dh,0Ah,'$'      ; For clearing screen effect

; ================================
;          Code Section
; ================================
start:
    mov ax, cs
    mov ds, ax
    mov si, OFFSET msgStartGame
    call printString
    call waitForYesNoInput

askRange:
    mov si, OFFSET msgSetRange
    call printString

; --- Ask for MIN (input validation) ---
readMin:
    mov si, OFFSET msgRangeMin
    call printString
    call getNumberInput
    mov cl, [inputBuffer+1]
    lea si, inputBuffer+2
validateMin:
    mov dl, [si]
    cmp dl, '0'
    jb minInputError
    cmp dl, '9'
    ja minInputError
    inc si
    dec cl
    jnz validateMin
    mov [rangeMin], bl
    jmp readMax

minInputError:
    mov si, OFFSET msgErrorInput
    call printString
    jmp readMin

; --- Ask for MAX (input validation) ---
readMax:
    mov si, OFFSET msgRangeMax
    call printString
    call getNumberInput
    mov cl, [inputBuffer+1]
    lea si, inputBuffer+2
validateMax:
    mov dl, [si]
    cmp dl, '0'
    jb maxInputError
    cmp dl, '9'
    ja maxInputError
    inc si
    dec cl
    jnz validateMax
    mov [rangeMax], bl
    jmp validateRange

maxInputError:
    mov si, OFFSET msgErrorInput
    call printString
    jmp readMax

; --- Calculate range and generate random number ---
validateRange:
    mov al, [rangeMax]
    cmp al, [rangeMin]
    jb .rangeInvalid
    sub al, [rangeMin]
    inc al
    mov [rangeSize], al

    ; Get system time (random seed)
    mov ah, 2Ch
    int 21h
    mov [randomSeed], dl

    xor ah, ah
    mov al, [randomSeed]
    div [rangeSize]
    add ah, [rangeMin]
    mov [secretNumber], ah

    call clearScreen
    jmp askAttempts

.rangeInvalid:
    mov si, OFFSET msgErrorRange
    call printString
    jmp askRange

; --- Ask for number of attempts ---
askAttempts:
    mov si, OFFSET msgAskAttempts
    call printString
    call getNumberInput

    mov cl, [inputBuffer+1]
    lea si, inputBuffer+2
validateAttempts:
    mov dl, [si]
    cmp dl, '0'
    jb attemptsInputError
    cmp dl, '9'
    ja attemptsInputError
    inc si
    dec cl
    jnz validateAttempts

    cmp bl, 0
    jne storeAttempts

    mov si, OFFSET msgErrorAttempts
    call printString
    jmp askAttempts

attemptsInputError:
    mov si, OFFSET msgErrorInput
    call printString
    jmp askAttempts

storeAttempts:
    mov [attemptsLeft], bl
    mov si, OFFSET msgGuessStart
    call printString
    jmp gameLoop

; ================================
;         Game Loop
; ================================
gameLoop:
    mov si, OFFSET msgAttemptsLeft
    call printString
    mov al, [attemptsLeft]
    call printDigit
    call getNumberInput
    call compareGuess
    cmp al, 0
    je youWin
    dec byte ptr [attemptsLeft]
    cmp byte ptr [attemptsLeft], 0
    jne gameLoop

gameOver:
    mov si, OFFSET msgGameOver
    call printString
    mov bl, [secretNumber]
    call printDecimal
    call playAgainPrompt

youWin:
    mov si, OFFSET msgYouWin
    call printString
    call playAgainPrompt

; ================================
;       End / Retry Menu
; ================================
playAgainPrompt:
    mov si, OFFSET msgPlayAgain
    call printString
    jmp waitForYesNoInput

waitForYesNoInput:
    mov ah, 01h
    int 21h
    cmp al, 'y'
    je clearAndRestart
    cmp al, 'Y'
    je clearAndRestart
    cmp al, 'n'
    je showExit
    cmp al, 'N'
    je showExit
    jmp waitForYesNoInput

clearAndRestart:
    call clearScreen
    jmp askRange

showExit:
    call clearScreen
    mov si, OFFSET msgPressEsc
    call printString
    call waitForEscKey
    int 20h             ; Exit program

waitForEscKey:
    mov ah, 0
.wait:
    int 16h
    cmp al, 27          ; ASCII for ESC
    jne .wait
    ret

; ================================
;         Helper Subroutines
; ================================

; Get user input and convert to number
getNumberInput:
    mov si, OFFSET msgAskNumber
    call printString
    mov ah, 0Ah
    lea dx, inputBuffer
    int 21h

    mov cl, [inputBuffer+1]
    xor ch, ch
    lea si, inputBuffer+2
    xor ax, ax
.convert:
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
    loop .convert
    mov bl, al
    ret

; Compare user's guess to the secret number
compareGuess:
    cmp bl, [secretNumber]
    je .correct
    jb .tooLow
    mov si, OFFSET msgTooHigh
    call printString
    mov al, 1
    ret
.tooLow:
    mov si, OFFSET msgTooLow
    call printString
    mov al, 1
    ret
.correct:
    mov al, 0
    ret

; Print a null-terminated string
printString:
    push ax
    push si
.next:
    lodsb
    cmp al, 0
    je .done
    mov ah, 0Eh
    int 10h
    jmp .next
.done:
    pop si
    pop ax
    ret

; Print a single digit (in AL)
printDigit:
    add al, '0'
    mov ah, 0Eh
    int 10h
    ret

; Print a full decimal number (in BL)
printDecimal:
    push ax
    push bx
    push cx
    push dx
    xor cx, cx
    mov al, bl
.convertLoop:
    xor dx, dx
    mov bx, 10
    div bx
    push dx
    inc cx
    cmp al, 0
    jne .convertLoop
.printLoop:
    pop dx
    add dl, '0'
    mov ah, 0Eh
    mov al, dl
    int 10h
    loop .printLoop
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Simulate screen clear by printing blank lines
clearScreen PROC NEAR
    push ax
    push bx
    push cx
    push dx
    mov cx,25
.loop:
    mov ah,09h
    mov dx,OFFSET newLine
    int 21h
    loop .loop
    pop dx
    pop cx
    pop bx
    pop ax
    ret
clearScreen ENDP
