# Lista ordenada dos modulos de producao usada pelos runners de teste.
# Mantida em sincronia com src/indice.ahk: Test-IndicesDeInclude falha se alguem
# adicionar, remover ou reordenar um modulo e esquecer de atualizar uma das duas.
$script:Modulos = @(
    'src/nucleo/logger.ahk', 'src/nucleo/validacao_config.ahk', 'src/nucleo/estado.ahk',
    'src/tempo/cooldown.ahk', 'src/tempo/planejador.ahk', 'src/tempo/cronometro.ahk',
    'src/macro/teclas.ahk', 'src/macro/troca_time.ahk',
    'src/macro/rodizio_222.ahk', 'src/macro/antecipacao.ahk',
    'src/macro/antecipacao_combo.ahk', 'src/macro/antecipacao_troca.ahk',
    'src/macro/modos.ahk', 'src/macro/acoes.ahk',
    'src/interface/quadrado_central.ahk', 'src/interface/painel.ahk', 'src/interface/controle.ahk'
)

function Test-IndicesDeInclude([string]$SourceRoot) {
    $texto = Get-Content -LiteralPath (Join-Path $SourceRoot 'src/indice.ahk') -Raw -Encoding UTF8
    $reais = [regex]::Matches($texto, '(?m)^#Include\s+(\S+)') | ForEach-Object { 'src/' + ($_.Groups[1].Value -replace '\\', '/') }
    if (($reais -join '|') -ne ($script:Modulos -join '|')) {
        throw "src/indice.ahk fora de sincronia com tests/fontes.ps1.`n  includes: $($reais -join ', ')`n  esperado: $($script:Modulos -join ', ')"
    }
    # Nenhum .ahk em src/ pode ficar de fora do indice (modulo orfao nunca carregado nem testado).
    $emDisco = Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'src') -Recurse -Filter *.ahk |
        ForEach-Object { 'src/' + ($_.FullName.Substring((Join-Path $SourceRoot 'src').Length + 1) -replace '\\', '/') } |
        Where-Object { $_ -ne 'src/indice.ahk' }
    $orfaos = $emDisco | Where-Object { $script:Modulos -notcontains $_ }
    if ($orfaos) { throw "Modulos fora do indice: $($orfaos -join ', ')" }
}

# A camada de tempo (src/tempo) decide QUANDO liberar; nunca envia tecla, nem toca na
# janela, na interface ou em timers. Quebrar isso mistura controle de tempo com macro.
function Test-CamadaTempo([string]$SourceRoot) {
    $proibidos = '\b(ControlSend|Send|SendInput|SendEvent|WinExist|WinActive|WinGetPos|ToolTip|SetTimer|Sleep|MouseMove|XInput_GetState)\s*\('
    foreach ($arquivo in Get-ChildItem -LiteralPath (Join-Path $SourceRoot 'src/tempo') -Filter *.ahk) {
        $codigo = (Get-Content -LiteralPath $arquivo.FullName -Raw -Encoding UTF8) -replace '(?m)^\s*;.*$', ''
        $codigo = $codigo -replace '(?m)(?<=\s);.*$', ''
        $achados = [regex]::Matches($codigo, $proibidos) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        if ($achados) { throw "src/tempo/$($arquivo.Name) usa funcao de macro/interface: $($achados -join ', ')" }
    }
}

# Carrega o main.ahk de verdade (todos os includes e a sintaxe) SEM executar: /validate nao
# roda o autoexecute, entao nao le o gamepad nem envia tecla ao jogo.
function Test-MainCarrega([string]$SourceRoot, [string]$AutoHotkey) {
    $saida = Join-Path $env:TEMP ('macro-validate-' + [guid]::NewGuid().ToString('N') + '.txt')
    $p = Start-Process -FilePath $AutoHotkey -ArgumentList @('/ErrorStdOut=UTF-8', '/validate', ('"' + (Join-Path $SourceRoot 'main.ahk') + '"')) `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $saida -RedirectStandardError ($saida + ".err")
    $null = $p.Handle
    if (-not $p.WaitForExit(20000)) { $p.Kill(); throw 'Timeout validando main.ahk' }
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { throw ("main.ahk nao carrega (exit " + $p.ExitCode + "): " + ((@(Get-Content -LiteralPath $saida -ErrorAction SilentlyContinue) + @(Get-Content -LiteralPath ($saida + ".err") -ErrorAction SilentlyContinue)) -join ' ')) }
}

function Read-ModulosJuntos([string]$SourceRoot, [string[]]$Modulos, [scriptblock]$Leitor) {
    $partes = foreach ($m in $Modulos) { & $Leitor $m }
    return ($partes -join "`r`n")
}
