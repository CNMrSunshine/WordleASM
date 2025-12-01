global  _start
extern printf, scanf, fopen, fclose, fgets

section .data
    ; =======================================
    ; 长文字信息
    MSG1 db 0x1b, "[36mWelcome to WODL. Enjoy!", 0x0a
    LenMSG1 equ $-MSG1
    MSG2 db 0x0a, 0x1b, "[36mThe selected word contains ", 0x1b, "[32m%d letters",0x0a, 0x1b, "[36mInput your first attempt then press ENTER to summit!", 0x0a, 0x00
    MSG4 db 0x0a, 0x1b, "[37m [%d] -", 0x00
    MSG5 db 0x1b, "[35m Wrong length!",0x0a, 0x00
    WinMSG db 0x0a, 0x0a, 0x1b, "[36mCongrats! You WON after %d attempts!", 0x0a, 0x00 
    ; =======================================
    ; 短文字信息
    ShowAttempt db 0x1b, "[37m[%d] -", 0x00
    FlushANSI db 0x1b, "[1A", 0x1b, "[2K" ; 控制台移动光标到上一行行首 并清空行
    LenFlush equ $-FlushANSI
    FlushCurANSI db 0x1b, "[2K", 0x1b, "[1G" ; 控制台清除当前行并移动光标到行首
    LenFlushCurANSI equ $-FlushCurANSI
    LetterRed db 0x1b, "[31m [%c]", 0x00
    LetterYellow db 0x1b, "[33m [%c]", 0x00
    LetterGreen db 0x1b, "[32m [%c]", 0x00
    Return db 0x0a, 0x00 ; \n
    Header db 0x1b, "[37mWODL> "
    lenHeader equ $-Header
    LeftSym db "["
    RightSym db "] "
    ; =======================================
    ; 硬编码参数
    wdlistPath db "wordlist", 0x00
    fopenMode db "r", 0x00
    RandNum times 8 db 0x00
    inFormat db "%s", 0x00
    ; =======================================
    ; 有初始值的变量
    input times 0x20 db 0x20
    ; =======================================


section .bss
    ; =======================================
    SelectedWord resb 0x40 ; 存放答案
    WordLen resb 0x8 ; 存放答案长度
    Attempts resb 0x8 ; 存放用户尝试次数
    TermiosData resb 64 ; 终端ioctl数据
    ; =======================================

section .text
_start:
    call RawMode ; 将终端设置为raw输入模式
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
    mov rdx, 1 ; 调试用 固定取词库第一个单词
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
    mov byte sil, 0x00
    call CustomStrlen
    dec rax ; 去掉文件每行结尾的\n
    mov [WordLen], rax
    mov rsi, rax
    mov rdi, MSG2
    call printf
GuessStart:
    mov rdi, Return
    call printf ; 换行顺便fflush
    xor rcx, rcx ; 计数器
ClearBuffer:
    mov [input+rcx], 0x20
    inc rcx
    cmp rcx, 0x20
    jne ClearBuffer
    xor rcx, rcx ; 用户输入字符数计数器
ReadInput:
    push rcx
    sub rsp, 8
    call PrintInput
    add rsp, 8
    pop rcx
    mov rax, 0 ; read
    mov rdi, 0 ; stdin
    lea rsi, [input+rcx] ; 输入缓冲区 input[rcx]
    mov rdx, 1 ; 输入长度
    push rcx ; 保存计数器
    sub rsp, 8 ; 对齐栈
    syscall ; 读取用户输入
CheckInput:
    add rsp, 8
    pop rcx
    mov byte al, [input+rcx] ; al: 输入字符
    cmp al, 0x7f ; del键
    je DeleteLetter ; 删除前一个输入
    cmp al, 0x08 ; 删除键
    je DeleteLetter
    cmp al, 0x61
    jl ClearInput ; 非小写字母 回退输入
    cmp al, 0x7a
    jg ClearInput
    push rcx
    sub rsp, 8
    jmp ProcessLetters ; 处理输入

DeleteLetter:
    mov al, 0x20
    mov byte [input+rcx], al ; 清除当前输入
    dec rcx
    mov byte [input+rcx], al ; 清除前一输入
    jmp ReadInput ; 重新监听输入

ClearInput:
    mov al, 0x20
    mov byte [input+rcx], al ; 回退缓冲区
    dec rcx ; 回退计数器
    jmp ReadInput ; 重新监听输入

ProcessLetters:
    call PrintInput ; 打印输入框
    add rsp, 8
    pop rcx ; 恢复输入计数器
    inc rcx
    cmp rcx, [WordLen]
    jne ReadInput
    call FlushCurrent
PrintAttempt:
    inc [Attempts]
    mov rdi, ShowAttempt
    mov rsi, [Attempts]
    call printf
    xor rcx, rcx ; 循环计数器
    xor rsi, rsi ; 正确字母计数器
CheckLetters:
    cmp rsi, [WordLen]
    je win
    cmp rcx, [WordLen]
    je GuessStart
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
    jmp LetterNotContain

win:
    mov rdi, WinMSG
    mov rsi, [Attempts]
    call printf
exit:
    mov rax, 60
    mov rdi, 0
    syscall


; ===========================================
; 杂项
print:
    mov rax, 1 ; write
    mov rdi, 1 ; stdout
    syscall
    ret

FlushCurrent: ; 清空当前终端行
    mov rax, 1 ; write
    mov rdi, 1 ; stdout
    mov rsi, FlushCurANSI
    mov rdx, LenFlushCurANSI
    syscall
    ret

RawMode: ; 将终端设置为raw输入模式
    mov rax, 16 ; ioctl
    mov rdi, 0 ; stdin
    mov rsi, 0x5401 ; ioctl指令: tcgets
    mov rdx, TermiosData
    syscall ; 获取当前终端配置
    mov eax, dword [TermiosData + 12]  ; lflag偏移
    and eax, ~(0x00000008 | 0x00000002) ; ECHO | ICAMON
    mov dword [TermiosData + 12], eax
    mov byte [TermiosData + 20 + 6], 1 ; vmin = 6
    mov byte [TermiosData + 20 + 5], 0 ; vtime = 5
    mov rax, 16
    mov rdi, 0
    mov rsi, 0x5402 ; ioctl指令: tcsets
    mov rdx, TermiosData
    syscall ; 写入新的终端配置
    ret

PrintInput: ; 打印输入框
    call FlushCurrent ; 清除本行
    mov rsi, Header
    mov rdx, lenHeader
    call print ; 打印"WODL> "
    xor rbx, rbx
PrintLetters: ; 打印用户输入字母
    push rbx ; 保存打印计数器
    sub rsp, 8 ; 对齐栈
    mov rsi, LeftSym
    mov rdx, 1
    call print ; 打印"["
    lea rsi, [input+rbx]
    mov rdx, 1
    call print ; 打印用户输入字母
    mov rsi, RightSym
    mov rdx, 2
    call print ; 打印"] "
    add rsp, 8
    pop rbx ; 恢复打印计数器
    inc rbx
    cmp rbx, [WordLen]
    jne PrintLetters
    ret

CustomStrlen: ; 以[sil]为终止符计算[rdi]字符串长度
    xor rax, rax ; 重置循环计数器
strlenLoop:
    inc rax ; 每检查1字节 rax++
    mov byte bl, [rdi+rax] ; bl = buffer[rax]
    cmp bl, sil
    jne strlenLoop
    ret
    

; ===========================================
; 处理用户输入时的输出

WrongLength:
    mov rdi, MSG5
    mov rsi, [Attempts]
    call printf
    jmp GuessStart

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

; ===========================================
