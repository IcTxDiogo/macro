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
. (Join-Path $PSScriptRoot 'fontes.ps1')
Test-IndicesDeInclude $SourceRoot
Test-CamadaTempo $SourceRoot

function Read-TestSource([string]$relativePath) {
    $source = Get-Content -LiteralPath (Join-Path $SourceRoot $relativePath) -Raw -Encoding UTF8
    $source = [regex]::Replace($source, '(?m)^#.*\r?\n', '')
    return ([regex]::Replace($source, "(?<!`r)`n", "`r`n"))
}

$modulos = Read-ModulosJuntos $SourceRoot $script:Modulos { param($m) Read-TestSource $m }
$source = (Read-TestSource 'config.ahk') + "`r`n" + $modulos

# Mesmas fronteiras de I/O do runner isolado, MENOS SetTimer, Sleep e A_TickCount.
$source = [regex]::Replace($source, '(?m)^AlvoDaFaseMs\(', 'RealBaseTarget(')
$source = [regex]::Replace($source, '(?m)^RegistrarTrocaNoLog\(', 'RealTeamLogger(')
foreach ($entry in @{
    'ControlClick' = 'MockControlClick'; 'ControlSend' = 'MockControlSend'; 'WinExist' = 'MockWinExist'; 'WinActive' = 'MockWinExist';
    'WinGetPos' = 'MockWinGetPos'; 'XInput_GetState' = 'MockXInput';
    'AlvoDaFaseMs' = 'MockBaseTarget'; 'RegistrarTrocaNoLog' = 'MockTeamLogger'
}.GetEnumerator()) {
    $source = [regex]::Replace($source, '\b' + $entry.Key + '\s*\(', $entry.Value + '(')
}

$header = @"
#Requires AutoHotkey v2.0
global MockTick := 100000
global GameLoopTicks := []
global Scenario := A_Args[1]
global DailyClicks := 0
Persistent()
SetTimer(Run, -1)

MockControlSend(*) {
}
MockControlClick(*) {
    global DailyClicks
    DailyClicks++
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
    return {bRightTrigger: 0, bLeftTrigger: 0, wButtons: Scenario = "daily" ? 0x4000 : 0, sThumbLX: 0, sThumbLY: 0, sThumbRX: 0, sThumbRY: 0}
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
    ArquivoDiagnostico := A_Temp "\macro-live-stall-" Scenario ".log"
    if FileExist(ArquivoDiagnostico)
        FileDelete(ArquivoDiagnostico)
    TankJaCastou := Map(1, false, 2, false, 3, false)
    ResetarCooldowns(A_TickCount)
    if (Scenario = "daily") {
        GuildDailyRenewPos := {X: 318, Y: 205}
        GuildDailyConfirmPos := {X: 747, Y: 455}
        GuildDailyConfirmDelayMs := 600
    } else if (Scenario = "combo") {
        ; ritmo da 1a volta libera o COMBAR em ~1,5 s; o pedido fica armado
        FaseAtual := "WAITING_COMBO"
        InicioDaFaseTick := A_TickCount - (PlanejarVolta().Lures[1] - 1500)
        PedirCombo()
    } else {
        ; TROCAR TIME a ~1,5 s do verde; o gatilho fica armado
        FaseAtual := "WAITING_TEAM_SWITCH"
        InicioDaFaseTick := A_TickCount - (DuracaoDoTrocarTimeMs(1) - 1500)
        TankJaCastou := Map(1, true, 2, true, 3, true)
        AcaoBumpers("controller")
    }
    SetTimer(GameLoop, 30)
    SetTimer(Fim, -10000)
}
Fim() {
    global GameLoopTicks, ArquivoDiagnostico, Scenario
    maxg := 0
    for i, t in GameLoopTicks {
        if (i > 1 && t - GameLoopTicks[i - 1] > maxg)
            maxg := t - GameLoopTicks[i - 1]
    }
    texto := FileExist(ArquivoDiagnostico) ? FileRead(ArquivoDiagnostico) : ""
    disparou := InStr(texto, "COMBO_FIRED") || InStr(texto, "SWITCH_FIRED")
    if (Scenario = "daily")
        disparou := DailyClicks == 2 && !RenovacaoDailyAtiva
    Log(Scenario "|" maxg "|" GameLoopTicks.Length "|" (disparou ? 1 : 0))
    ExitApp(0)
}
"@

$falhou = $false
foreach ($cenario in 'combo', 'troca', 'daily') {
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
