param(
    [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$AutoHotkey = 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'fontes.ps1')
Test-IndicesDeInclude $SourceRoot
$testDirectory = Join-Path $env:TEMP ('macro-config-startup-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDirectory | Out-Null
$config = Get-Content -LiteralPath (Join-Path $SourceRoot 'config.ahk') -Raw -Encoding UTF8
$modules = Read-ModulosJuntos $SourceRoot $script:Modulos {
    param($m)
    Get-Content -LiteralPath (Join-Path $SourceRoot $m) -Raw -Encoding UTF8
}
$modules = $modules.Replace('A_Temp "\macro_switch_debug.log"', 'A_ScriptDir "\boot-diagnostic.log"')
$modules = $modules.Replace('A_ScriptDir "\logs"', 'A_ScriptDir "\boot-logs"')
# Autoexecute real, sem includes, hotkeys, mutex real ou dispositivo conectado.
$entry = ((Get-Content -LiteralPath (Join-Path $SourceRoot 'main.ahk') -Raw -Encoding UTF8) -split '; --- ATALHOS')[0]
$entry = [regex]::Replace($entry, '(?m)^#.*\r?\n', '')
$entry = $entry.Replace('GarantirInstanciaUnica()', 'BootEntrada()').Replace('XInput_Init()', 'BootEntrada()').Replace('IniciarControle()', 'BootLoop()').Replace('MsgBox(', 'BootMensagem(')
$stubs = @'
#Requires AutoHotkey v2.0
#Warn All, StdOut
BootEntrada() {
    if !ConfigDeTempoValida
        throw Error("Config invalido chegou as entradas")
}
BootLoop() {
    if (ProblemasDeConfig.Length > 0 || !PlanoEmCache)
        throw Error("Inicializacao sem plano valido")
    FileAppend("BOOT_OK L=" Round(PlanoEmCache.L) "`n", "*", "UTF-8")
}
BootMensagem(texto) {
    if ConfigDeTempoValida
        throw Error("Erro inesperado na inicializacao: " texto)
    FileAppend("BOOT_REJECTED " texto "`n", "*", "UTF-8")
}
BootSemEntrada(*) {
    throw Error("Teste tentou entrada externa")
}
'@
$cases = @(
    @{ Name = 'valido'; Override = ''; Expected = 'BOOT_OK L=76300' },
    @{ Name = 'bloco-zero'; Override = 'Hoenn222_InBallBlockMs := 0'; Expected = 'Hoenn222_InBallBlockMs invalido: 0' },
    @{ Name = 'bloco-texto'; Override = 'Hoenn222_InBallBlockMs := "abc"'; Expected = 'Hoenn222_InBallBlockMs invalido: abc' },
    @{ Name = 'sleep-negativo'; Override = 'SleepAfterSwitch := -1'; Expected = 'SleepAfterSwitch invalido: -1' },
    @{ Name = 'cd-zero'; Override = 'Hoenn222_CdByTier["SR"] := 0'; Expected = "CD do tier 'SR' invalido: 0" },
    @{ Name = 'cd-texto'; Override = 'Hoenn222_CdByTier["UR"] := "abc"'; Expected = "CD do tier 'UR' invalido: abc" },
    @{ Name = 'taxas-iguais'; Override = 'Hoenn222_RateOutOfBall := Hoenn222_RateInBall'; Expected = 'RateOutOfBall deve ser maior que RateInBall' }
)
foreach ($case in $cases) {
    $source = "$stubs`r`n$config`r`n$($case.Override)`r`n$modules`r`n$entry`r`nExitApp(0)"
    $source = [regex]::Replace($source, '\b(ControlClick|ControlSend|XInput_GetState|SetTimer)\s*\(', 'BootSemEntrada(')
    $source = [regex]::Replace($source, "(?<!`r)`n", "`r`n")
    $path = Join-Path $testDirectory ($case.Name + '.ahk')
    [IO.File]::WriteAllText($path, $source, [Text.UTF8Encoding]::new($true))
    $stdout = Join-Path $testDirectory ($case.Name + '.txt')
    $stderr = $stdout + '.err'
    $process = Start-Process -FilePath $AutoHotkey -ArgumentList @('/ErrorStdOut=UTF-8', ('"' + $path + '"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $process.Handle
    if (-not $process.WaitForExit(10000)) {
        $process.Kill()
        throw "Timeout no boot isolado: $($case.Name)"
    }
    $process.WaitForExit()
    $output = ((Get-Content -LiteralPath $stdout -Raw -Encoding UTF8) + (Get-Content -LiteralPath $stderr -Raw -Encoding UTF8))
    $marker = if ($case.Override) { 'BOOT_REJECTED' } else { 'BOOT_OK' }
    if ($process.ExitCode -ne 0 -or !$output.Contains($marker) -or !$output.Contains($case.Expected) -or $output.Contains('Warning:')) {
        throw "Falha no boot $($case.Name): $output"
    }
    if ($case.Override -and $output.Contains('BOOT_OK')) { throw "Config invalido iniciou: $output" }
    Write-Output "PASS boot isolado: $($case.Name)"
}
Write-Output "Artifacts: $testDirectory"
