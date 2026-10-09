param(
    [double]$Margin = 250,        # so usar a skill este tempo depois do CD estimado zerar
    [double]$Latency = 250,       # o CD so comeca a contar este tempo depois do comando
    [double]$Prepare = 4000,      # minimo fisico: entrar no time -> cast do tank
    [double]$Summon = 2700,       # animacao: cast do tank -> chamada do secundario
    [double]$Gap = 800,           # chamada -> cast do secundario
    [int]$Laps = 4
)
$ErrorActionPreference = 'Stop'

$CdByTier = @{ 'Lendario' = 40.0; 'UR' = 43.0; 'SR' = 45.0; 'T1' = 50.0 }
$Teams = @(
    @{ Name = 'Time 1'; Tank = 'Lendario'; Sec = 'UR' },
    @{ Name = 'Time 2'; Tank = 'UR';       Sec = 'SR' },
    @{ Name = 'Time 3'; Tank = 'SR';       Sec = 'UR' }
)
$Out = 1.0; $In = 0.5

function Get-Plan($Margin, $Latency, $Prepare, $Summon, $Teams) {
    $X = @(); foreach ($t in $Teams) {
        # Sair da Ball e o cast do tank so contam depois de Latency; voltar e imediato.
        $xTank = 1000 * $CdByTier[[string]$t.Tank] + 1.5 * $Latency + $Margin
        # O secundario ainda paga 0,5 por segundo do offset do tank e 0,5 da animacao.
        $xSec = 1000 * $CdByTier[[string]$t.Sec] + 0.5 * $Prepare + 0.5 * $Summon + 1.5 * $Latency + $Margin
        $X += [math]::Max($xTank, $xSec)
    }
    $L = ($X | Measure-Object -Sum).Sum / 2
    $w = @(); for ($i = 0; $i -lt $X.Count; $i++) { $w += 2 * $X[$i] - $L }
    return @{ L = $L; X = $X; w = $w }
}

function Show-Plan($p, $Margin, $Latency, $Prepare, $Summon, $Gap, $label) {
    Write-Output "=== $label ==="
    Write-Output ("Prepare={0:N1}s  Margin={1:N0}ms  Latency={2:N0}ms  Summon={3:N0}ms  Gap={4:N0}ms" -f ($Prepare / 1000), $Margin, $Latency, $Summon, $Gap)
    Write-Output ("Volta L = {0:N3}s" -f ($p.L / 1000))
    for ($i = 0; $i -lt $Teams.Count; $i++) {
        $t = $Teams[$i]
        Write-Output ("  {0}: tank {1,-9} CD {2,4:N0}s | sec {3,-9} CD {4,4:N0}s | janela {5,6:N2}s | cast tank @+{6,5:N2}s | cast sec @+{7,5:N2}s | ocioso {8,5:N2}s | X={9,6:N2}s" -f `
            $t.Name, $t.Tank, $CdByTier[[string]$t.Tank], $t.Sec, $CdByTier[[string]$t.Sec], ($p.w[$i] / 1000), `
            ($Prepare / 1000), (($Prepare + $Summon + $Gap) / 1000), (($p.w[$i] - $Prepare - $Summon - $Gap) / 1000), ($p.X[$i] / 1000))
    }
    $sum = 0; foreach ($t in $Teams) { $sum += 1000 * ($CdByTier[[string]$t.Tank] + $CdByTier[[string]$t.Sec]) }
    Write-Output ("  Limite agregado (N+1)*L >= soma CD + penalidades -> L_min = {0:N3}s" -f (($sum + 3 * (1.5 * $Latency + $Margin) + 3 * (0.5 * $Prepare + 0.5 * $Summon + 1.5 * $Latency + $Margin)) / 4 / 1000))
    Write-Output ''
}

$p4 = Get-Plan $Margin $Latency 4000 $Summon $Teams
Show-Plan $p4 $Margin $Latency 4000 $Summon $Gap "PARAMETROS CORRIGIDOS (Prepare 4s)"

