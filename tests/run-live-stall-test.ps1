# Teste do CONGELAMENTO do laco de movimento durante uma acao armada.
#
# Os testes isolados (run-hoenn-switch-tests.ps1) simulam SetTimer e Sleep, entao nao
# enxergam este defeito: ele so existe com timers e relogio REAIS. Aqui o codigo de
# producao roda com SetTimer, Sleep e A_TickCount reais; so o envio de teclas, a janela
# do jogo e o XInput sao simulados, e cada chamada do laco ganha um custo de 20 ms para
# imitar ControlSend/WinExist/ToolTip reais (e isso que leva o AutoHotkey a checar a fila
# de mensagens no meio do laco).
#
# Cenarios: combo armado disparando no verde e troca armada disparando no verde.
# Falha (exit 1) se o laco de 30 ms ficar parado mais que $LimiteMs.
param(
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$AutoHotkey = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe',
    [int]$LimiteMs = 400
)
$ErrorActionPreference = 'Stop'

function Read-TestSource([string]$relativePath) {
    $source = Get-Content -LiteralPath (Join-Path $SourceRoot $relativePath) -Raw -Encoding UTF8
    $source = [regex]::Replace($source, '(?m)^#.*\r?\n', '')
    return ([regex]::Replace($source, "(?<!`r)`n", "`r`n"))
}

$main = Read-TestSource 'main.ahk'
$main = $main.Substring($main.IndexOf('TrocarModo() {'))
$main = $main.Substring(0, $main.IndexOf('; --- HOTKEYS PARA TECLADO E MOUSE ---'))
$mapping = Read-TestSource 'src/mapeamento-controle.ahk'
$mapping = [regex]::Replace($mapping, '(?m)^\^Esc::.*\r?\n|^SetTimer\(GameLoop, 30\).*\r?\n', '')
$logger = Read-TestSource 'src/logger.ahk'
$engine = Read-TestSource 'src/hoenn_engine.ahk'
$source = (Read-TestSource 'config.ahk') + "`r`n" + $logger + "`r`n" + (Read-TestSource 'src/core_actions.ahk') + "`r`n" + $engine + "`r`n" + $main + "`r`n" + $mapping

# Mesmas fronteiras de I/O do runner isolado, MENOS SetTimer, Sleep e A_TickCount.
$source = $source.Replace('GetHoenn222BaseTargetMs(state, timeIndex) {', 'RealBaseTarget(state, timeIndex) {')
$source = $source.Replace('LogTeamSwitch(newTeam, modo) {', 'RealTeamLogger(newTeam, modo) {')
foreach ($entry in @{
    'ControlSend' = 'MockControlSend'; 'WinExist' = 'MockWinExist'; 'WinActive' = 'MockWinExist';
    'WinGetPos' = 'MockWinGetPos'; 'XInput_GetState' = 'MockXInput';
    'GetHoenn222BaseTargetMs' = 'MockBaseTarget'; 'LogTeamSwitch' = 'MockTeamLogger'
}.GetEnumerator()) {
    $source = [regex]::Replace($source, '\b' + $entry.Key + '\s*\(', $entry.Value + '(')
}

$header = @"
#Requires AutoHotkey v2.0
global MockTick := 100000
global ModoAtual := "Hoenn222"
global comboMrMime := 0
global GameLoopTicks := []
global Scenario := A_Args[1]
Persistent()
SetTimer(Run, -1)

