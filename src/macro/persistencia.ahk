#Requires AutoHotkey v2.0
; Persistencia do estado do modelo entre recargas (Ctrl+Esc / Start).
;
; Sem isto, recarregar o macro no meio da hunt zerava o modelo (os seis "prontos") e a
; primeira volta depois do reload podia comer skill. O estado e salvo a cada evento
; (cast, chamada, troca, F8, modo) e restaurado so se o arquivo for recente e da mesma
; sessao do Windows. Pedidos armados nunca sao restaurados.
; F8 continua sendo o jeito de zerar de proposito.

global ArquivoDeEstado := PastaDeLogs "\estado_do_macro.txt"
global VersaoDoArquivoDeEstado := 1
global IdadeMaximaDoEstadoSeg := 180

; Grava o estado atual. Nunca lanca excecao: falha de disco so vai para o log.
SalvarEstado() {
    global Hoenn222_RestoreStateOnReload, ArquivoDeEstado, VersaoDoArquivoDeEstado
    global ModoAtual, TimeAtual, FaseAtual, InicioDaFaseTick, UltimaTrocaDeTimeTick, TankJaCastou
    global CooldownRestanteMs, TaxaDeRecuperacao, CooldownContaDesdeTick, CooldownZerouTick
    if (!Hoenn222_RestoreStateOnReload)
        return
    try {
        texto := "versao=" VersaoDoArquivoDeEstado "`n"
            . "salvo_em=" A_Now "`n"
            . "salvo_tick=" A_TickCount "`n"
            . "modo=" ModoAtual "`n"
            . "time=" TimeAtual "`n"
            . "fase=" FaseAtual "`n"
            . "inicio_fase_tick=" InicioDaFaseTick "`n"
            . "ultima_troca_tick=" UltimaTrocaDeTimeTick "`n"
            . "tank_castou=" (TankJaCastou[1] ? 1 : 0) "," (TankJaCastou[2] ? 1 : 0) "," (TankJaCastou[3] ? 1 : 0) "`n"
            . "cd_restante=" ListaSeparadaPorVirgula(CooldownRestanteMs) "`n"
            . "taxa=" ListaSeparadaPorVirgula(TaxaDeRecuperacao) "`n"
            . "conta_desde=" ListaSeparadaPorVirgula(CooldownContaDesdeTick) "`n"
            . "zerou_em=" ListaSeparadaPorVirgula(CooldownZerouTick) "`n"
        arquivo := FileOpen(ArquivoDeEstado, "w", "UTF-8-RAW")
        arquivo.Write(texto)
        arquivo.Close()
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=salvar_estado", e)
    }
}

; Restaura o estado salvo se for valido e recente. Devolve true se restaurou.
; `agoraTick`/`agoraTexto` existem para o teste simular a passagem do tempo.
RestaurarEstado(agoraTick := A_TickCount, agoraTexto := A_Now) {
    global Hoenn222_RestoreStateOnReload, ArquivoDeEstado
    if (!Hoenn222_RestoreStateOnReload || !FileExist(ArquivoDeEstado))
        return false
    try {
        dados := LerArquivoDeEstado()
        motivo := MotivoParaIgnorarEstado(dados, agoraTick, agoraTexto)
        if (motivo != "") {
            LogDiagnostico("STATE_RESTORE_SKIPPED", "reason=" motivo)
            return false
        }
        AplicarEstadoLido(dados)
        idadeSeg := DateDiff(agoraTexto, dados["salvo_em"], "Seconds")
        LogDiagnostico("STATE_RESTORED", "age_s=" idadeSeg " mode=" ModoAtual " team=" TimeAtual " state=" FaseAtual)
        return true
    } catch as e {
        LogDiagnostico("STATE_RESTORE_SKIPPED", "reason=invalid_file")
        LogDiagnostico("SWITCH_ERROR", "phase=restaurar_estado", e)
        return false
    }
}

