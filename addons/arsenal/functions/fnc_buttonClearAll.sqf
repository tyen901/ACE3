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

// Clear number of owned items and refresh right panel
private _ctrlTree = _display displayCtrl IDC_rightTabContent;

// Reset all item quantities to 0 in the tree display
for "_lbIndex" from 0 to (_ctrlTree tvCount []) - 1 do {
    private _xItem = _ctrlTree tvData [_lbIndex];
    if (_xItem != "") then {
        // Set quantity to 0
        _ctrlTree tvSetValue [[_lbIndex], 0];
        
        // Update display text to remove quantity
        private _originalName = GVAR(originalDisplayNames) getOrDefault [_xItem, "Unknown"];
        _ctrlTree tvSetText [[_lbIndex], _originalName];
    };
};

// Update load bar
(_display displayCtrl IDC_loadIndicatorBar) progressSetPosition 0;

// Refresh availability of items based on space remaining in container
[_ctrlTree, _container, false] call FUNC(updateRightPanel);

// Refresh the dynamic container buttons with updated states (all should be disabled for minus, enabled for plus)
[_display, _ctrlTree, _container, []] call FUNC(createContainerButtons);
