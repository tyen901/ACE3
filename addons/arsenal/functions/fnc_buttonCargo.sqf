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

private _add = _addOrRemove > 0;
private _ctrlTree = _display displayCtrl IDC_rightTabContent;

(["getSelectedLeaf", [_ctrlTree]] call FUNC(treeControlInterface)) params ["_path", "_item"];
if (_path isEqualTo [] || {_item == ""}) exitWith {};

private _metaKey = format ["%1|%2", GVAR(currentRightPanel), toLowerANSI _item];
private _meta = (uiNamespace getVariable [QGVAR(treeRightItemMetaCache), createHashMap]) getOrDefault [_metaKey, [false]];
private _isUnique = _meta param [0, false];

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

private _baseNameCache = uiNamespace getVariable [QGVAR(treeOriginalDisplayNameCache), createHashMap];
private _baseName = _baseNameCache getOrDefault [_metaKey, _ctrlTree tvText _path];
// Find out how many items of that type there are and update the number displayed
["setLeafQuantityText", [_ctrlTree, _path, {_item == _x} count _containerItems, _baseName]] call FUNC(treeControlInterface);

[QGVAR(cargoChanged), [_display, _item, _addOrRemove, GVAR(shiftState)]] call CBA_fnc_localEvent;

// Refresh availability of items based on space remaining in container
[_ctrlTree, _container, _containerItems isNotEqualTo []] call FUNC(updateRightPanel);
