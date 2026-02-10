#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Alganthe, johnb43
 * Clear the current container.
 *
 * Arguments:
 * 0: Arsenal display <DISPLAY>
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["_display"];

// Clear chosen container, reset currentItems for that container and get relevant container
private _container = switch (GVAR(currentLeftPanel)) do {
    // Uniform
    case IDC_buttonUniform: {
        private _container = uniformContainer GVAR(center);

        // Remove everything (backpacks need special command for this)
        clearWeaponCargoGlobal _container;
        clearMagazineCargoGlobal _container;
        clearItemCargoGlobal _container;
        clearBackpackCargoGlobal _container;

        GVAR(currentItems) set [IDX_CURR_UNIFORM_ITEMS, []];

        _container
    };
    // Vest
    case IDC_buttonVest: {
        private _container = vestContainer GVAR(center);

        // Remove everything (backpacks need special command for this)
        clearWeaponCargoGlobal _container;
        clearMagazineCargoGlobal _container;
        clearItemCargoGlobal _container;
        clearBackpackCargoGlobal _container;

        GVAR(currentItems) set [IDX_CURR_VEST_ITEMS, []];

        _container
    };
    // Backpack
    case IDC_buttonBackpack: {
        // Remove everything
        clearAllItemsFromBackpack GVAR(center);

        GVAR(currentItems) set [IDX_CURR_BACKPACK_ITEMS, []];

        backpackContainer GVAR(center)
    };
};

private _ctrlTree = _display displayCtrl IDC_rightTabContent;
private _nameCache = uiNamespace getVariable [QGVAR(treeOriginalDisplayNameCache), createHashMap];

// Clear number of owned items
{
    private _item = _ctrlTree tvData _x;
    if (_item == "") then { continue; };

    private _key = format ["%1|%2", GVAR(currentRightPanel), toLowerANSI _item];
    ["setLeafQuantityText", [_ctrlTree, _x, 0, _nameCache getOrDefault [_key, _ctrlTree tvText _x]]] call FUNC(treeControlInterface);
} forEach (["collectLeafPaths", [_ctrlTree, false]] call FUNC(treeControlInterface));

// Update load bar
(_display displayCtrl IDC_loadIndicatorBar) progressSetPosition 0;

// Refresh availability of items based on space remaining in container
[_ctrlTree, _container, false] call FUNC(updateRightPanel);
