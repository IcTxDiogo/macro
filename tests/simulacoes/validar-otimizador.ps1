param(
    [double]$Margin = 250,
    [double]$Latency = 250,
    [double]$Summon = 2700,
    [double]$Gap = 800,
    [int]$Laps = 20,
    [double]$BallLatency = 0
)
$ErrorActionPreference = 'Stop'

$CdByTier = @{ 'Lendario' = 40.0; 'UR' = 43.0; 'SR' = 45.0; 'T1' = 50.0 }
$Teams = @(
    @{ Name = 'Time 1'; Tank = 'Lendario'; Sec = 'UR' },
    @{ Name = 'Time 2'; Tank = 'UR';       Sec = 'SR' },
    @{ Name = 'Time 3'; Tank = 'SR';       Sec = 'UR' }
)
$RATE_OUT = 1.0
$RATE_IN = 0.5
# Teto de CD do secundario no instante T0 para o combo inteiro ser viavel.
# Entre T0 e a chamada ele ainda esta na Ball (0,5 x Summon); entre a chamada e
# o cast recupera 1,0 x Gap; e a margem de 250ms precisa caber antes do cast.
$SEC_TOL = 0.5 * $Summon + $Gap - $Margin
$OBS = @()
function Say([string]$s) { $script:OBS += $s; Write-Output $s }

# ---------------------------------------------------------------- estado CD
function New-Cd {
    $cd = @{}; $rate = @{}; $since = @{}
    for ($i = 1; $i -le 6; $i++) { $cd[$i] = 0.0; $rate[$i] = $RATE_IN; $since[$i] = 0.0 }
    return @{ Cd = $cd; Rate = $rate; Since = $since }
}
function Touch($st, $i, $now) {
    $d = $now - $st.Since[$i]
    if ($d -gt 0) {
        $v = $st.Cd[$i] - $d * $st.Rate[$i]
        $st.Cd[$i] = if ($v -gt 0) { $v } else { 0.0 }
        $st.Since[$i] = $now
    }
}
function SetRate($st, $i, $r, $now, $delay = 0) {
    Touch $st $i $now
    $st.Rate[$i] = $r
    if ($delay -gt 0) { $st.Since[$i] = $now + $delay }
}
function Cast($st, $i, $cdMain, $now) {
    Touch $st $i $now
    $st.Rate[$i] = $RATE_OUT
    $st.Cd[$i] = $cdMain
    $st.Since[$i] = $now + $Latency
}

# ------------------------- verde = viabilidade do COMBO INTEIRO, nao so do tank
function Green-ReadyAt($st, $tk, $sc, $now, $forceMs = 0) {
    Touch $st $tk $now
    Touch $st $sc $now
    $t0 = $now + $st.Cd[$tk] / $RATE_OUT + $Margin
    $secEmT0 = $st.Cd[$sc] - ($t0 - $now) * $RATE_IN
    if ($secEmT0 -lt 0) { $secEmT0 = 0 }
    if ($secEmT0 -gt $SEC_TOL) { $t0 = $now + ($st.Cd[$sc] - $SEC_TOL) / $RATE_IN }
    if ($forceMs -gt 0) {
        $t0 = $t0 - $forceMs
        # Nao da para comecar o combo antes de o time estar em campo.
        if ($t0 -lt $now) { $t0 = $now }
    }
    return $t0
}

# ------------------------------------------- planejador global das tres duplas
function Get-X([double]$BallComp) {
    $X = @()
    foreach ($t in $Teams) {
        $xTank = 1000 * $CdByTier[[string]$t.Tank] + $Latency + $Margin + 1.5 * $BallComp
        $xSec = 1000 * $CdByTier[[string]$t.Sec] + 0.5 * $Margin + 0.5 * $Summon + $Latency + $Margin + 1.5 * $BallComp
        $X += [math]::Max($xTank, $xSec)
    }
    return $X
}
function Get-W([double]$BallComp) {
    $X = Get-X $BallComp
    $L = ($X | Measure-Object -Sum).Sum / 2
    $w = @(); for ($i = 0; $i -lt 3; $i++) { $w += 2 * $X[$i] - $L }
    return @{ L = $L; X = $X; W = $w }
}

