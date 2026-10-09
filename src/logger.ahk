#Requires AutoHotkey v2.0

global LogFolder := A_ScriptDir "\logs"

; Diagnóstico temporário e independente do logger de sessões.
global SwitchDebugEnabled := true
global SwitchDebugFile := A_Temp "\macro_switch_debug.log"

SwitchDebug(event, details := "", err := 0) {
    global SwitchDebugEnabled, SwitchDebugFile
    try {
        if !SwitchDebugEnabled
            return
        if IsObject(err) {
            details .= " message=" err.Message " function=" err.What " line=" err.Line " file=" err.File
        }
        details := StrReplace(StrReplace(details, "`r", " "), "`n", " ")
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " tick=" A_TickCount " pid=" ProcessExist()
            " | " event " | " details "`n", SwitchDebugFile, "UTF-8")
    } catch {
        ; Nem arquivo indisponível, nem formatação do diagnóstico podem bloquear comandos.
    }
}

try {
    if !DirExist(LogFolder)
        DirCreate(LogFolder)
} catch as e {
    SwitchDebug("SWITCH_ERROR", "phase=logger_init", e)
}

global CurrentSessionLogFile := LogFolder "\farm_log_" FormatTime(, "yyyy-MM-dd_HH-mm-ss") ".txt"

LogAction(message) {
    global CurrentSessionLogFile
    try {
        currentTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        FileAppend(currentTime " | " message "`n", CurrentSessionLogFile)
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=session_logger", e)
    }
}

global StartComboTick := 0
global CurrentLogTime := 0

LogComboStart(timeNum, modo, origem := "manual") {
    global StartComboTick, CurrentLogTime
    StartComboTick := A_TickCount
    CurrentLogTime := timeNum
    LogAction("COMBO START | Modo: " modo " | Time: " timeNum " | Origem: " origem)
}

LogTeamSwitch(newTeam, modo) {
    global StartComboTick, CurrentLogTime

    if (StartComboTick > 0) {
        elapsedSec := Round((A_TickCount - StartComboTick) / 1000, 2)
        LogAction("TEAM END    | Tempo pos-combo (Time " CurrentLogTime "): " elapsedSec "s")
        StartComboTick := 0
    }

    LogAction("TEAM SWITCH | Solicitado Time: " newTeam " | Entrada visual: nao confirmada")
}
