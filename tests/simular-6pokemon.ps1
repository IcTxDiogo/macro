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
        [double]$AtrasoCombo = 0, [double]$AtrasoTroca = 0,
        [double[]]$Lures = $null, [double[]]$JanelasFora = $null)
    $script:Vcd = @{}; $script:Vrate = @{}; $script:Vfrz = @{}
    for ($i = 1; $i -le 6; $i++) { $script:Vcd[$i] = 0.0; $script:Vrate[$i] = 0.5; $script:Vfrz[$i] = 0.0 }
    $script:VT = 0.0
    $script:Vviol = New-Object System.Collections.ArrayList
    $script:Vcasts = New-Object System.Collections.ArrayList

    # Janela de cada dupla: lure_k + P + (tempo do secundario fora).
    # O lure NAO e tempo perdido: e o tank fora da Ball ANTES do cast, e quem
    # ele recupera e o cooldown que comecou no cast da volta ANTERIOR. Por isso
    # o tempo fora do tank entre dois casts consecutivos e lure + P.
    # As janelas podem ter tamanhos diferentes: cada uma tem o tamanho que o tank
    # e o secundario daquela dupla exigem. lure_k = tempo do tank fora ANTES
    # do cast, e o que resta da janela e o secundario.
    $posSec = $script:Sg + $script:So
    if ($JanelasFora) { $wBase = $JanelasFora } else { $wBase = (PlanoPara $Cd $Lap).W }
    $lureBase = @()
    if ($Lures) { $lureBase = $Lures } else { $lureBase = (PlanoPara $Cd $Lap).Lures }

    $lapTimes = @()
    for ($lap = 0; $lap -lt $Laps; $lap++) {
        $ls = $script:VT
        for ($k = 0; $k -lt 3; $k++) {
            $tk = 2 * $k + 1; $sc = 2 * $k + 2
            $ws = $script:VT
            # tank k SAI da Ball agora; o secundario continua guardado
            St-Out $tk $true $ws
            St-Out $sc $false $ws
            $lure = $lureBase[$k]
            if ($lure -lt 0) {
                [void]$script:Vviol.Add("lure negativo na dupla $($k+1)")
                $lure = 0
            }
            # Atraso no combo consome o lure da janela; nao empurra o combo
            # para fora dela. Se for maior, o macro aceita a janela mais longa
            # em vez de forcar o cast com CD pendente.
            # Atraso do jogador no combo: ele demora mais para terminar o lure, entao
            # o tank continua em campo mais tempo (recuperacao real para ele) e
            # a janela desta dupla alonga. O secundario tambem ganha, porque
            # ele fica fora ate a proxima troca.
            $wLap = $wBase[$k] + $AtrasoTroca + $AtrasoCombo
            $orcamento = $wLap - $script:Sp - $posSec
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
            # Fim da janela = proxima troca. O secundario permanece fora de tp2
            # ate la, e esse tempo conta como recuperacao a 1,0x do CD recem-criado.
            # O tank ja voltou para a Ball em tp2.
            $proxTroca = $ws + $wLap + $atrasoReal
            if ($script:VT -lt $proxTroca) { St-Step $proxTroca }
            St-Out $sc $false $proxTroca
        }
        # A volta e exatamente 3 janelas: o relogio pode ter ficado atras.
        $lapTimes += ($script:VT - $ls)
    }
    $tail = $lapTimes | Select-Object -Last ([math]::Min(5, $lapTimes.Count))
    return @{
        Mean = ($tail | Measure-Object -Average).Average
        Viol = $script:Vviol; Casts = $script:Vcasts; Laps = $lapTimes
        Pior = ($script:Vcasts | Measure-Object -Property CdRestante -Maximum).Maximum
        JanelaSec = $posSec; Lure = ($lureBase | Measure-Object -Sum).Sum
        Lures = $lureBase; Janela = ($wBase | Measure-Object -Sum).Sum
    }
}

