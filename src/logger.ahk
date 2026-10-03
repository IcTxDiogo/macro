#Requires AutoHotkey v2.0

global LogFolder := A_ScriptDir "\logs"

if !DirExist(LogFolder) {
    DirCreate(LogFolder)
}

global CurrentSessionLogFile := LogFolder "\farm_log_" FormatTime(, "yyyy-MM-dd_HH-mm-ss") ".txt"

LogAction(message) {
    global CurrentSessionLogFile
    currentTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    
    FileAppend(currentTime " | " message "`n", CurrentSessionLogFile)
}

global StartComboTick := 0
global CurrentLogTime := 0

LogComboStart(timeNum, modo) {
    global StartComboTick, CurrentLogTime
    StartComboTick := A_TickCount
    CurrentLogTime := timeNum
    LogAction("COMBO START | Modo: " modo " | Time: " timeNum)
}

LogTeamSwitch(newTeam, modo) {
    global StartComboTick, CurrentLogTime
    
    if (StartComboTick > 0) {
        elapsedSec := Round((A_TickCount - StartComboTick) / 1000, 2)
        LogAction("TEAM END    | Tempo pos-combo (Time " CurrentLogTime "): " elapsedSec "s")
        StartComboTick := 0
    }
    
    LogAction("TEAM SWITCH | Entrando Time: " newTeam)
}
