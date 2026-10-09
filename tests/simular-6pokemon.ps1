# =============================================================================
# SIMULADOR INDEPENDENTE - Hoenn 2-2-2, seis Pokemon, tres duplas
# =============================================================================
# Nao importa nenhuma formula do planejador. Reconstroi os seis cooldowns por
# uma linha do tempo explicita de eventos, aplicando 1,0x fora da Ball e 0,5x
# dentro. E o simulador que define a verdade: o menor L aceitavel e achado por
# busca binaria sobre as invariantes, nao por algebra.
#
# ESTRUTURA DA JANELA de uma dupla (dura w, comeca na troca de time):
#   t=0        tank sai da Ball (1,0x); secundario ainda na Ball (0,5x)
#   lure       tank em campo antes do combo. O CD dele ainda nao comecou, entao
#              este tempo NAO recupera o CD do proprio tank.
#   T0         tank faz o cast; CD passa a contar em T0 + Latencia
#   T0+Lat .. T0+P     tank fora a 1,0x -> (P - Latencia) de recuperacao real
#   T0+P       p2 chamado: tank VOLTA para a Ball, secundario sai (1,0x)
#   T2=T0+P+GAP secundario faz o cast; CD conta a partir de T2 + Latencia
#   ate w      secundario fora a 1,0x
#   w          proxima troca de time
#
# INVARIANTES
#   I1  no maximo um Pokemon fora da Ball por instante
#   I2  nenhum cooldown negativo nem recarga acima de zero
#   I3  o CD so conta a partir de cast + Latencia
#   I4  um unico credito de taxa por slot por intervalo
#   I5  recuperacao conjunta <= 3,5x o tempo
#   I6  nenhum cast com CD pendente acima da margem
# =============================================================================

$script:Vcd = @{}; $script:Vrate = @{}; $script:VT = 0.0
$script:Vfrz = @{}; $script:Vviol = $null; $script:Vcasts = $null
$script:Lat = 250.0; $script:Marg = 250.0
$script:Sp = 2700.0; $script:Sg = 800.0; $script:So = 3000.0

function St-Step([double]$t1) {
    $dt = $t1 - $script:VT
    if ($dt -lt 0) { throw 'tempo retrocedeu' }
    if ($dt -eq 0) { return }
    $out = 0
    for ($i = 1; $i -le 6; $i++) { if ($script:Vrate[$i] -ge 1.0) { $out++ } }
    if ($out -gt 1) {
        [void]$script:Vviol.Add(('I1 em {0}ms: {1} fora da Ball' -f [math]::Round($script:VT, 0), $out))
    }
    if ($out -gt 0) {
        $cap = $out + (6 - $out) * 0.5
        if ($cap -gt 3.500001) {
            [void]$script:Vviol.Add(('I5 em {0}ms: capacidade {1}' -f [math]::Round($script:VT, 0), $cap))
        }
    }
    for ($i = 1; $i -le 6; $i++) {
        if ($script:Vcd[$i] -le 0) { continue }
        $ini = [math]::Max($script:VT, $script:Vfrz[$i])     # I3
        $eff = $t1 - $ini
        if ($eff -le 0) { continue }
        $v = $script:Vcd[$i] - $eff * $script:Vrate[$i]        # I4
        if ($v -lt 0) { $v = 0.0 }                             # I2
        $script:Vcd[$i] = $v
    }
    $script:VT = $t1
}

function St-Out([int]$i, [bool]$fora, [double]$now) {
    St-Step $now
    $script:Vrate[$i] = if ($fora) { 1.0 } else { 0.5 }
}

function St-Cast([int]$i, [double]$cdMain, [double]$now, [string]$papel, [int]$lap) {
    St-Step $now
    $antes = $script:Vcd[$i]
    if ($antes -gt $script:Marg + 0.5) {
        [void]$script:Vviol.Add(('I6 v{0} {1} s{2}: CD={3}ms > margem {4}' -f $lap, $papel, $i, [math]::Round($antes, 0), $script:Marg))
    }
    [void]$script:Vcasts.Add([pscustomobject]@{
            Volta = $lap; T = [math]::Round($now, 0); Slot = $i; Papel = $papel
            CdRestante = [math]::Round($antes, 0); CdPrincipal = $cdMain
        })
    $script:Vrate[$i] = 1.0
    $script:Vcd[$i] = $cdMain
    $script:Vfrz[$i] = $now + $script:Lat
}

