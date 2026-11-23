#Requires AutoHotkey v2.0

;; global constants
DEBUG_MODE := 0

isSelectionMode := 0 ; Ctrl-m (マーク設定) が押されたときに1になります

EXCLUDED_EXE := "WindowsTerminal.exe"

; すべての状態をリセットする関数
reset_all_status() {
    global
    isSelectionMode := 0

    return
}

is_ahk_enabled() {
    global
    return !WinActive("ahk_exe " EXCLUDED_EXE)
}

send_and_reset(keys) {
    Send keys
    reset_all_status()
}

move_or_select(normalKeys, selectKeys) {
    global
    if isSelectionMode
        Send selectKeys
    else {
        Send normalKeys
        reset_all_status()
    }
}

main() {
    ProcessSetPriority("High")
    if (DEBUG_MODE > 0)
        InstallKeybdHook

    ;; Disable log
    ListLines 0

    ;; Disable delay
    SetControlDelay 0
    ;; SetKeyDelay 0
    SetKeyDelay -1 ;; disable key delay
    SetWinDelay 0
    SendMode "Input"
    ;;SendMode "Play"
}

main()

#UseHook

;; Set suspend toggle key
#SuspendExempt
^F1:: Suspend
#SuspendExempt False

#HotIf is_ahk_enabled()

^b::  ; Left
{
    move_or_select("{Left}", "+{Left}")
    return
}
^f::  ; Right
{
    move_or_select("{Right}", "+{Right}")
    return
}
^p::  ; Down
{
    move_or_select("{Up}", "+{Up}")
    return
}
^n::  ; Up
{
    move_or_select("{Down}", "+{Down}")
    return
}

^a::  ; Beginning of line
{
    move_or_select("{HOME}", "+{HOME}")
    return
}
^e::  ; End of line
{
    move_or_select("{END}", "+{END}")
    return
}

!u::  ; Page up
{
    move_or_select("{PgUp}", "+{PgUp}")
    return
}
^u::  ; Kill to beginning of line
{
    Send "{ShiftDown}{Home}{ShiftUp}" ; Select from cursor to beginning of line
    Sleep 50 ; Wait for selection to apply
    send_and_reset("^x") ; Cut the selected text
    return
}

!<::  ; Beginning of file
{
    move_or_select("^{Home}", "+^{Home}")
    return
}
!>::  ; End of file
{
    move_or_select("^{End}", "+^{End}")
    return
}

^j::  ; New line
{
    send_and_reset("{Enter}")
    return
}

^d::  ; Delete
{
    send_and_reset("{Del}")
    return
}
^h::  ; Backspace
{
    send_and_reset("{BS}")
    return

}

^k::  ; Kill line
{
    savedClipboard := A_Clipboard
    Send "{ShiftDown}{END}{ShiftUp}"
    Sleep 50 ;[ms] この値は環境によって調整してください
    A_Clipboard := "" ; クリップボードを空にする
    Send "^c"
    ClipWait(0.1) ; コピー完了まで待機

    if (A_Clipboard = "") {
        A_Clipboard := savedClipboard
        Send "{Del}" ; 行末なら改行を削除
    } else {
        Send "^x"
    }

    reset_all_status()
    return
}

^/::  ; Undo
{
    send_and_reset("^z")
    return
}

^m::  ; Mark toggle
{
    global
    if isSelectionMode
        isSelectionMode := 0
    else
        isSelectionMode := 1
    return
}

^g::  ; Cancel / Quit
{
    send_and_reset("{Esc}")
    return
}
^s::  ; Save/Search (app-defined)
{
    send_and_reset("^s")
    return
}

^x::  ; Cut (app-defined)
{
    send_and_reset("^x")
    return
}
^c::  ; Copy (app-defined)
{
    send_and_reset("^c")
    return
}
^v::  ; Paste (app-defined)
{
    send_and_reset("^v")
    return
}

!a::  ; Select All
{
    send_and_reset("^a")
    return
}
!f::  ; Find
{
    send_and_reset("^f")
    return
}
!r::  ; Find next
{
    send_and_reset("+{F3}")
    return
}
!p::  ; Print
{
    send_and_reset("^p")
    return
}

;; -----------------------------------------------
;; ELECOM製マウス HUGE（M-HT1UR）用 Slack リアクション
;; マウスアシスタントで Fn1→F13, Fn2→F14, Fn3→F15 に設定すること
;; -----------------------------------------------
SlackReaction(emoji) {
    if !WinActive("ahk_exe slack.exe")
        return

    MouseGetPos &mx, &my
    Click "Right", mx, my
    Sleep 500
    Send "r"
    Sleep 400

    ; タイプではなくクリップボード経由で貼り付け
    savedClip := A_Clipboard
    A_Clipboard := emoji
    ClipWait 1
    Send "^v"
    Sleep 400
    Send "{Enter}"
    A_Clipboard := savedClip
}

^+F1:: SlackReaction("syouti")
^+F2:: SlackReaction("done_stamp")

SlackSaveForLater() {
    if !WinActive("ahk_exe slack.exe")
        return

    MouseGetPos &mx, &my
    Click "Right", mx, my
    Sleep 500

    Send "a"   ; Save for later
    Sleep 400
}

^+F3:: SlackSaveForLater()

; Windows Terminal がアクティブになったら IME をオフ（直接入力）にする
DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
OnMessage(DllCall("RegisterWindowMessage", "Str", "SHELLHOOK"), OnShellEvent)

OnShellEvent(wParam, lParam, msg, hwnd) {
    static HSHELL_WINDOWACTIVATED := 4, HSHELL_RUDEAPPACTIVATED := 0x8004
    if (wParam != HSHELL_WINDOWACTIVATED && wParam != HSHELL_RUDEAPPACTIVATED)
        return
    try {
        if (WinGetProcessName("ahk_id " lParam) != "WindowsTerminal.exe")
            return
        ImeOff(lParam)
    }
}

ImeOff(hwnd) {
    static WM_IME_CONTROL := 0x283, IMC_SETOPENSTATUS := 0x006
    hIme := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if hIme
        SendMessage(WM_IME_CONTROL, IMC_SETOPENSTATUS, 0, , hIme)
}
#HotIf