MockControlSend(*) {
}
MockWinExist(*) {
    return 123
}
MockWinGetPos(&x := unset, &y := unset, &width := unset, &height := unset, *) {
    ; custo de uma chamada real; espera Win32 que nao processa mensagens do AutoHotkey
    DllCall("Sleep", "UInt", 20)
    x := 10
    y := 20
    width := 13
    height := 18
}
MockXInput(*) {
    global GameLoopTicks
    GameLoopTicks.Push(A_TickCount)
    return {bRightTrigger: 0, bLeftTrigger: 0, wButtons: 0, sThumbLX: 0, sThumbLY: 0, sThumbRX: 0, sThumbRY: 0}
}
MockBaseTarget(state, team) {
    return RealBaseTarget(state, team)
}
MockTeamLogger(team, mode) {
    RealTeamLogger(team, mode)
}
Log(s) {
    FileAppend(s "``n", "*", "UTF-8")
}
Run() {
    global
    SwitchDebugFile := A_Temp "\macro-live-stall-" Scenario ".log"
    if FileExist(SwitchDebugFile)
        FileDelete(SwitchDebugFile)
    Hoenn222_TeamCasted := Map(1, false, 2, false, 3, false)
    ResetarCooldownsHoenn222(A_TickCount)
    if (Scenario = "combo") {
        ; ritmo da 1a volta libera o COMBAR em ~1,5 s; o pedido fica armado
        Hoenn222_State := "WAITING_COMBO"
        Hoenn222_StateStartTick := A_TickCount - (PlanHoenn222().Lures[1] - 1500)
        SolicitarComboHoenn222()
    } else {
        ; TROCAR TIME a ~1,5 s do verde; o gatilho fica armado
        Hoenn222_State := "WAITING_TEAM_SWITCH"
        Hoenn222_StateStartTick := A_TickCount - (GetHoenn222SwitchTargetMs(1) - 1500)
        Hoenn222_TeamCasted := Map(1, true, 2, true, 3, true)
        Acao_Gatilhos("controller")
    }
    SetTimer(GameLoop, 30)
    SetTimer(Fim, -10000)
}
Fim() {
    global GameLoopTicks, SwitchDebugFile, Scenario
    maxg := 0
    for i, t in GameLoopTicks {
        if (i > 1 && t - GameLoopTicks[i - 1] > maxg)
            maxg := t - GameLoopTicks[i - 1]
    }
    texto := FileExist(SwitchDebugFile) ? FileRead(SwitchDebugFile) : ""
    disparou := InStr(texto, "COMBO_FIRED") || InStr(texto, "SWITCH_FIRED")
    Log(Scenario "|" maxg "|" GameLoopTicks.Length "|" (disparou ? 1 : 0))
    ExitApp(0)
}
"@

$falhou = $false
foreach ($cenario in 'combo', 'troca') {
    $dir = Join-Path $env:TEMP ('macro-live-stall-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $script = [regex]::Replace("$header`r`n$source", "(?<!`r)`n", "`r`n")
    $path = Join-Path $dir 'live.ahk'
    [IO.File]::WriteAllText($path, $script, [Text.UTF8Encoding]::new($true))
    $stdout = Join-Path $dir 'stdout.txt'
    $stderr = Join-Path $dir 'stderr.txt'
    $p = Start-Process -FilePath $AutoHotkey -ArgumentList @('/ErrorStdOut=UTF-8', ('"' + $path + '"'), $cenario) `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $p.Handle
    if (-not $p.WaitForExit(30000)) { $p.Kill(); throw "Timeout no cenario $cenario ($dir)" }
    $p.WaitForExit()
    $linha = (Get-Content -LiteralPath $stdout | Where-Object { $_ -match '^\w+\|' } | Select-Object -Last 1)
    $err = Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue
    if (-not $linha) { throw "Sem resultado no cenario $cenario. stderr: $err (ver $dir)" }
    $c, $maxg, $exec, $disparou = $linha.Split('|')
    $ok = ([int]$maxg -le $LimiteMs) -and ($disparou -eq '1')
    $status = if ($ok) { 'PASS' } else { 'FAIL' }
    Write-Output ("{0} {1}: laco parado no maximo {2} ms ({3} execucoes), acao armada disparou={4}" -f $status, $c, $maxg, $exec, $disparou)
    if (-not $ok) { $falhou = $true }
}
if ($falhou) { throw "Laco de movimento congelou durante uma acao armada (limite $LimiteMs ms)" }
Write-Output "RESULT: laco de movimento nao congela durante acoes armadas"
