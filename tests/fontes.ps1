# Lista ordenada dos modulos de producao usada pelos runners de teste.
# Mantida em sincronia com os indices src/hoenn_engine.ahk e src/mapeamento-controle.ahk:
# Test-IndicesDeInclude falha se alguem adicionar um modulo e esquecer de listar aqui.
$script:ModulosMotor = @(
    'src/estado.ahk', 'src/cooldown.ahk', 'src/planejador.ahk', 'src/cronometro.ahk',
    'src/troca_time.ahk', 'src/combos.ahk', 'src/antecipacao.ahk',
    'src/antecipacao_combo.ahk', 'src/antecipacao_troca.ahk'
)
$script:ModulosInterface = @('src/indicador.ahk', 'src/controle.ahk')

function Test-IndicesDeInclude([string]$SourceRoot) {
    $verificar = @(
        @{ Arquivo = 'src/hoenn_engine.ahk'; Esperado = (@('core_actions.ahk', 'logger.ahk') + ($script:ModulosMotor | ForEach-Object { Split-Path $_ -Leaf })) },
        @{ Arquivo = 'src/mapeamento-controle.ahk'; Esperado = ($script:ModulosInterface | ForEach-Object { Split-Path $_ -Leaf }) }
    )
    foreach ($v in $verificar) {
        $texto = Get-Content -LiteralPath (Join-Path $SourceRoot $v.Arquivo) -Raw -Encoding UTF8
        $reais = [regex]::Matches($texto, '(?m)^#Include\s+(\S+)') | ForEach-Object { $_.Groups[1].Value }
        if (($reais -join '|') -ne ($v.Esperado -join '|')) {
            throw "Indice $($v.Arquivo) fora de sincronia com tests/fontes.ps1.`n  includes: $($reais -join ', ')`n  esperado: $($v.Esperado -join ', ')"
        }
    }
}

function Read-ModulosJuntos([string]$SourceRoot, [string[]]$Modulos, [scriptblock]$Leitor) {
    $partes = foreach ($m in $Modulos) { & $Leitor $m }
    return ($partes -join "`r`n")
}