# ------------------------------------------------------------------- rotacao
function Invoke-Rotation {
    param([int]$N, [string]$Policy, [double]$ForceEarly = 0, $ForceWindow = $null)
    $W = if ($ForceWindow) { $ForceWindow } else { (Get-W $script:BallLatency).W }
    $st = New-Cd
    $t = 0.0; $lap = 0
    $rows = @()
    $late = 0; $casts = 0; $worstT = 0.0; $worstS = 0.0
    while ($lap -lt $N) {
        $lapStart = $t
        for ($k = 0; $k -lt 3; $k++) {
            $tk = 2 * $k + 1; $sc = 2 * $k + 2
            $cdT = 1000 * $CdByTier[[string]$Teams[$k].Tank]
            $cdS = 1000 * $CdByTier[[string]$Teams[$k].Sec]
            SetRate $st $tk $RATE_OUT $t $script:BallLatency
            $s = $t
            $t0 = Green-ReadyAt $st $tk $sc $t $ForceEarly
            Touch $st $tk ($t0 - $Margin)
            if ($st.Cd[$tk] -gt 0) { $late++; if ($st.Cd[$tk] -gt $worstT) { $worstT = $st.Cd[$tk] } }
            $casts++
            Cast $st $tk $cdT $t0
            $t1 = $t0 + $Summon
            SetRate $st $sc $RATE_OUT $t1 $script:BallLatency
            $t2 = $t1 + $Gap
            Touch $st $sc ($t2 - $Margin)
            if ($st.Cd[$sc] -gt 0) { $late++; if ($st.Cd[$sc] -gt $worstS) { $worstS = $st.Cd[$sc] } }
            $casts++
            Cast $st $sc $cdS $t2
            if ($Policy -eq 'greedy') {
                $nk = $k + 1; if ($nk -gt 2) { $nk = 0 }
                $nslot = 2 * $nk + 1
                Touch $st $nslot $t2
                $t = $t2 + $st.Cd[$nslot] / $RATE_IN + $Margin
            } else {
                $t = $s + $W[$k]
            }
            SetRate $st $tk $RATE_IN $t
            SetRate $st $sc $RATE_IN $t
        }
        $rows += [pscustomobject]@{ Lap = $lap; Length = $t - $lapStart }
        $lap++
    }
    $tail = $rows | Select-Object -Last ([math]::Min(5, $rows.Count))
    $mean = ($tail | Measure-Object -Property Length -Average).Average
    return @{ Mean = $mean; Late = $late; Casts = $casts; WorstTank = $worstT; WorstSec = $worstS; Rows = $rows }
}

Say "=== 1. INSTANTES DE BALL, LIDOS DO CODIGO ==="
Say ("  ExecutarRodizio222(): AutoCombo tank -> Sleep(Summon={0}) -> ControlSend(p2)" -f $Summon)
Say ("  -> Sleep(Gap={0}) -> AutoCombo secundario -> Sleep(SleepAfterCombo)" -f $Gap)
Say "  Troca de time: a tecla do time traz o Tank para fora. O secundario so sai"
Say "  da Ball na chamada (p2) e volta junto com o Tank na proxima troca."
Say ("  Teto de CD do secundario em T0: 0,5*Summon + Gap - Margin = {0:N0}ms" -f $SEC_TOL)
Say ""

Say "=== 2. FORMULA DE RECUPERACAO ==="
Say "  recuperacao efetiva = segundos fora x 1,0 + segundos dentro x 0,5"
Say "  Tank: recupera durante TODO o tempo em que o time esta em campo, incluindo"
Say "  a espera ate o combo, Summon, Gap e a espera pos-combo ate a troca."
Say "  Secundario: a 0,5 desde a troca anterior ate a chamada, e a 1,0 de T1 a T2."
Say ""