function Simular {
    param([double[]]$Cd, [double]$Lap, [int]$Laps = 20,
        [double]$AtrasoCombo = 0, [double]$AtrasoTroca = 0)
    $script:Vcd = @{}; $script:Vrate = @{}; $script:Vfrz = @{}
    for ($i = 1; $i -le 6; $i++) { $script:Vcd[$i] = 0.0; $script:Vrate[$i] = 0.5; $script:Vfrz[$i] = 0.0 }
    $script:VT = 0.0
    $script:Vviol = New-Object System.Collections.ArrayList
    $script:Vcasts = New-Object System.Collections.ArrayList

    # Janela w = lure + P + B. O lure e folga do jogador; o otimizador o deixa
    # em zero, que e o caso restritivo. Logo B = w - P.
    $wLap = $Lap / 3.0
    $w = $wLap
    $maxB = $w - $script:Sp
    $lure = 0.0
    if ($maxB -lt ($script:Sg + $script:So)) {
        [void]$script:Vviol.Add("janela insuficiente: secundario fora $([math]::Round($maxB,0))ms < $($script:Sg + $script:So)")
    }

    $lapTimes = @()
    for ($lap = 0; $lap -lt $Laps; $lap++) {
        $ls = $script:VT
        for ($k = 0; $k -lt 3; $k++) {
            $tk = 2 * $k + 1; $sc = 2 * $k + 2
            $ws = $script:VT
            St-Out $tk $true $ws
            St-Out $sc $false $ws
            if ($lure -lt 0) {
                [void]$script:Vviol.Add("janela insuficiente: lure=$([math]::Round($lure,0))ms")
                $lure = 0
            }
            # O jogador demora mais para terminar o lure: o tank continua em
            # campo e esse tempo todo conta como recuperacao real. O atraso
            # NAO pode empurrar o combo para fora da janela, entao ele consome
            # o lure disponivel em vez de somar a janela.
            # Atraso no combo consome o lure disponivel na janela; nao empurra
            # o combo para fora dela. Se for maior que o lure, o macro
            # aceita a janela mais longa em vez de forcar o cast.
            $orcamento = $wLap + $AtrasoTroca - $script:Sp
            $lureEfetivo = $lure + $AtrasoCombo
            $atrasoReal = 0.0
            if ($lureEfetivo -gt $orcamento) {
                $atrasoReal = $lureEfetivo - $orcamento
                $lureEfetivo = $orcamento
            }
            $T0 = $ws + $lureEfetivo
            St-Cast $tk $Cd[2 * $k] $T0 "tank" $lap
            $tp2 = $T0 + $script:Sp
            St-Out $tk $false $tp2        # tank volta a Ball
            St-Out $sc $true  $tp2        # secundario sai
            $T2 = $tp2 + $script:Sg
            St-Cast $sc $Cd[2 * $k + 1] $T2 "sec" $lap
            # Fim da janela: quando a proxima troca acontece. O secundario fica
            # fora de tp2 ate la.
            $tend = $ws + $wLap + $AtrasoTroca + $atrasoReal
            if ($tend -lt $T2) { $tend = $T2 }
            St-Step $tend
            St-Out $sc $false $tend
            # Atraso na troca: o secundario continua fora mais tempo, o que e
            # recuperacao real. Um atraso maior que o previsto alonga a volta
            # em vez de forcar o cast com CD pendente.
            $proxTroca = $ws + $wLap + $AtrasoTroca + $atrasoReal
            if ($script:VT -lt $proxTroca) { St-Step $proxTroca }
        }
        # A volta e exatamente 3 janelas: o relogio pode ter ficado atras.
        $lapTimes += ($script:VT - $ls)
    }
    $tail = $lapTimes | Select-Object -Last ([math]::Min(5, $lapTimes.Count))
    return @{
        Mean = ($tail | Measure-Object -Average).Average
        Viol = $script:Vviol; Casts = $script:Vcasts; Laps = $lapTimes
        Pior = ($script:Vcasts | Measure-Object -Property CdRestante -Maximum).Maximum
        JanelaSec = $maxB; Lure = $lure
    }
}

function MenorL([double[]]$Cd, [int]$Laps = 8) {
    $lo = ($script:Sp + $script:Sg) * 3.0
    $hi = 400000.0
    if ((Simular -Cd $Cd -Lap $hi -Laps $Laps).Viol.Count -gt 0) { return $null }
    for ($i = 0; $i -lt 40; $i++) {
        $mid = ($lo + $hi) / 2
        if ((Simular -Cd $Cd -Lap $mid -Laps $Laps).Viol.Count -eq 0) { $hi = $mid } else { $lo = $mid }
    }
    return $hi
}

