global  _start
extern printf, scanf, fopen, fclose, fgets, strlen

section .data
    MSG1 db 0x1b, "[36mWelcome to WODL. Enjoy!", 0x0a
    LenMSG1 equ $-MSG1
    MSG2 db 0x0a, 0x1b, "[36mThe selected word contains ", 0x1b, "[32m%d letters",0x0a, 0x1b, "[36mInput your first attempt then press ENTER to summit!", 0x00
    MSG3 db 0x1b, "[37mWODL> "
    LenMSG3 equ $-MSG3
    MSG4 db 0x0a, 0x1b, "[37m[%d]", 0x00
    MSG5 db 0x1b, "[35mWrong length!",0x0a, 0x00
    WinMSG db 0x0a, 0x0a, 0x1b, "[36mCongrats! You WON after %d attempts!", 0x0a, 0x00 
    ShowAttempt db 0x1b, "[37m[%d] ", 0x00
    FlushANSI db 0x1b, "[1A", 0x1b, "[2K"
    LenFlush equ $-FlushANSI
    LetterRed db 0x1b, "[31m%c", 0x00
    LetterYellow db 0x1b, "[33m%c", 0x00
    LetterGreen db 0x1b, "[32m%c", 0x00
    Return db 0x0a, 0x00
    wdlistPath db "wordlist", 0x00
    fopenMode db "r", 0x00
    RandNum: times 8 db 0x00
    inFormat db "%s", 0x00
section .bss
    SelectedWord: resb 0x40
    input: resb 0x40
    WordLen: resb 0x8
    Attempts: resb 0x8

section .text
_start:
    mov rsi, MSG1
    mov rdx, LenMSG1
    call print ; 打印欢迎语
OpenWordlist:
    mov rdi, wdlistPath
    mov rsi, fopenMode
    call fopen ; 打开文件流
    push rax
rand:
    rdtsc ; 用CPU时钟做伪随机
    xor rdx, rdx
    mov rbx, 7700 ; 取模词库总数
    div rbx
    ;mov rdx, 1 ; 调试用 固定取词库第一个单词
ReadWordlist:
    push rdx ; 此时[rsp]是计数器 [rsp+8]是文件流
    mov rdi, SelectedWord
    mov rsi, 0x100
    mov rdx, [rsp+8]
    call fgets
    pop rdx
    dec rdx
    test rdx, rdx
    jnz ReadWordlist
    pop rdi
    call fclose ; 关闭文件流 同时对齐栈
GetLen:
    mov rdi, SelectedWord
    call strlen
    dec rax ; 去掉/0的长度
    mov [WordLen], rax
    mov rsi, rax
    mov rdi, MSG2
    call printf
guess:
    mov rdi, Return
    call printf
    mov rsi, MSG3
    mov rdx, LenMSG3
    call print
    mov rdi, inFormat
    mov rsi, input
    call scanf
    inc [Attempts]
    call FlushRow
    mov rdi, ShowAttempt
    mov rsi, [Attempts]
    call printf
CheckLength:
    mov rdi, input
    call strlen
    cmp rax, [WordLen]
    jne WrongLength
    xor rcx, rcx ; 循环计数器
    xor rsi, rsi ; 正确字母计数器
CheckLetters:
    cmp rsi, [WordLen]
    je win
    cmp rcx, [WordLen]
    je guess
    mov byte al, [input+rcx]
    mov byte bl, [SelectedWord+rcx] ; 首先检查当前字母位是否匹配
    cmp al, bl
    je LetterCorrect
    xor rdx, rdx ; 子循环计数器
CheckEachLetter:
    mov byte bl, [SelectedWord+rdx] ; 再检查该字母是否存在于单词
    cmp al, bl
    je LetterContain
    inc rdx
    cmp rdx, [WordLen]
    jne CheckEachLetter
LetterNotContain:
    push rcx ; 保存循环计数器和正确字母计数器
    push rsi
    mov rdi, LetterRed
    mov rsi, rax
    call printf
    pop rsi ; 恢复计数器
    pop rcx
    inc rcx
    jmp CheckLetters

win:
    mov rdi, WinMSG
    mov rsi, [Attempts]
    call printf
exit:
    mov rax, 60
    mov rdi, 0
    syscall

WrongLength:
    mov rdi, MSG5
    mov rsi, [Attempts]
    call printf
    jmp guess

print:
    mov rax, 1 ; write
    mov rdi, 1 ; stdout
    syscall
    ret

FlushRow:
    mov rax, 1 ; write
    mov rdi, 1 ; stdout
    mov rsi, FlushANSI
    mov rdx, LenFlush
    syscall
    ret

LetterContain:
    push rcx ; 保存循环计数器和正确字母计数器
    push rsi
    mov rdi, LetterYellow
    mov rsi, rax
    call printf
    pop rsi ; 恢复计数器
    pop rcx
    inc rcx
    jmp CheckLetters

LetterCorrect:
    push rcx ; 保存循环计数器和正确字母计数器
    push rsi
    mov rdi, LetterGreen
    mov rsi, rax
    call printf
    pop rsi ; 恢复计数器
    pop rcx
    inc rcx
    inc rsi
    jmp CheckLetters
