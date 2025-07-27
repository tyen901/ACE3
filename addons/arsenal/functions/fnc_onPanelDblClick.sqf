#include "..\script_component.hpp"
#include "\a3\ui_f\hpp\defineResincl.inc"
#include "..\defines.hpp"
/*
 * Author: LinkIsGrim
 * Add or remove item(s) to favorites when LShift is pressed
 *
 * Arguments:
 * 0: Control <CONTROL>
 * 1: Tree selection path <ARRAY> / Selection index <NUMBER>
 *
 * Return Value:
 * None
 *
 * Public: No
*/
params ["_control", "_selection"];

if !(GVAR(shiftState)) exitWith {};

if (GVAR(currentLeftPanel) in [IDC_buttonFace, IDC_buttonVoice, IDC_buttonInsigina]) exitWith {};

// All panels now use tree controls exclusively
if (count _selection == 0) exitWith {};

private _favorited = false;
private _item = toLowerANSI (_control tvData _selection);

if (_item in GVAR(favorites)) then {
    GVAR(favorites) deleteAt _item;
} else {
    GVAR(favorites) set [_item, nil];
    _favorited = true;
};

private _color = ([[1, 1, 1], GVAR(favoritesColor)] select _favorited) + [1];

// All panels use tree controls - set picture color for favorites
_control tvSetPictureColor [_selection, _color];