; chave=valor por linha -> Map. Lanca excecao se o arquivo nao puder ser lido.
LerArquivoDeEstado() {
    global ArquivoDeEstado
    dados := Map()
    for linha in StrSplit(FileRead(ArquivoDeEstado, "UTF-8"), "`n", "`r") {
        posicao := InStr(linha, "=")
        if (posicao > 1)
            dados[SubStr(linha, 1, posicao - 1)] := SubStr(linha, posicao + 1)
    }
    return dados
}

; Texto com o motivo de ignorar o arquivo, ou "" se ele vale.
MotivoParaIgnorarEstado(dados, agoraTick, agoraTexto) {
    global VersaoDoArquivoDeEstado, IdadeMaximaDoEstadoSeg
    for chave in ["versao", "salvo_em", "salvo_tick", "modo", "time", "fase", "inicio_fase_tick",
        "ultima_troca_tick", "tank_castou", "cd_restante", "taxa", "conta_desde", "zerou_em"] {
        if (!dados.Has(chave))
            return "missing_" chave
    }
    if (dados["versao"] != VersaoDoArquivoDeEstado)
        return "version"
    if (dados["modo"] != "Normal" && dados["modo"] != "Hoenn222")
        return "mode"
    if (!IsInteger(dados["time"]) || dados["time"] < 1 || dados["time"] > 3)
        return "team"
    idadeSeg := DateDiff(agoraTexto, dados["salvo_em"], "Seconds")
    if (idadeSeg < 0 || idadeSeg > IdadeMaximaDoEstadoSeg)
        return "too_old"
    ; Mesma sessao do Windows: o relogio de ticks avancou o mesmo que o relogio de parede.
    decorridoMs := agoraTick - dados["salvo_tick"]
    if (decorridoMs < 0 || Abs(decorridoMs - idadeSeg * 1000) > 5000)
        return "other_boot"
    for chave in ["cd_restante", "taxa", "conta_desde", "zerou_em"] {
        valores := StrSplit(dados[chave], ",")
        if (valores.Length != 6)
            return "bad_" chave
        for valor in valores {
            if (!IsNumber(valor))
                return "bad_" chave
        }
    }
    castou := StrSplit(dados["tank_castou"], ",")
    if (castou.Length != 3)
        return "bad_tank_castou"
    return ""
}

AplicarEstadoLido(dados) {
    global ModoAtual, TimeAtual, FaseAtual, InicioDaFaseTick, UltimaTrocaDeTimeTick, TankJaCastou
    global CooldownRestanteMs, TaxaDeRecuperacao, CooldownContaDesdeTick, CooldownZerouTick
    global TextoDeStatus, PlanoEmCache

    ModoAtual := dados["modo"]
    TimeAtual := Integer(dados["time"])
    FaseAtual := dados["fase"]
    InicioDaFaseTick := Integer(dados["inicio_fase_tick"])
    UltimaTrocaDeTimeTick := Integer(dados["ultima_troca_tick"])
    castou := StrSplit(dados["tank_castou"], ",")
    TankJaCastou := Map(1, castou[1] == "1", 2, castou[2] == "1", 3, castou[3] == "1")
    PreencherLista(CooldownRestanteMs, dados["cd_restante"])
    PreencherLista(TaxaDeRecuperacao, dados["taxa"])
    PreencherLista(CooldownContaDesdeTick, dados["conta_desde"])
    PreencherLista(CooldownZerouTick, dados["zerou_em"])
    PlanoEmCache := false
    TextoDeStatus := (ModoAtual == "Normal") ? "Modo: Normal" : "Modo: Hoenn 2-2-2 - Time: " TimeAtual
}

ListaSeparadaPorVirgula(lista) {
    texto := ""
    for valor in lista
        texto .= (A_Index == 1 ? "" : ",") valor
    return texto
}

PreencherLista(lista, texto) {
    for valor in StrSplit(texto, ",")
        lista[A_Index] := Number(valor)
}