Write-Output "=== PrepareMs: tempo fisico, nao margem ==="
foreach ($pr in 2000, 3000, 4000, 6000, 8000, 12000) {
    $p = Get-Plan $Margin $Latency $pr $Summon $Teams
    Write-Output ("  Prepare={0,5:N1}s -> L={1,7:N3}s  janelas {2,6:N2} {3,6:N2} {4,6:N2}s  (vs 86,50s observado: {5,6:N1}%)" -f `
        ($pr / 1000), ($p.L / 1000), ($p.w[0] / 1000), ($p.w[1] / 1000), ($p.w[2] / 1000), ((86.5 - $p.L / 1000) / 86.5 * 100))
}
Write-Output ''

Write-Output "=== As duas margens de 250ms custam quase nada ==="
foreach ($mg in 0, 250, 500, 1000, 2000) {
    foreach ($la in 0, 250, 500) {
        $p = Get-Plan $mg $la 4000 $Summon $Teams
        Write-Output ("  Margin={0,5:N0}ms Latency={1,4:N0}ms -> L={2,7:N3}s" -f $mg, $la, ($p.L / 1000))
    }
}
Write-Output ''

Write-Output "=== Custo da animacao de invocacao (2700ms) ==="
foreach ($su in 0, 800, 1350, 2700, 4000) {
    $p = Get-Plan $Margin $Latency 4000 $su $Teams
    Write-Output ("  Summon={0,5:N0}ms -> L={1,7:N3}s  (cada -1350ms de invocacao vale ~{2:N2}s de volta)" -f `
        $su, ($p.L / 1000), ((2700 - $su) / 1000 * 0.75))
}
Write-Output ''

