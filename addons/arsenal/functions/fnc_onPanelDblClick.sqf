#include "..\script_component.hpp"
#include "\a3\ui_f\hpp\defineResincl.inc"
#include "..\defines.hpp"
/*
 * Author: LinkIsGrim
 * Add or remove item(s) to favorites when LShift is pressed
 *
 * Arguments:
 * 0: Tree control <CONTROL>
 * 1: Selection path <ARRAY>
 *
 * Return Value:
 * None
 *
 * Public: No
*/
params ["_control", "_path"];

if !(GVAR(shiftState)) exitWith {};
if (GVAR(currentLeftPanel) in [IDC_buttonFace, IDC_buttonVoice, IDC_buttonInsignia]) exitWith {};
if (_path isEqualTo [] || {["isGroupPath", [_control, _path]] call FUNC(treeControlInterface)}) exitWith {};

private _item = toLowerANSI (_control tvData _path);
if (_item == "") exitWith {};

private _favorited = false;
if (_item in GVAR(favorites)) then {
    GVAR(favorites) deleteAt _item;
} else {
    GVAR(favorites) set [_item, nil];
    _favorited = true;
};

private _color = ([[1, 1, 1], GVAR(favoritesColor)] select _favorited) + [1];
_control tvSetColor [_path, _color];