# ---------------------------------------------------------------------------
$TODOS = [ordered]@{
    'PRINCIPAL  SR45/Lend40, SR45/UR43, SR45/UR43' = @(45000, 40000, 45000, 43000, 45000, 43000)
    'CONFIG     Lend40/UR43, UR43/UR43, UR43/UR43' = @(40000, 43000, 43000, 43000, 43000, 43000)
    'TODOS 45s' = @(45000, 45000, 45000, 45000, 45000, 45000)
    'TANKS 50s  50/40, 50/43, 50/43' = @(50000, 40000, 50000, 43000, 50000, 43000)
    'LENDARIOS  40/40, 40/43, 40/45' = @(40000, 40000, 40000, 43000, 40000, 45000)
    'MISTURADO  45/40, 43/45, 43/50' = @(45000, 40000, 43000, 45000, 43000, 50000)
}

$W = 78
Write-Output ('#' * $W)
Write-Output '# 1. MENOR VOLTA SUSTENTAVEL - busca binaria sobre o simulador'
Write-Output ('#' * $W)
Write-Output ('{0,-50} {1,10} {2,12} {3,12}' -f 'composicao', 'soma CD', 'piso 3,5x', 'MENOR L')
foreach ($nome in $TODOS.Keys) {
    $cdv = $TODOS[$nome]
    $S = ($cdv | Measure-Object -Sum).Sum
    $ml = MenorL $cdv
    Write-Output ('{0,-50} {1,10:N0} {2,12:N3} {3,12:N3}' -f $nome, $S, ($S / 3.5), ($ml / 1000))
}

Write-Output ''
Write-Output ('#' * $W)
Write-Output '# 2. CONFIRMACAO: 20 e 200 voltas no L minimo'
Write-Output ('#' * $W)
foreach ($nome in $TODOS.Keys) {
    $cdv = $TODOS[$nome]
    $ml = MenorL $cdv
    $r20 = Simular -Cd $cdv -Lap $ml -Laps 20
    $r200 = Simular -Cd $cdv -Lap $ml -Laps 200
    $p5 = ($r200.Laps | Select-Object -First 5 | Measure-Object -Average).Average
    $pf = ($r200.Laps | Select-Object -Last 5 | Measure-Object -Average).Average
    Write-Output ('{0}' -f $nome)
    Write-Output ('   L = {0:N3}s | janela/sec fora {1:N3}s | lure {2:N0}ms' -f ($ml / 1000), ($r20.JanelaSec / 1000), $r20.Lure)
    Write-Output ('   20 voltas {0:N3}s | 200 voltas 5 primeiras {1:N3}s 5 ultimas {2:N3}s' -f ($r20.Mean / 1000), ($p5 / 1000), ($pf / 1000))
    Write-Output ('   casts {0} | violacoes {1} | maior CD no cast {2}ms' -f $r20.Casts.Count, $r20.Viol.Count, $r20.Pior)
}

Write-Output ''
Write-Output ('#' * $W)
Write-Output '# 3. O PLANO ANTIGO ERA INVIÁVEL? (composicao CONFIG)'
Write-Output ('#' * $W)
$cdv = $TODOS['CONFIG     Lend40/UR43, UR43/UR43, UR43/UR43']
$ml = MenorL $cdv
Write-Output ('   menor L aceitavel = {0:N3}s | plano antigo = 67,462s | macro anterior = 86,500s' -f ($ml / 1000))
foreach ($teste in @(@{ N = 'plano antigo 67,462s'; L = 67462.5 }, @{ N = 'macro anterior 86,500s'; L = 86500.0 })) {
    $r = Simular -Cd $cdv -Lap $teste.L -Laps 3
    Write-Output ('   {0}: {1} violacoes em {2} casts | maior CD pendente {3}ms' -f $teste.N, $r.Viol.Count, $r.Casts.Count, $r.Pior)
    $r.Casts | Select-Object -First 4 | ForEach-Object {
        Write-Output ('      v{0} {1} s{2}: CD restante {3}ms de um CD principal de {4}ms' -f $_.Volta, $_.Papel, $_.Slot, $_.CdRestante, $_.CdPrincipal)
    }
}

Write-Output ''
Write-Output ('#' * $W)
Write-Output '# 4. SENSIBILIDADE A MARGEM E A LATENCIA'
Write-Output ('#' * $W)
foreach ($m in @(0, 250, 500, 1000)) { $script:Marg = [double]$m; Write-Output ('   margem   {0,5}ms -> menor L {1,8:N3}s' -f $m, ((MenorL $cdv) / 1000)) }
$script:Marg = 250.0
foreach ($l in @(0, 250, 500, 1000)) { $script:Lat = [double]$l; Write-Output ('   latencia {0,5}ms -> menor L {1,8:N3}s' -f $l, ((MenorL $cdv) / 1000)) }
$script:Lat = 250.0

Write-Output ''
Write-Output ('#' * $W)
Write-Output '# 5. SENSIBILIDADE AO TEMPO POS-CAST DO TANK'
Write-Output ('#' * $W)
foreach ($p in @(2700, 4000, 6000, 8000, 12000)) { $script:Sp = [double]$p; Write-Output ('   pos-cast {0,6}ms -> menor L {1,8:N3}s' -f $p, ((MenorL $cdv) / 1000)) }
$script:Sp = 2700.0