function PlanoPara([double[]]$Cd, [double]$L) {
    $m = $script:Lat + $script:Marg
    $posSec = $script:Sg + $script:So
    # 1) exigencia de cada Pokemon entre dois casts consecutivos
    $tankNeed = @(); $secNeed = @()
    for ($k = 0; $k -lt 3; $k++) {
        $tankNeed += [math]::Max($script:Sp, 2 * ($Cd[2 * $k] + $m) - $L)
        $secNeed += [math]::Max($posSec, 2 * ($Cd[2 * $k + 1] + $m) - $L)
    }
    $minJanelas = @()
    $somaMin = 0.0
    for ($k = 0; $k -lt 3; $k++) {
        $minJanelas += ($tankNeed[$k] + $secNeed[$k])
        $somaMin += ($tankNeed[$k] + $secNeed[$k])
    }
    # 2) a volta tem de fechar em L. A sobra sobre as janelas minimas vira
    #    lure: tempo do tank em campo ANTES do cast, que recupera o cooldown
    #    iniciado no cast da volta anterior. Nao ha tempo "de graca": a janela
    #    e lure + P + secFora, e secFora ja esta no minimo.
    $sobra = $L - $somaMin
    if ($sobra -lt 0) { $sobra = 0 }
    $extra = $sobra / 3.0
    $w = @(); $lures = @()
    for ($k = 0; $k -lt 3; $k++) {
        $lure = ($tankNeed[$k] - $script:Sp) + $extra
        if ($lure -lt 0) { $lure = 0 }
        $lures += $lure
        $w += ($lure + $script:Sp + $secNeed[$k])
    }
    return @{ W = $w; Lures = $lures }
}

function LuresPara([double[]]$Cd, [double]$L) {
    return (PlanoPara $Cd $L).Lures
}