Say "=== 3. PLANEJAMENTO GLOBAL DAS TRES DUPLAS ==="
Say "  Tank       : X >= cdTank + Latency + Margin            (independe de p)"
Say "  Secundario : X >= cdSec  + 0,5*p + 0,5*Summon + Latency + Margin"
Say "  L = soma(X)/2     janela = 2*X - L     p = offset do cast do tank"
$plan = Get-W 0
Say ("  L previsto = {0:N3}s    janelas {1:N2} {2:N2} {3:N2}s" -f ($plan.L / 1000), ($plan.W[0] / 1000), ($plan.W[1] / 1000), ($plan.W[2] / 1000))
for ($k = 0; $k -lt 3; $k++) {
    $a = 1000 * $CdByTier[[string]$Teams[$k].Tank] + $Latency + $Margin
    $b = 1000 * $CdByTier[[string]$Teams[$k].Sec] + 0.5 * $Margin + 0.5 * $Summon + $Latency + $Margin
    $lim = if ($b -ge $a) { 'secundario' } else { 'tank' }
    Say ("  {0}: tank exige {1,6:N1}s | sec exige {2,6:N1}s -> limita o {3}" -f $Teams[$k].Name, ($a / 1000), ($b / 1000), $lim)
}
Say ""

Say "=== 4. CONVERGENCIA E COMPARACAO COM O MACRO ATUAL (20 voltas) ==="
$rPlan = Invoke-Rotation -N $Laps -Policy 'plan'
$rGreedy = Invoke-Rotation -N $Laps -Policy 'greedy'
$ult = $rPlan.Rows | Select-Object -Last 3
foreach ($u in $ult) { Say ("   volta {0}: {1:N3}s" -f $u.Lap, ($u.Length / 1000)) }
$sd = 0.0
foreach ($u in ($rPlan.Rows | Select-Object -Last 5)) { $sd += [math]::Pow($u.Length - $rPlan.Mean, 2) }
$sd = [math]::Sqrt($sd / 5)
Say ("  politica 'plan'   -> {0:N3}s por volta   (previsto {1:N3}s, desvio {2:N4}s)" -f ($rPlan.Mean / 1000), ($plan.L / 1000), ($sd / 1000))
Say ("                      casts com CD pendente: {0} de {1}" -f $rPlan.Late, $rPlan.Casts)
Say ("  politica 'greedy' -> {0:N3}s por volta   (casts pendentes {1} de {2})" -f ($rGreedy.Mean / 1000), $rGreedy.Late, $rGreedy.Casts)
Say ""
Say ("  MACRO ATUAL (logs/farm_log_2026-10-09_11-38-58.txt) = 86,500s")
Say ("  ganho da politica 'plan'   : {0:N1}%" -f ((86.5 - $rPlan.Mean / 1000) / 86.5 * 100))
Say ("  ganho da politica 'greedy' : {0:N1}%  (executar o mais cedo possivel e PIOR)" -f ((86.5 - $rGreedy.Mean / 1000) / 86.5 * 100))
Say ""

Say "=== 5. SENSIBILIDADE A LATENCIA DE SAIDA DA BALL ==="
foreach ($bl in 0, 250, 500) {
    $script:BallLatency = $bl
    $a = Invoke-Rotation -N 12 -Policy 'plan'
    Say ("  saida {0,4:N0}ms, plano sem compensacao -> volta {1:N3}s, casts pendentes {2}/{3}" -f $bl, ($a.Mean / 1000), $a.Late, $a.Casts)
    $Wc = (Get-W $bl).W
    $b = Invoke-Rotation -N 12 -Policy 'plan' -ForceWindow $Wc
    Say ("  saida {0,4:N0}ms, plano com 1,5*X     -> volta {1:N3}s, casts pendentes {2}/{3}" -f $bl, ($b.Mean / 1000), $b.Late, $b.Casts)
}
$script:BallLatency = 0
Say ""

