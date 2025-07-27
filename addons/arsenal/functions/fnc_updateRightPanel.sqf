#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Alganthe, johnb43, ACE Team
 * Update the right panel tree control for container availability.
 *
 * Arguments:
 * 0: Right panel tree control <CONTROL>
 * 1: Container <OBJECT>
 * 2: If container has items <BOOL>
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["_treeControl", "_container", "_hasItems"];

private _item = "";
private _alpha = 1;

// Update item availability colors - grey out items that can't fit
private _itemCount = _treeControl tvCount [];
for "_itemIndex" from 0 to (_itemCount - 1) do {
    _item = _treeControl tvData [_itemIndex];
    
    // Skip empty items
    if (_item != "") then {
        // Lower alpha for items that can't fit in container
        _alpha = [0.25, 1] select (_container canAdd _item);
        private _color = [1, 1, 1, _alpha];
        _treeControl tvSetPictureColor [[_itemIndex], _color];
    };
};

private _display = ctrlParent _treeControl;

// If there are items inside container, show "remove all" button
private _removeAllCtrl = _display displayCtrl IDC_buttonRemoveAll;

// A separate "_hasItems" argument is needed, because items can have no mass
_removeAllCtrl ctrlSetFade 0;
_removeAllCtrl ctrlShow _hasItems;
_removeAllCtrl ctrlEnable _hasItems;
_removeAllCtrl ctrlCommit FADE_DELAY;

// Update weight display
(_display displayCtrl IDC_totalWeightText) ctrlSetText (format ["%1 (%2)", GVAR(center) call EFUNC(common,getWeight), [GVAR(center), 1] call EFUNC(common,getWeight)]);

private _curSel = tvCurSel _treeControl;

// Note: Button state management is now handled by dynamic container buttons in createContainerButtons
// This function now only handles item availability colors and remove all button
