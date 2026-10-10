; Tema: Botao de combo: normal, antecipado (armado) e emergencia.
TestesComboArmado() {
    global

    ; --- COMBO 2-2-2: NORMAL, ANTECIPADO E EMERGENCIA ---
    ; O alvo do otimizador e "quanto falta a partir de agora" e chega ao
    ; contador como DURACAO a partir do inicio do estado (decorrido + falta),
    ; entao o pendente e exatamente o que falta, sem descontar o decorrido
    ; duas vezes. Nao existe espera artificial: com todos os CD zerados esta
    ; pronto, e com o tank pronto quem segura o verde e o secundario, ate que
    ; o CD dele caia abaixo da tolerancia (1900ms).

    ResetCase("WAITING_COMBO", 0, 0)
    ; Tolerancia = metade da invocacao na Ball + (gap - latencia, o jogo so conta o CD
    ; LatenciaMs depois da chamada) - margem.
    Assert(ToleranciaDoSecundarioMs == 0.5 * SleepAfterTankCombo + (SleepAfterSwitch - Hoenn222_LatencyMs) - Hoenn222_MarginMs, "A tolerancia do secundario inclui a latencia da chamada")
    Assert(FaltaParaComboViavelMs(1) == 0, "A sem CD, ja esta pronto")
    Assert(QuemBloqueiaOCombo(1) == "", "A com tudo pronto ninguem segura o verde")

    ; Tank pronto, secundario com CD principal em cooldown: o verde e do
    ; secundario. O numero vem do config, nao e fixo.
    cdSecMain := CooldownBaseMs(1, true)
    AplicarCast(1, true, MockTick)
    Assert(FaltaParaComboViavelMs(1) == cdSecMain - ToleranciaDoSecundarioMs, "A alvo = (CD sec - tolerancia)/taxa -> "
        FaltaParaComboViavelMs(1) " esperado " (cdSecMain - ToleranciaDoSecundarioMs))
    Assert(QuemBloqueiaOCombo(1) == "secundario", "A secundario segurando o verde")
    Assert(CooldownPendenteDoSecundarioMs(1, 0) > 0, "A antecipar agora deixaria o secundario atrasado")
    PedirCombo()
    Assert(ComboArmado && TimeDoComboArmado == 1, "A pressa antes do verde arma")
    Assert(Scheduled.Length == 0, "A nada e enviado enquanto armado")
    Assert(InStr(DebugText(), "CD_ANTECIPACAO"), "A avisa a antecipacao")
    Assert(InStr(DebugText(), "bloqueio=secundario"), "A avisa quem esta segurando")
    GameLoop()
    Assert(Scheduled.Length == 0, "A continua esperando")
    ; O verde chega quando o CD do secundario cai a tolerancia, nem antes.
    ; Com taxa 1,0 (cast fora da Ball, contagem comeca LatenciaMs depois):
    ;   falta = cdSec - (decorrido - Lat) - Tolerancia <= 0
    ;   =>  decorrido >= cdSec + Lat - Tol
    ; Contar o decorrido duas vezes acendia o verde na METADE disso, com o
    ; CD ainda correndo no jogo.
    ateVerde := cdSecMain + Hoenn222_LatencyMs - ToleranciaDoSecundarioMs
    MockTick += ateVerde - 1
    GameLoop()
    Assert(Scheduled.Length == 0, "A 1ms antes do instante exato ainda nao dispara (pend="
        FaltaParaVerdeMs() ")")
    MockTick += 1
    GameLoop()
    ; O laco de 30 ms so AGENDA uma thread descartavel; nada de Critical nem do
    ; combo na thread do movimento.
    Assert(Scheduled.Length == 1 && !RodizioAtivo && ComboArmado, "A o laco so agenda: agend=" Scheduled.Length " ativo=" RodizioAtivo
        " pend=" FaltaParaVerdeMs() " alvo=" FaltaParaComboViavelMs(1)
        " cdSec=" CdOf(SlotDoPokemon(1, true)) " tol=" ToleranciaDoSecundarioMs)
    GameLoop()
    Assert(Scheduled.Length == 1, "A varreduras seguintes nao agendam de novo")
    Assert(InStr(DebugText(), "COMBO_FIRED"), "A disparo armado registrado")
    Scheduled[1].Call()
    Assert(Scheduled.Length == 2 && RodizioAtivo, "A a thread descartavel consome o pedido e agenda o rodizio")
    Assert(!ComboArmado && TimeDoComboArmado == 0, "A pedido armado consumido")
    Scheduled[2].Call()
    Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}|{c}|{f}|{i}", "A sequencia de skills armada")
    Assert(!RodizioAtivo, "A trava do combo liberada")
    Pass("A pressa antecipada arma; o timer dispara o combo quando tank E secundario ficam viaveis")

    ResetCase("WAITING_COMBO", 0, 20000)
    GameLoop()
    Assert(Scheduled.Length == 0 && Sent.Length == 0, "B green alone never auto-runs")
    Assert(!ComboArmado, "B nothing armed without a press")
    PedirCombo()
    Assert(Scheduled.Length == 1 && RodizioAtivo, "B press on green runs now")
    Scheduled[1].Call()
    Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}|{c}|{f}|{i}", "B skill sequence")
    Pass("B green waits for the press")

    ; Sem CD o alvo e so a margem (250ms), entao "ainda nao verde"quer dizer
    ; decorrido menor que a margem. Os grupos C, D e E dependem disso.
    ResetCase("WAITING_COMBO", 0, 0)
    ; CD real no secundario: assim o verde nao chega durante a janela de
    ; emergencia e o teste mede a janela, nao o cronometro.
    AplicarCast(1, true, MockTick)
    PedirCombo()
    Assert(ComboArmado && Scheduled.Length == 0, "C first press only arms")
    MockTick += Hoenn222_EmergencyWindowMs + 1
    PedirCombo()
    Assert(Scheduled.Length == 0 && ComboArmado, "C outside the window only re-arms")
    MockTick += Hoenn222_EmergencyWindowMs
    PedirCombo()
    Assert(Scheduled.Length == 1 && RodizioAtivo, "C double press is emergency")
    Assert(!ComboArmado, "C emergency drops the pending request")
    Assert(InStr(DebugText(), "result=emergency"), "C emergency logged")
    Scheduled[1].Call()
    Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}|{c}|{f}|{i}", "C emergency sequence")
    savedWindow := Hoenn222_EmergencyWindowMs
    Hoenn222_EmergencyWindowMs := 0
    ResetCase("WAITING_COMBO", 0, 0)
    AplicarCast(1, true, MockTick)
    PedirCombo()
    MockTick += 1
    PedirCombo()
    Assert(Scheduled.Length == 0 && ComboArmado, "C zero window disables emergency")
    Hoenn222_EmergencyWindowMs := savedWindow
    Pass("C double press ignores the timer; zero window disables it")

    ResetCase("WAITING_COMBO", 0, 0)
    ; Com tudo pronto o botao executaria na hora; o secundario em CD faz o pedido armar.
    AplicarCast(1, true, MockTick)
    PedirCombo()
    Assert(ComboArmado, "D the press armed")
    Assert(TrocarDeTime(), "D switch accepted")
    Assert(TimeAtual == 2 && !ComboArmado && TimeDoComboArmado == 0, "D switch disarms")
    Assert(Sent.Length == 3 && InStr(DebugText(), "reason=team_switch"), "D only the switch keys were sent")
    MockTick += 60000
    GameLoop()
    Assert(Scheduled.Length == 0 && Sent.Length == 3, "D no combo leaks into the next team")
    Pass("D accepted team switch cancels the pending combo")

    ResetCase("WAITING_COMBO", 0, 0)
    AplicarCast(1, true, MockTick)
    PedirCombo()
    Assert(ComboArmado, "E the press armed")
    Resincronizar()
    Assert(!ComboArmado && FaseAtual == "WAITING_FIRST_COMBO", "E resync disarms")
    Assert(CdOf(1) == 0 && CdRateOf(1) == 0.5, "E resync also resets the six cooldowns")
    MockTick += 60000
    GameLoop()
    Assert(Scheduled.Length == 0, "E nothing runs after resync")
    ResetCase("WAITING_COMBO", 0, 0)
    AplicarCast(1, true, MockTick)
    PedirCombo()
    Assert(ComboArmado, "E the press armed")
    TrocarModo()
    Assert(!ComboArmado && ModoAtual == "Normal", "E mode change disarms")
    MockTick += 60000
    GameLoop()
    Assert(Scheduled.Length == 0 && Sent.Length == 0, "E nothing runs in another mode")
    Pass("E resync and mode change cancel the pending combo")
}
