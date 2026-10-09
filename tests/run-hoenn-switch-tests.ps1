param(
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Baseline,
    [switch]$LoggerInitFailure,
    [string]$AutoHotkey = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
)
$ErrorActionPreference = 'Stop'
$testDirectory = Join-Path $env:TEMP ('macro-switch-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDirectory | Out-Null
if ($LoggerInitFailure) {
    # Arquivo no lugar da pasta: DirCreate falha de verdade, sem alterar permissões.
    [IO.File]::WriteAllText((Join-Path $testDirectory 'session_logs'), 'blocked directory')
}

function Read-TestSource([string]$relativePath) {
    $source = Get-Content -LiteralPath (Join-Path $SourceRoot $relativePath) -Raw
    # Nunca carregar includes, hotkeys, polling ou a inicialização XInput do aplicativo.
    $source = [regex]::Replace($source, '(?m)^#.*\r?\n', '')
    return $source
}

$main = Read-TestSource 'main.ahk'
$main = $main.Substring($main.IndexOf('TrocarModo() {'))
$main = $main.Substring(0, $main.IndexOf('; --- HOTKEYS PARA TECLADO E MOUSE ---'))
$mapping = Read-TestSource 'src/mapeamento-controle.ahk'
$mapping = [regex]::Replace($mapping, '(?m)^\^Esc::.*\r?\n|^SetTimer\(GameLoop, 30\).*\r?\n', '')
$logger = Read-TestSource 'src/logger.ahk'
$logger = $logger.Replace('A_ScriptDir "\logs"', 'A_ScriptDir "\session_logs"')
$logger = $logger.Replace('A_Temp "\macro_switch_debug.log"', 'A_ScriptDir "\debug-init.log"')
$engine = Read-TestSource 'src/hoenn_engine.ahk'
$source = (Read-TestSource 'config.ahk') + "`n" + $logger + "`n" + (Read-TestSource 'src/core_actions.ahk') + "`n" + $engine + "`n" + $main + "`n" + $mapping

# Executar as funções de produção, substituindo apenas fronteiras de I/O e relógio.
$source = $source.Replace('GetHoenn222BaseTargetMs(state, timeIndex) {', 'RealBaseTarget(state, timeIndex) {')
$source = $source.Replace('LogTeamSwitch(newTeam, modo) {', 'RealTeamLogger(newTeam, modo) {')
$source = $source.Replace('AtualizarHoenn222CentralTooltip(text := "", x := 0, y := 0, color := "FFE033") {', 'RealCentralTooltip(text := "", x := 0, y := 0, color := "FFE033") {')
foreach ($entry in @{
    'ControlSend' = 'MockControlSend'; 'Sleep' = 'MockSleep'; 'WinExist' = 'MockWinExist';
    'WinActive' = 'MockWinExist'; 'WinGetPos' = 'MockWinGetPos'; 'ToolTip' = 'MockToolTip';
    'SetTimer' = 'MockSetTimer'; 'XInput_GetState' = 'MockXInput';
    'AtualizarHoenn222CentralTooltip' = 'MockCentralTooltip';
    'GetHoenn222BaseTargetMs' = 'MockBaseTarget'; 'LogTeamSwitch' = 'MockTeamLogger'
}.GetEnumerator()) {
    $source = [regex]::Replace($source, '\b' + $entry.Key + '\s*\(', $entry.Value + '(')
}
$source = $source.Replace('A_TickCount', 'MockTick')
if ($source -match '\bControlSend\s*\(' -or $source -match '(?m)^#Include\b') {
    throw 'Fonte de teste contém uma fronteira de envio/include não isolada.'
}
$mode = if ($Baseline) { 'true' } else { 'false' }
$initFailure = if ($LoggerInitFailure) { 'true' } else { 'false' }
$header = @"
#Requires AutoHotkey v2.0
global MockTick := 100000
global ModoAtual := "Hoenn222"
global comboMrMime := 0
global TestBaseline := $mode
global TestLoggerInitFailure := $initFailure
"@
$tests = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'hoenn-switch-tests.ahk') -Raw
if ($Baseline) {
    # A versão anterior não recebia o argumento opcional de origem do gatilho.
    $tests = [regex]::Replace($tests, 'Acao_Gatilhos\("[^"]*"\)', 'Acao_Gatilhos()')
    # Não analisar chamadas à nova função de interface ausente no código anterior.
    $tests = [regex]::Replace($tests, '(?s)RunTests\(\) \{.*?(?=RunBaseline\(\) \{)', "RunTests() {`n}`n")
}
# Todas as funções são analisadas antes do autoexecute; RunTests encerra o processo.
$script = "$header`n$source`n$tests"
$scriptPath = Join-Path $testDirectory 'isolated-tests.ahk'
[IO.File]::WriteAllText($scriptPath, $script, [Text.UTF8Encoding]::new($true))
$stdout = Join-Path $testDirectory 'stdout.txt'
$stderr = Join-Path $testDirectory 'stderr.txt'
$process = Start-Process -FilePath $AutoHotkey -ArgumentList @('/ErrorStdOut=UTF-8', ('"' + $scriptPath + '"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
# Sem manter o handle, ExitCode fica vazio no PowerShell 5.1 e um run verde seria dado como falha.
$null = $process.Handle
if (-not $process.WaitForExit(20000)) {
    $process.Kill()
    throw "Timeout nos testes isolados: $testDirectory"
}
$process.WaitForExit()
Get-Content -LiteralPath $stdout
Get-Content -LiteralPath $stderr
Write-Output "Artifacts: $testDirectory"
if ($process.ExitCode -ne 0) { throw "AutoHotkey test exit code: $($process.ExitCode)" }
