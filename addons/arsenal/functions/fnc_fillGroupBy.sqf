#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: ACE3 Team
 * Fills the group-by dropdown for a tree panel.
 *
 * Arguments:
 * 0: Arsenal display <DISPLAY>
 * 1: Group-by control <CONTROL>
 *
 * Return Value:
 * None
 *
 * Public: No
 */

params ["_display", "_control"];

if (isNull _display || {isNull _control}) exitWith {};

lbClear _control;

private _isRight = ctrlIDC _control == IDC_groupRightTab;
private _groupByMode = [GVAR(lastGroupByLeftMode), GVAR(lastGroupByRightMode)] select _isRight;

if !(_groupByMode in [GROUP_BY_OFF, GROUP_BY_FIRST_LETTER, GROUP_BY_MOD]) then {
    _groupByMode = GROUP_BY_OFF;
};

{
    _x params ["_label", "_mode"];
    private _index = _control lbAdd _label;
    _control lbSetValue [_index, _mode];
} forEach [
    [LLSTRING(groupByOff), GROUP_BY_OFF],
    [LLSTRING(groupByFirstLetter), GROUP_BY_FIRST_LETTER],
    [LLSTRING(groupByMod), GROUP_BY_MOD]
];

GVAR(ignoreFirstGroupPanelCall) = true;
_control lbSetCurSel _groupByMode;