Say "=== 6. ANTECIPACAO MANUAL ==="
Say "  O macro nao inventa CD. Se o jogador antecipa, o macro precisa avisar que o"
Say "  combo inteiro nao e viavel nesse instante, em vez de fingir que esta."
$base = Invoke-Rotation -N 10 -Policy 'plan'
Say ("  referencia (sem antecipacao): {0}/{1} casts viaveis" -f ($base.Casts - $base.Late), $base.Casts)
foreach ($e in 250, 1000, 2000, 3000, 4000, 5000, 8000) {
    $r = Invoke-Rotation -N 10 -Policy 'plan' -ForceEarly $e
    $pior = [math]::Max($r.WorstTank, $r.WorstSec)
    $quem = if ($r.WorstTank -ge $r.WorstSec) { 'tank ' } else { 'sec  ' }
    if ($r.Late -eq 0) {
        Say ("  antecipar {0,6:N0}ms -> ainda viavel" -f $e)
    } else {
        Say ("  antecipar {0,6:N0}ms -> NAO VIAVEL: {1}/{2} casts, pior {3} com {4:N0}ms de CD" -f $e, $r.Late, $r.Casts, $quem, $pior)
    }
}
Say ""
Say ""
Say "  Estado nao eststationario: o jogador segura o combo e comeca a volta com o"
Say "  Tank pronto e o secundario atrasado. O macro tem de avisar, nao inventar CD."
function Project-SecAtCast($st, $sc, $now, $t0) {
    Touch $st $sc $now
    $t1 = $t0 + $Summon
    $r = $st.Cd[$sc] - ($t1 - $now) * $RATE_IN
    if ($r -lt 0) { $r = 0 }
    $util = ($r + $Margin) -le $Gap      # CD zerado + margem cabem antes do cast fixo
    return @{ R = $r; Util = $util; T0 = $t0; T2 = $t0 + $Summon + $Gap }
}
foreach ($cdSecInicial in 0, 1000, 1900, 3000, 8000, 15000) {
    $st = New-Cd
    SetRate $st 1 $RATE_OUT 0 0
    $st.Cd[1] = 0
    $st.Cd[2] = $cdSecInicial
    $st.Since[1] = 0; $st.Since[2] = 0
    $t0 = Green-ReadyAt $st 1 2 0
    $p = Project-SecAtCast $st 2 0 $t0
    $forcado = Project-SecAtCast $st 2 0 0
    Say ("  sec com {0,6:N0}ms de CD  -> verde em +{1,6:N0}ms, secundario no cast {2,6:N0}ms, {3}" -f `
        $cdSecInicial, ($t0 - 0), ($p.R), $(if ($p.Util) { 'VIAVEL' } else { 'NAO VIAVEL' }))
    Say ("      se o jogador forcar agora: secundario no cast {0,6:N0}ms, {1}" -f `
        $forcado.R, $(if ($forcado.Util) { 'VIAVEL' } else { 'NAO VIAVEL - o macro deve avisar' }))
}
Say ""

Say "=== 7. INTERVALOS INTERNOS PRESERVADOS ==="
$seq = @()
foreach ($r in $script:OBS) { }
Say ("  Summon={0}ms e Gap={1}ms sao os valores de SleepAfterTankCombo e" -f $Summon, $Gap)
Say "  SleepAfterSwitch no codigo. A simulacao nunca os altera: o unico tempo que"
Say "  muda entre cenarios e quando o combo comeca e quando o time troca."
$chk = Invoke-Rotation -N 6 -Policy 'plan'
Say ("  Sequencia medida: nenhum sleep foi estendido; 6 voltas em {0:N3}s" -f ($chk.Mean / 1000))