# ------------------------------------------------------------------ simulacao
function Invoke-Sim($p, $Margin, $Latency, $Prepare, $Summon, $Gap, $Laps, $OffsetExtra, $FollowGreen, $WindowCut, $Label) {
    $cd = @{}; $rate = @{}; $since = @{}; $stat = @{}
    for ($s = 0; $s -lt 6; $s++) {
        $cd["$s"] = 0.0; $rate["$s"] = $In; $since["$s"] = 0.0
        $stat["$s"] = [pscustomobject]@{ Out = 0.0; In = 0.0; Casts = 0 }
    }
    function Recover($s, $now) {
        if ($now -le $since["$s"]) { return }
        $d = $now - $since["$s"]
        $cd["$s"] -= $d * $rate["$s"]
        if ($rate["$s"] -eq 1.0) { $stat["$s"].Out += $d } else { $stat["$s"].In += $d }
        $since["$s"] = $now
    }
    function SetRate($s, $r, $now) { Recover $s $now; $rate["$s"] = $r }
    # Cast: o CD passa a contar Latency ms depois do comando enviado.
    function Cast($s, $now) { Recover $s $now; $cd["$s"] = $cdMainOf[$s]; $since["$s"] = $now + $Latency; $stat["$s"].Casts++ }

    $cdMainOf = @()
    foreach ($tt in $Teams) { $cdMainOf += (1000 * $CdByTier[[string]$tt.Tank]); $cdMainOf += (1000 * $CdByTier[[string]$tt.Sec]) }

    $t = 0.0; $lap = 0; $rows = @()
    while ($lap -lt $Laps) {
        for ($k = 0; $k -lt $Teams.Count; $k++) {
            $tk = 2 * $k; $sc = 2 * $k + 1
            # Troca de time: so o tank da dupla nova sai da Ball, e Levancy depois.
            SetRate "$tk" $Out ($t + $Latency)
            $extra = if ($OffsetExtra -and $OffsetExtra.ContainsKey($k)) { $OffsetExtra[$k] } else { 0.0 }

            # O macro comanda no primeiro instante em que a skill e utilizavel
            # (CD zerado ha pelo menos Margin). Com FollowGreen ele adia o comando
            # ate la; sem FollowGreen, um atraso do jogador fica visivel no saldo.
            $sendT = $t + $Prepare + $extra
            if ($FollowGreen) {
                Recover "$tk" $t
                $safeAt = $t + ($cd["$tk"] / $rate["$tk"]) + $Margin
                if ($safeAt -gt $sendT) { $sendT = $safeAt }
            }
            Recover "$tk" $sendT; $remT = $cd["$tk"]
            Recover "$tk" ($sendT + $Latency); Cast "$tk" ($sendT + $Latency)

            SetRate "$sc" $Out ($sendT + $Summon + $Latency)
            $sendSec = $sendT + $Summon + $Gap
            if ($FollowGreen) {
                Recover "$sc" ($sendT + $Summon + $Latency)
                $safeSec = ($sendT + $Summon + $Latency) + ($cd["$sc"] / $rate["$sc"]) + $Margin
                if ($safeSec -gt $sendSec) { $sendSec = $safeSec }
            }
            Recover "$sc" $sendSec; $remS = $cd["$sc"]
            Recover "$sc" ($sendSec + $Latency); Cast "$sc" ($sendSec + $Latency)

            $rows += [pscustomobject]@{
                Volta = $lap; Time = $Teams[$k].Name; TankSend = $sendT; TankRem = $remT
                SecSend = $sendSec; SecRem = $remS; Offset = $extra
            }
            $t += $p.w[$k]
            if ($WindowCut -and $WindowCut.ContainsKey($k) -and $lap -eq 0) { $t -= $WindowCut[$k] }
            SetRate "$tk" $In $t; SetRate "$sc" $In $t
        }
        $lap++
    }
    Write-Output "=== $Label ==="
    $last = $Laps - 1
    $a = ($rows | Where-Object { $_.Volta -eq ($last - 1) -and $_.Time -eq 'Time 1' }).TankSend
    $b = ($rows | Where-Object { $_.Volta -eq $last -and $_.Time -eq 'Time 1' }).TankSend
    Write-Output ("  Volta resultante = {0:N3}s (planejada {1:N3}s)" -f (($b - $a) / 1000), ($p.L / 1000))
    foreach ($r in $rows) {
        $tag = if ($r.Offset -ne 0) { "  [tank atrasado $([math]::Round($r.Offset/1000,2))s]" } else { '' }
        Write-Output ("   v{0} {1}: comando tank {2,8:N3}s (CD no seguro {3,7:N1}ms {4}) | comando sec {5,8:N3}s (CD no seguro {6,7:N1}ms {7}){8}" -f `
            $r.Volta, $r.Time, ($r.TankSend / 1000), $r.TankRem, $(if ($r.TankRem -le 0) { 'PRONTO' } else { '*** ATRASADO ***' }), `
            ($r.SecSend / 1000), $r.SecRem, $(if ($r.SecRem -le 0) { 'PRONTO' } else { '*** ATRASADO ***' }), $tag)
    }
    $casts = @($rows).Count * 2
    $badCasts = @($rows | Where-Object { $_.TankRem -gt 0 }).Count + @($rows | Where-Object { $_.SecRem -gt 0 }).Count
    Write-Output ("  Verificacoes: {0} visitas de dupla x 2 slots = {1} casts ({2} Pokemon distintos x {3} voltas)" -f @($rows).Count, $casts, 6, $Laps)
    Write-Output ("  Skills nao prontas no instante do comando: {0} de {1} casts" -f $badCasts, $casts)
    Write-Output "  Recuperacao acumulada:"
    $names = @('L1 tank', 'U1 sec', 'U2 tank', 'R2 sec', 'R3 tank', 'U3 sec')
    for ($s = 0; $s -lt 6; $s++) {
        $o = $stat["$s"].Out / 1000; $i = $stat["$s"].In / 1000
        Write-Output ("   {0}: fora {1,7:N1}s | dentro {2,7:N1}s | creditado {3,7:N1}s | casts {4}" -f $names[$s], $o, $i, ($o + $In * $i), $stat["$s"].Casts)
    }
    Write-Output ''
}

