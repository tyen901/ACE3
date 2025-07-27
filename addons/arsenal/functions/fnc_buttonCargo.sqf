#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Alganthe, johnb43
 * Add or remove item(s) when the + or - button is pressed in the right panel.
 *
 * Arguments:
 * 0: Arsenal display <DISPLAY>
 * 1: Add (1) or remove (-1) item <NUMBER>
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["_display", "_addOrRemove"];

if !(GVAR(currentLeftPanel) in [IDC_buttonUniform, IDC_buttonVest, IDC_buttonBackpack]) exitWith {};

private _add = _addOrRemove > 0;

private _ctrlTree = _display displayCtrl IDC_rightTabContent;
private _treeCurSel = tvCurSel _ctrlTree;

// Exit if no selection or invalid selection
if (count _treeCurSel != 1) exitWith {};

private _item = _ctrlTree tvData _treeCurSel;

// Exit if no valid item selected
if (_item == "") exitWith {
    TRACE_2("Invalid item selected for cargo operation",_item,_treeCurSel);
};

// Check if item is unique (for backpacks and special items)
private _isUnique = _item in ((uiNamespace getVariable QGVAR(configItems)) get IDX_VIRT_BACKPACK);

// If item is unique, don't allow adding more
if (_add && {_isUnique}) exitWith {};

private _containerItems = [];

// Update item count and currentItems array & get relevant container
private _container = switch (GVAR(currentLeftPanel)) do {
    // Uniform
    case IDC_buttonUniform: {
        if (_add) then {
            for "_i" from 1 to ([1, 5] select GVAR(shiftState)) do {
                GVAR(center) addItemToUniform _item;
            };
        } else {
            // Backpacks need special command to be removed
            if (_isUnique && {_item in ((uiNamespace getVariable QGVAR(configItems)) get IDX_VIRT_BACKPACK)}) then {
                [uniformContainer GVAR(center), _item, [1, 5] select GVAR(shiftState)] call CBA_fnc_removeBackpackCargo;
            } else {
                for "_i" from 1 to ([1, 5] select GVAR(shiftState)) do {
                    GVAR(center) removeItemFromUniform _item;
                };
            };
        };

        // Get all items from container
        _containerItems = uniformItems GVAR(center);

        // Update currentItems
        GVAR(currentItems) set [IDX_CURR_UNIFORM_ITEMS, ((getUnitLoadout GVAR(center)) select IDX_LOADOUT_UNIFORM) param [1, []]];

        // Update load bar
        (_display displayCtrl IDC_loadIndicatorBar) progressSetPosition (loadUniform GVAR(center));

        uniformContainer GVAR(center)
    };
    // Vest
    case IDC_buttonVest: {
        if (_add) then {
            for "_i" from 1 to ([1, 5] select GVAR(shiftState)) do {
                GVAR(center) addItemToVest _item;
            };
        } else {
            // Backpacks need special command to be removed
            if (_isUnique && {_item in ((uiNamespace getVariable QGVAR(configItems)) get IDX_VIRT_BACKPACK)}) then {
                [vestContainer GVAR(center), _item, [1, 5] select GVAR(shiftState)] call CBA_fnc_removeBackpackCargo;
            } else {
                for "_i" from 1 to ([1, 5] select GVAR(shiftState)) do {
                    GVAR(center) removeItemFromVest _item;
                };
            };
        };

        // Get all items from container
        _containerItems = vestItems GVAR(center);

        // Update currentItems
        GVAR(currentItems) set [IDX_CURR_VEST_ITEMS, ((getUnitLoadout GVAR(center)) select IDX_LOADOUT_VEST) param [1, []]];

        // Update load bar
        (_display displayCtrl IDC_loadIndicatorBar) progressSetPosition (loadVest GVAR(center));

        vestContainer GVAR(center)
    };
    // Backpack
    case IDC_buttonBackpack: {
        if (_add) then {
            for "_i" from 1 to ([1, 5] select GVAR(shiftState)) do {
                GVAR(center) addItemToBackpack _item;
            };
        } else {
            // Backpacks need special command to be removed
            if (_isUnique && {_item in ((uiNamespace getVariable QGVAR(configItems)) get IDX_VIRT_BACKPACK)}) then {
                [backpackContainer GVAR(center), _item, [1, 5] select GVAR(shiftState)] call CBA_fnc_removeBackpackCargo;
            } else {
                for "_i" from 1 to ([1, 5] select GVAR(shiftState)) do {
                    GVAR(center) removeItemFromBackpack _item;
                };
            };
        };

        // Get all items from container
        _containerItems = backpackItems GVAR(center);

        // Update currentItems
        GVAR(currentItems) set [IDX_CURR_BACKPACK_ITEMS, ((getUnitLoadout GVAR(center)) select IDX_LOADOUT_BACKPACK) param [1, []]];

        // Update load bar
        (_display displayCtrl IDC_loadIndicatorBar) progressSetPosition (loadBackpack GVAR(center));

        backpackContainer GVAR(center)
    };
};

[QGVAR(cargoChanged), [_display, _item, _addOrRemove, GVAR(shiftState)]] call CBA_fnc_localEvent;

// Get updated container items after the operation
private _updatedContainerItems = switch (GVAR(currentLeftPanel)) do {
    case IDC_buttonUniform: { uniformItems GVAR(center) };
    case IDC_buttonVest: { vestItems GVAR(center) };
    case IDC_buttonBackpack: { backpackItems GVAR(center) };
    default { [] };
};

// Update the quantity display for the specific item in the tree
private _currentQuantity = {_item == _x} count _updatedContainerItems;
_ctrlTree tvSetValue [_treeCurSel, _currentQuantity];

// Get original display name and update text with new quantity
private _originalName = GVAR(originalDisplayNames) getOrDefault [_item, "Unknown"];
if (_currentQuantity > 0) then {
    _ctrlTree tvSetText [_treeCurSel, format ["%1 (x%2)", _originalName, _currentQuantity]];
} else {
    _ctrlTree tvSetText [_treeCurSel, _originalName];
};

// Refresh availability of items based on space remaining in container
[_ctrlTree, _container, _updatedContainerItems isNotEqualTo []] call FUNC(updateRightPanel);

// Refresh the dynamic container buttons with updated states
[_display, _ctrlTree, _container, _updatedContainerItems] call FUNC(createContainerButtons);
