#Requires AutoHotkey v2.0-beta.6

/* XInput by Lexikos
    Adaptações para funcionar sem avisos.
*/

; #####################################################################
; # BIBLIOTECA XINPUT (VERSÃO DO FÓRUM, ESTÁVEL E CORRIGIDA)
; #####################################################################

XInput_Init(dll := "") {
    global
    if _XInput_hm ?? 0
        return

    global XINPUT_GAMEPAD_DPAD_UP := 0x0001
    global XINPUT_GAMEPAD_DPAD_DOWN := 0x0002
    global XINPUT_GAMEPAD_DPAD_LEFT := 0x0004
    global XINPUT_GAMEPAD_DPAD_RIGHT := 0x0008
    global XINPUT_GAMEPAD_START := 0x0010
    global XINPUT_GAMEPAD_BACK := 0x0020
    global XINPUT_GAMEPAD_LEFT_THUMB := 0x0040
    global XINPUT_GAMEPAD_RIGHT_THUMB := 0x0080
    global XINPUT_GAMEPAD_LEFT_SHOULDER := 0x0100
    global XINPUT_GAMEPAD_RIGHT_SHOULDER := 0x0200
    global XINPUT_GAMEPAD_GUIDE := 0x0400
    global XINPUT_GAMEPAD_A := 0x1000
    global XINPUT_GAMEPAD_B := 0x2000
    global XINPUT_GAMEPAD_X := 0x4000
    global XINPUT_GAMEPAD_Y := 0x8000
    global XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE := 7849
    global XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE := 8689
    global XINPUT_GAMEPAD_TRIGGER_THRESHOLD := 30

    if (dll = "")
        loop files A_WinDir "\System32\XInput1_*.dll"
            dll := A_LoopFileName
    if (dll = "")
        dll := "XInput1_3.dll"

    global _XInput_hm := DllCall("LoadLibrary", "str", dll, "ptr")

    if !_XInput_hm
        throw Error("Falha ao inicializar XInput: " dll " não encontrada.")

    global _XInput_GetState, _XInput_SetState, _XInput_GetCapabilities
    (_XInput_GetState := DllCall("GetProcAddress", "ptr", _XInput_hm, "ptr", 100, "ptr")) || (_XInput_GetState :=
        DllCall("GetProcAddress", "ptr", _XInput_hm, "astr", "XInputGetState", "ptr"))
    _XInput_SetState := DllCall("GetProcAddress", "ptr", _XInput_hm, "astr", "XInputSetState", "ptr")
    _XInput_GetCapabilities := DllCall("GetProcAddress", "ptr", _XInput_hm, "astr", "XInputGetCapabilities", "ptr")

    if !(_XInput_GetState && _XInput_SetState && _XInput_GetCapabilities) {
        XInput_Term()
        throw Error("Falha ao inicializar XInput: função não encontrada.")
    }
}

XInput_GetState(UserIndex) {
    global _XInput_GetState

    xiState := Buffer(16)

    if err := DllCall(_XInput_GetState, "uint", UserIndex, "ptr", xiState) {
        if err = 1167 ; ERROR_DEVICE_NOT_CONNECTED
            return 0
        throw OSError(err, -1)
    }

    return {
        dwPacketNumber: NumGet(xiState, 0, "UInt"),
        wButtons: NumGet(xiState, 4, "UShort"),
        bLeftTrigger: NumGet(xiState, 6, "UChar"),
        bRightTrigger: NumGet(xiState, 7, "UChar"),
        sThumbLX: NumGet(xiState, 8, "Short"),
        sThumbLY: NumGet(xiState, 10, "Short"),
        sThumbRX: NumGet(xiState, 12, "Short"),
        sThumbRY: NumGet(xiState, 14, "Short"),
    }
}

XInput_Term() {
    global _XInput_hm, _XInput_GetState, _XInput_SetState, _XInput_GetCapabilities
    if _XInput_hm
        DllCall("FreeLibrary", "ptr", _XInput_hm), _XInput_hm := _XInput_GetState := _XInput_SetState :=
        _XInput_GetCapabilities := 0
}