Invoke-Sim $p4 $Margin $Latency 4000 $Summon $Gap $Laps @{} $false $null "CENARIO A - execucao conforme o plano (4 voltas)"
Invoke-Sim $p4 $Margin $Latency 4000 $Summon $Gap 4 @{} $true $null "CENARIO A2 - macro esperando o primeiro instante seguro"
$d = @{}; $d[0] = 3000
Invoke-Sim $p4 $Margin $Latency 4000 $Summon $Gap 3 $d $false $null "CENARIO B - cast do tank do Time 1 atrasado 3s, janela mantida"
$pB = Get-Plan $Margin $Latency 7000 $Summon $Teams
Invoke-Sim $pB $Margin $Latency 7000 $Summon $Gap 3 $d $true $null "CENARIO B2 - mesmo atraso 3s, com janela replanejada (L=73,71s)"
$cut = @{}; $cut[1] = 5000
Invoke-Sim $p4 $Margin $Latency 4000 $Summon $Gap 5 @{} $true $cut "CENARIO C - troca antecipada 5s no Time 2, macro esperando ficar verde"

Write-Output "=== COMPENSACAO: custo real de um atraso no cast ==="
foreach ($x in 1000, 2000, 3000, 5000) {
    $p2 = Get-Plan $Margin $Latency (4000 + $x) $Summon $Teams
    Write-Output ("  atraso {0,4:N1}s -> janela Time 1 {1,6:N2}s (+{2:N2}s), L {3,6:N2}s (+{4:N2}s) => se paga {5,5:N2}s" -f `
        ($x / 1000), ($p2.w[0] / 1000), (($p2.w[0] - $p4.w[0]) / 1000), ($p2.L / 1000), (($p2.L - $p4.L) / 1000), (($x - ($p2.L - $p4.L)) / 1000))
}
Write-Output ''

Write-Output "=== ANTECIPACAO: sobra de CD abre a janela ==="
foreach ($s in 2000, 4000, 8000) {
    $X = @(); for ($i = 0; $i -lt $Teams.Count; $i++) {
        $pk = [math]::Max(4000 - $s, 0)
        $X += [math]::Max(1000 * $CdByTier[[string]$Teams[$i].Tank] - $s + $Margin, 1000 * $CdByTier[[string]$Teams[$i].Sec] + 0.5 * $pk + 0.5 * $Summon + $Latency)
    }
    $Le = ($X | Measure-Object -Sum).Sum / 2
    Write-Output ("  sobra {0,4:N1}s -> janela Time 1 {1,6:N2}s ({2,6:N2}s), L {3,6:N2}s ({4,6:N2}s)" -f `
        ($s / 1000), ((2 * $X[0] - $Le) / 1000), ($p4.w[0] / 1000), ($Le / 1000), ($p4.L / 1000))
}
Write-Output ''

