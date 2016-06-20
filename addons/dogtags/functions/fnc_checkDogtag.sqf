/*
 * Author: SzwedzikPL
 * Checks unit dogtag
 *
 * Arguments:
 * 0: Player <OBJECT>
 * 1: Target <OBJECT>
 *
 * Return Value:
 * None
 *
 * Public: No
 */
#include "script_component.hpp"

params ["_player", "_target"];

private _doubleTags = !(_target getVariable [QGVAR(dogtagTaken), false]);
private _dogTagData = [_target] call FUNC(getDogTagData);

[QGVAR(showDogtag), [_dogTagData, _doubleTags]] call CBA_fnc_localEvent;
