#Requires AutoHotkey v2.0
; Dois logs independentes:
;   - diagnostico (%TEMP%\macro_switch_debug.log): eventos tecnicos; nunca bloqueia um comando;
;   - sessao (logs\farm_log_*.txt): combos e trocas de time, para o jogador.

global PastaDeLogs := A_ScriptDir "\logs"
global DiagnosticoAtivo := true
global ArquivoDiagnostico := A_Temp "\macro_switch_debug.log"

; Diagnostico maior que 5 MB vira .old (substitui o .old anterior): o arquivo nao cresce sem limite.
RotacionarDiagnosticoSeGrande() {
    global ArquivoDiagnostico
    try {
        if (FileExist(ArquivoDiagnostico) && FileGetSize(ArquivoDiagnostico) > 5 * 1024 * 1024)
            FileMove(ArquivoDiagnostico, ArquivoDiagnostico ".old", true)
    } catch {
    }
}
RotacionarDiagnosticoSeGrande()

; Escreve uma linha no diagnostico. Qualquer falha (arquivo indisponivel, formatacao) e
; ignorada: o log nunca pode impedir uma acao do macro.
LogDiagnostico(evento, detalhes := "", erro := 0) {
    global DiagnosticoAtivo, ArquivoDiagnostico
    try {
        if !DiagnosticoAtivo
            return
        if IsObject(erro)
            detalhes .= " message=" erro.Message " function=" erro.What " line=" erro.Line " file=" erro.File
        detalhes := StrReplace(StrReplace(detalhes, "`r", " "), "`n", " ")
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " tick=" A_TickCount " pid=" ProcessExist()
            " | " evento " | " detalhes "`n", ArquivoDiagnostico, "UTF-8")
    } catch {
    }
}

try {
    if !DirExist(PastaDeLogs)
        DirCreate(PastaDeLogs)
} catch as erroAoIniciarLog {
    LogDiagnostico("SWITCH_ERROR", "phase=logger_init", erroAoIniciarLog)
}

global ArquivoDoLogDaSessao := PastaDeLogs "\farm_log_" FormatTime(, "yyyy-MM-dd_HH-mm-ss") ".txt"
global InicioDoComboTick := 0
global TimeDoUltimoCombo := 0

RegistrarNoLog(mensagem) {
    global ArquivoDoLogDaSessao
    try {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " | " mensagem "`n", ArquivoDoLogDaSessao)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=session_logger", e)
    }
}

RegistrarInicioDoCombo(time, modo, origem := "manual") {
    global InicioDoComboTick, TimeDoUltimoCombo
    InicioDoComboTick := A_TickCount
    TimeDoUltimoCombo := time
    RegistrarNoLog("COMBO START | Modo: " modo " | Time: " time " | Origem: " origem)
}

; Registra a troca (e, se havia combo em andamento, quanto tempo passou desde ele).
RegistrarTrocaNoLog(novoTime, modo) {
    global InicioDoComboTick, TimeDoUltimoCombo

    if (InicioDoComboTick > 0) {
        decorridoSeg := Round((A_TickCount - InicioDoComboTick) / 1000, 2)
        RegistrarNoLog("TEAM END    | Tempo pos-combo (Time " TimeDoUltimoCombo "): " decorridoSeg "s")
        InicioDoComboTick := 0
    }

    RegistrarNoLog("TEAM SWITCH | Solicitado Time: " novoTime " | Entrada visual: nao confirmada")
}