Write-Output "=== RISCO REAL DE CAST ANTECIPADO ==="
Write-Output "Roda um CD REAL em paralelo (latencia e taxa reais diferentes do modelo) e mede"
Write-Output "quanto de CD real ainda resta no instante em que o macro manda o comando."
Write-Output "No regime do plano o CD do modelo zera em (comando - Margin), logo:"
Write-Output "  resto real ~= max(0, latencia_real - Latency - Margin) + erro de taxa"
foreach ($case in @(
        @{ r = 1.00; lat = 0;   lbl = 'jogo instantaneo (hipotese)' },
        @{ r = 1.00; lat = 250; lbl = 'latencia real = assumida' },
        @{ r = 1.00; lat = 400; lbl = 'latencia real 150ms maior' },
        @{ r = 1.00; lat = 500; lbl = 'latencia real no limite (+250)' },
        @{ r = 1.00; lat = 750; lbl = 'latencia real 500ms maior' },
        @{ r = 1.00; lat = 1000; lbl = 'latencia real 750ms maior' },
        @{ r = 0.99; lat = 250; lbl = 'taxa 1% mais lenta' },
        @{ r = 0.98; lat = 250; lbl = 'taxa 2% mais lenta' },
        @{ r = 0.99; lat = 400; lbl = 'taxa 1% lenta + lat 150ms' })) {
    $r = $case.r
    $rcd = @{}; $rrate = @{}; $rsince = @{}; $worst = 0.0
    for ($s = 0; $s -lt 6; $s++) { $rcd["$s"] = 0.0; $rrate["$s"] = $r * $In; $rsince["$s"] = 0.0 }
    $t = 0.0; $lap = 0
    while ($lap -lt 5) {
        for ($k = 0; $k -lt $Teams.Count; $k++) {
            $tk = 2 * $k; $sc = 2 * $k + 1
            $cmT = 1000 * $CdByTier[[string]$Teams[$k].Tank]; $cmS = 1000 * $CdByTier[[string]$Teams[$k].Sec]
            # troca de time: so o tank da dupla nova sai da Ball
            $dec = ($t + $Latency) - $rsince["$tk"]
            if ($dec -gt 0) { $rcd["$tk"] = [math]::Max(0, $rcd["$tk"] - $dec * $rrate["$tk"]); $rsince["$tk"] = $t + $Latency }
            $rrate["$tk"] = $r * $Out
            $sendT = $t + 4000
            # chamada do secundario: ele sai da Ball
            $dec = ($sendT + $Summon + $Latency) - $rsince["$sc"]
            if ($dec -gt 0) { $rcd["$sc"] = [math]::Max(0, $rcd["$sc"] - $dec * $rrate["$sc"]); $rsince["$sc"] = $sendT + $Summon + $Latency }
            $rrate["$sc"] = $r * $Out
            foreach ($slot in $tk, $sc) {
                if ($slot -eq $tk) { $send = $sendT; $cm = $cmT } else { $send = $sendT + $Summon + $Gap; $cm = $cmS }
                $dec = $send - $rsince["$slot"]
                $rem = if ($dec -gt 0) { [math]::Max(0, $rcd["$slot"] - $dec * $rrate["$slot"]) } else { $rcd["$slot"] }
                if ($rem -gt $worst) { $worst = $rem }
                $rcd["$slot"] = $cm
                $rsince["$slot"] = $send + $case.lat
            }
            $t += $p4.w[$k]
            foreach ($slot in $tk, $sc) {
                $dec = $t - $rsince["$slot"]
                if ($dec -gt 0) { $rcd["$slot"] = [math]::Max(0, $rcd["$slot"] - $dec * $rrate["$slot"]); $rsince["$slot"] = $t }
                $rrate["$slot"] = $r * $In
            }
        }
        $lap++
    }
    $verdict = if ($worst -le 0.5) { 'OK - nenhum cast antecipado' } else { ('CAST ANTECIPADO em {0:N0}ms' -f $worst) }
    Write-Output ("  {0,-32} taxa {1:N2}x lat {2,4:N0}ms -> {3}" -f $case.lbl, $r, $case.lat, $verdict)
}
Write-Output ''
Write-Output "Envelope de tolerancia (Latency 250 + Margin 250 = 500ms):"
Write-Output "  latencia real ate 500ms .... seguro (a margem absorve ate 250ms a mais)"
Write-Output "  latencia real > 500ms ..... cast antecipado de (lat_real - 500)ms"
Write-Output "  taxa ate ~0,8% mais lenta . seguro; acima disso a margem NAO protege"
Write-Output "=== SEM TEMPO SUFICIENTE ==="
foreach ($tier in 'SR', 'T1') {
    $T2 = @(); for ($i = 0; $i -lt 3; $i++) { $T2 += , @{ Name = "Time $($i+1)"; Tank = $tier; Sec = $tier } }
    $p = Get-Plan $Margin $Latency 4000 $Summon $T2
    Write-Output ("  3 duplas todas {0} (CD {1}s): L={2:N2}s janela={3:N2}s | cabe: {4}" -f $tier, $CdByTier[$tier], ($p.L / 1000), ($p.w[0] / 1000), ($p.w[0] -ge (4000 + $Summon + $Gap)))
}
foreach ($pr in 20000, 30000, 40000) {
    $p = Get-Plan $Margin $Latency $pr $Summon $Teams
    Write-Output ("  Prepare={0,4:N0}s: L={1:N2}s janela={2:N2}s precisa de {3:N2}s | cabe: {4}" -f ($pr / 1000), ($p.L / 1000), ($p.w[0] / 1000), (($pr + $Summon + $Gap) / 1000), ($p.w[0] -ge ($pr + $Summon + $Gap)))
}
