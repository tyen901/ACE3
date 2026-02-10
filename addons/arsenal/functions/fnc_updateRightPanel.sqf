#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Alganthe, johnb43
 * Update the right panel (listnbox/tree).
 *
 * Arguments:
 * 0: Right panel control <CONTROL>
 * 1: Container <OBJECT>
 * 2: If container has items <BOOL>
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["_control", "_container", "_hasItems"];

private _metaCache = uiNamespace getVariable [QGVAR(treeRightItemMetaCache), createHashMap];

// Grey out items that are too big to fit in remaining space of the container
{
    private _item = _control tvData _x;
    private _color = [[1, 1, 1, 1], FAVORITES_COLOR] select ((toLowerANSI _item) in GVAR(favorites));

    private _alpha = [0.25, 1] select (_container canAdd _item);
    _color set [3, _alpha];
    _control tvSetColor [_x, _color];
} forEach (["collectLeafPaths", [_control, false]] call FUNC(treeControlInterface));

private _display = ctrlParent _control;

// If there are items inside container, show "remove all" button
private _removeAllCtrl = _display displayCtrl IDC_buttonRemoveAll;

// A separate "_hasItems" argument is needed, because items can have no mass
_removeAllCtrl ctrlSetFade 0;
_removeAllCtrl ctrlShow _hasItems;
_removeAllCtrl ctrlEnable _hasItems;
_removeAllCtrl ctrlCommit FADE_DELAY;

// Update weight display
(_display displayCtrl IDC_totalWeightText) ctrlSetText (format ["%1 (%2)", GVAR(center) call EFUNC(common,getWeight), [GVAR(center), 1] call EFUNC(common,getWeight)]);

(["getSelectedLeaf", [_control]] call FUNC(treeControlInterface)) params ["", "_item"];

private _plusButtonCtrl = _display displayCtrl IDC_arrowPlus;
private _minusButtonCtrl = _display displayCtrl IDC_arrowMinus;

if (_item != "") then {
    private _cacheKey = format ["%1|%2", GVAR(currentRightPanel), toLowerANSI _item];
    private _isUnique = (_metaCache getOrDefault [_cacheKey, [false]]) param [0, false];

    // Disable '+' button if item is unique or too big to fit in remaining space
    _plusButtonCtrl ctrlEnable (!_isUnique && {_container canAdd _item});
    _minusButtonCtrl ctrlEnable true;
} else {
    _plusButtonCtrl ctrlEnable false;
    _minusButtonCtrl ctrlEnable false;
};

_plusButtonCtrl ctrlCommit FADE_DELAY;
_minusButtonCtrl ctrlCommit FADE_DELAY;