function MenorL([double[]]$Cd, [int]$Laps = 8) {
    # Menor L em que (a) os seis casts comecam com o CD zerado E (b) a volta
    # fecha: as tres janelas tem de somar exatamente L. O teste (b) e o que
    # impede aceitar um L curto cujas janelas nao cabem na volta.
    $lo = 19500.0
    $hi = 400000.0
    $bom = {
        param($L)
        $j = PlanoPara $Cd $L
        $soma = ($j.W | Measure-Object -Sum).Sum
        if ([math]::Abs($soma - $L) -gt 1) { return $false }
        return ((Simular -Cd $Cd -Lap $L -Laps $Laps -Lures $j.Lures -JanelasFora $j.W).Viol.Count -eq 0)
    }
    if (-not (& $bom $hi)) { return $null }
    if (& $bom $lo) { return $lo }
    for ($i = 0; $i -lt 40; $i++) {
        $mid = ($lo + $hi) / 2
        if (& $bom $mid) { $hi = $mid } else { $lo = $mid }
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
    $r20 = Simular -Cd $cdv -Lap $ml -Laps 20 -Lures (LuresPara $cdv $ml)
    $r200 = Simular -Cd $cdv -Lap $ml -Laps 200 -Lures (LuresPara $cdv $ml)
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
# Um L so e valido se as janelas do plano somarem esse L. O plano antigo
# assumia 67,462s; se as janelas exigidas nao couberem nessa volta, ele e
# inviavel — e e exatamente isso que se quer mostrar.
foreach ($teste in @(@{ N = 'plano antigo 67,462s'; L = 67462.5 }, @{ N = 'macro anterior 86,500s'; L = 86500.0 })) {
    $j = PlanoPara $cdv $teste.L
    $somaJ = ($j.W | Measure-Object -Sum).Sum
    $r = Simular -Cd $cdv -Lap $teste.L -Laps 20 -Lures $j.Lures -JanelasFora $j.W
    Write-Output ('   {0}: janelas somam {1:N0}ms (precisa ser {2:N0}ms) | volta real {3:N3}s' -f $teste.N, $somaJ, $teste.L, ($r.Mean / 1000))
    Write-Output ('      violacoes {0} | maior CD no cast {1}ms | casts {2}' -f $r.Viol.Count, $r.Pior, $r.Casts.Count)
    $r.Casts | Where-Object { $_.Volta -ge 5 } | Select-Object -First 3 | ForEach-Object {
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
Write-Output '#    planejador: menor L com soma(janelas) = L, janelas derivadas de L'
Write-Output '#    Janela_k = lure_k + P + secFora_k ; F_i = 2*(CD_i + Lat + Marg) - L'
foreach ($nome in $TODOS.Keys) {
    $cdv = $TODOS[$nome]
    # reproduz o planejador AHK: bissecao na condicao soma(janelas) <= L
    $m2 = $script:Lat + $script:Marg
    $posSec2 = $script:Sg + $script:So
    function JanPlano([double[]]$c, [double]$LL) {
        $w2 = @(); $l2 = @()
        for ($q = 0; $q -lt 3; $q++) {
            $tk = [math]::Max($script:Sp, 2 * ($c[2 * $q] + $m2) - $LL)
            $sc = [math]::Max($posSec2, 2 * ($c[2 * $q + 1] + $m2) - $LL)
            $l2 += ($tk - $script:Sp); $w2 += ($tk + $sc)
        }
        return @($w2, $l2)
    }
    $lo2 = 19500.0; $hi2 = 500000.0
    for ($i2 = 0; $i2 -lt 200; $i2++) {
        $mid = ($lo2 + $hi2) / 2
        $jj = JanPlano $cdv $mid
        $soma = ($jj[0] | Measure-Object -Sum).Sum
        if ($soma -le $mid) { $hi2 = $mid } else { $lo2 = $mid }
    }
    $Lt = $hi2
    $jf = JanPlano $cdv $Lt
    $somaF = ($jf[0] | Measure-Object -Sum).Sum
    $r = Simular -Cd $cdv -Lap $Lt -Laps 20 -Lures $jf[1] -JanelasFora $jf[0]
    $ml = MenorL $cdv
    $dif = $Lt - $ml
    $ok = if ($r.Viol.Count -eq 0 -and $dif -ge -1.0) { 'OK' } else { 'DIVERGE' }
    Write-Output ('   {0,-50} plano {1,8:N3}s | janelas {2:N0}ms | sim {3,8:N3}s viol {4} | minimo {5,8:N3}s | dif {6,5:N0}ms {7}' -f $nome, ($Lt / 1000), $somaF, ($r.Mean / 1000), $r.Viol.Count, ($ml / 1000), $dif, $ok)
}

Write-Output ''
Write-Output ''
Write-Output ('#' * $W)
Write-Output '# 8. TESTE DA PREMISSA: o lure ANTES do proximo cast recupera o CD'
Write-Output ('#' * $W)
Write-Output '#    Se so o trecho pos-cast contasse, F seria sempre P e a volta nunca'
Write-Output '#    fecharia abaixo de 2*CD. Este bloco mede os dois trechos.'
$CdU = @(45000, 0, 0, 0, 0, 0)
$Ltest = 75429.0
$jU = PlanoPara $CdU $Ltest
$lureU = $jU.Lures[0]
$FU = $lureU + $script:Sp
$exigU = 2 * (45000 + $script:Lat + $script:Marg) - $Ltest
Write-Output ('   tank CD 45000, L = {0:N0}ms' -f $Ltest)
Write-Output ('   lure antes do cast      = {0:N0}ms' -f $lureU)
Write-Output ('   pos-cast (P)           = {0:N0}ms' -f $script:Sp)
Write-Output ('   F total entre casts    = {0:N0}ms  (lure + P)' -f $FU)
Write-Output ('   exigido 2*(CD+m)-L     = {0:N0}ms' -f $exigU)
Write-Output ('   o lure e necessario?    = {0}' -f $(if ($FU -ge $exigU) { 'SIM, sem ele F seria ' + [math]::Round($script:Sp) + 'ms e ficaria ' + [math]::Round($exigU - $script:Sp) + 'ms curto' } else { 'nao' }))
$recU = ($FU - $script:Lat) + ($Ltest - $FU) * 0.5
Write-Output ('   recuperacao = (F-Lat) + (L-F)*0,5 = {0:N0}ms  ; exigido CD+Marg = {1:N0}ms' -f $recU, (45000 + $script:Marg))
$rU = Simular -Cd $CdU -Lap $Ltest -Laps 200
$estU = $rU.Casts | Where-Object { $_.Volta -ge 5 }
$ruinsU = ($estU | Where-Object { $_.CdRestante -gt $script:Marg }).Count
Write-Output ('   200 voltas: casts estaveis {0} | com CD pendente {1}' -f $estU.Count, $ruinsU)
Write-Output ('   -> o lure ANTES do cast recupera o CD iniciado no cast anterior.')
Write-Output ('      Se a formula ignorasse o lure, F seria so P = {0}ms e faltariam' -f $script:Sp)
Write-Output ('      {0}ms de recuperacao neste cenario.' -f [math]::Round($exigU - $script:Sp))

Write-Output ''
Write-Output ('#' * $W)
Write-Output '# 9. ATRASOS E ANTECIPACOES (compensacao dinamica)'
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
    $r = Simular -Cd $cdv -Lap $ml -Laps 20 -Lures (LuresPara $cdv $ml) -AtrasoCombo $t.C -AtrasoTroca $t.S
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
    $r = Simular -Cd $cdv -Lap $ml -Laps 10 -Lures (LuresPara $cdv $ml)
    if ($r.Viol.Count -gt 0) { $bad++; Write-Output ('   FALHOU: ' + ($cdv -join ',')) }
}
Write-Output ('   composicoes testadas 40 | com violacao no L minimo: {0}' -f $bad)