Write-Output ''
Write-Output ('#' * $W)
Write-Output '# 7. CRUZAMENTO: a formula fechada do planejador AHK vs o simulador'
Write-Output ('#' * $W)
Write-Output '#    planejador: L >= 2*CD_tank + 4*Lat + 2*Margem - P'
foreach ($nome in $TODOS.Keys) {
    $cdv = $TODOS[$nome]
    $Lt = 0.0
    for ($k = 0; $k -lt 3; $k++) {
        $x = 2 * $cdv[2 * $k] + 4 * $script:Lat + 2 * $script:Marg - $script:Sp
        if ($x -gt $Lt) { $Lt = $x }
    }
    # e o piso dos secundarios: menor L com soma(janelas) <= L
    $minJan = $script:Sp + $script:Sg + $script:So
    $lo = $minJan * 3; $hi = [math]::Max($Lt, $lo) * 2 + $lo
    while ($lo -lt $hi) {
        $meio = ($lo + $hi) / 2; $tot = 0.0
        for ($k = 0; $k -lt 3; $k++) { $tot += [math]::Max($minJan, 2 * ($cdv[2 * $k + 1] + $script:Marg) - $meio + $script:Sp) }
        if ($tot -le $meio) { $hi = $meio } else { $lo = $meio + 1 }
    }
    if ($lo -gt $Lt) { $Lt = $lo }
    $r = Simular -Cd $cdv -Lap $Lt -Laps 20
    $ml = MenorL $cdv
    $dif = $Lt - $ml
    # Aceitavel: o plano nunca pode violar. Pode ser mais folgado que o minimo
    # foundo (conservador), nunca mais curto.
    $ok = if ($r.Viol.Count -eq 0 -and $dif -ge -1.0) { 'OK' } else { 'DIVERGE' }
    Write-Output ('   {0,-50} plano {1,8:N3}s | sim {2,8:N3}s viol {3} | minimo {4,8:N3}s | folga {5,5:N0}ms {6}' -f $nome, ($Lt / 1000), ($r.Mean / 1000), $r.Viol.Count, ($ml / 1000), $dif, $ok)
}

Write-Output ''
Write-Output ''
Write-Output ('#' * $W)
Write-Output '# 8. ATRASOS E ANTECIPACOES (compensacao dinamica)'
Write-Output ('#' * $W)
$cdv = $TODOS['CONFIG     Lend40/UR43, UR43/UR43, UR43/UR43']
$ml = MenorL $cdv
Write-Output ('   referencia: L minimo = {0:N3}s' -f ($ml / 1000))
foreach ($t in @(
        @{ N = 'sem atraso'; C = 0.0; S = 0.0 },
        @{ N = 'combo +5s'; C = 5000.0; S = 0.0 },
        @{ N = 'combo +15s'; C = 15000.0; S = 0.0 },
        @{ N = 'combo +30s'; C = 30000.0; S = 0.0 },
        @{ N = 'troca +5s'; C = 0.0; S = 5000.0 },
        @{ N = 'troca +30s'; C = 0.0; S = 30000.0 },
        @{ N = 'ambos +30s'; C = 30000.0; S = 30000.0 })) {
    $r = Simular -Cd $cdv -Lap $ml -Laps 20 -AtrasoCombo $t.C -AtrasoTroca $t.S
    Write-Output ('   {0,-12} -> volta {1,7:N3}s | violacoes {2} | maior CD no cast {3}ms' -f $t.N, ($r.Mean / 1000), $r.Viol.Count, $r.Pior)
}
Write-Output '   (um atraso e absorvido pela folga; se passar da folga, o macro precisa'
Write-Output '    aceitar uma volta mais longa em vez de forçar o cast.)'

Write-Output ''
Write-Output ('#' * $W)
Write-Output '# 9. PROPRIEDADE: 40 composicoes aleatorias de 40/43/45/50s'
Write-Output ('#' * $W)
$bad = 0; $rnd = New-Object System.Random 42
for ($n = 0; $n -lt 40; $n++) {
    $cdv = @()
    for ($i = 0; $i -lt 6; $i++) { $cdv += @(40000, 43000, 45000, 50000)[$rnd.Next(4)] }
    $ml = MenorL $cdv 6
    $r = Simular -Cd $cdv -Lap $ml -Laps 10
    if ($r.Viol.Count -gt 0) { $bad++; Write-Output ('   FALHOU: ' + ($cdv -join ',')) }
}
Write-Output ('   composicoes testadas 40 | com violacao no L minimo: {0}' -f $bad)