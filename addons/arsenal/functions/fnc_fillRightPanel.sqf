#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Alganthe, johnb43
 * Fills right panel.
 *
 * Arguments:
 * 0: Arsenal display <DISPLAY>
 * 1: Tab control <CONTROL>
 * 2: Animate panel refresh <BOOL> (default: true)
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["_display", "_control", ["_animate", true]];

// Fade old control background
if (!isNil QGVAR(currentRightPanel)) then {
    private _previousCtrlBackground  = _display displayCtrl (GVAR(currentRightPanel) - 1);
    _previousCtrlBackground ctrlSetFade 1;
    _previousCtrlBackground ctrlCommit ([0, FADE_DELAY] select _animate);
};

// Show new control background
private _ctrlIDC = ctrlIDC _control;
private _ctrlBackground = _display displayCtrl (_ctrlIDC - 1);
_ctrlBackground ctrlShow true;
_ctrlBackground ctrlSetFade 0;
_ctrlBackground ctrlCommit ([0, FADE_DELAY] select _animate);

private _searchbarCtrl = _display displayCtrl IDC_rightSearchbar;

// Show right search bar
if (!(ctrlShown _searchbarCtrl) || {ctrlFade _searchbarCtrl > 0}) then {
    _searchbarCtrl ctrlShow true;
    _searchbarCtrl ctrlSetFade 0;
    _searchbarCtrl ctrlCommit 0;
};

private _cfgMagazines = configFile >> "CfgMagazines";
private _cfgWeapons = configFile >> "CfgWeapons";
private _rightPanelCache = uiNamespace getVariable QGVAR(rightPanelCache);

private _currentCargo = []; // we only need this if we're filtering for favorites
if (GVAR(favoritesOnly)) then {
    _currentCargo = itemsWithMagazines GVAR(center) + backpacks GVAR(center);
    _currentCargo = _currentCargo arrayIntersect _currentCargo;
};

private _fnc_fillRightContainer = {
    params ["_configCategory", "_className", ["_isUnique", false, [false]], ["_unknownOrigin", false, [false]]];

    if (GVAR(favoritesOnly) && {!(_className in _currentCargo)} && {!((toLowerANSI _className) in GVAR(favorites))}) exitWith {};

    // If item is not in the arsenal, it must be unique
    if (!_isUnique && {!(_className in GVAR(virtualItemsFlat))}) then {
        _isUnique = true;
    };

    // If not in cache, find info and cache it for later use
    (_rightPanelCache getOrDefaultCall [_configCategory + _className, {
        // Get display name, picture and mass
        private _configPath = configFile >> _configCategory >> _className;

        // "Misc. items" magazines (e.g. spare barrels, intel, photos)
        if (_className in (uiNamespace getVariable QGVAR(magazineMiscItems))) then {
            _configPath = _cfgMagazines >> _className;
        };

        // If an item with unknown origin is in the arsenal list, try to find it
        if (_unknownOrigin && {isNull _configPath}) then {
            _configPath = _className call CBA_fnc_getItemConfig;

            // Check if item is object (this should never happen)
            if (isNull _configPath) then {
                _configPath = _className call CBA_fnc_getObjectConfig;
            };
        };

        [getText (_configPath >> "displayName"), getText (_configPath >> "picture")]
    }, true]) params ["_displayName", "_picture"];

    // Use tree control instead of listnbox
    private _lbAdd = _ctrlPanel tvAdd [[], _displayName];
    _ctrlPanel tvSetData [[_lbAdd], _className];
    _ctrlPanel tvSetPicture [[_lbAdd], _picture];
    _ctrlPanel tvSetTooltip [[_lbAdd], format ["%1\n%2", _displayName, _className]];
    
    // Store original display name in a clean way using global hashmap
    if (isNil QGVAR(originalDisplayNames)) then {
        GVAR(originalDisplayNames) = createHashMap;
    };
    GVAR(originalDisplayNames) set [_className, _displayName];
    
    if ((toLowerANSI _className) in GVAR(favorites)) then {
        _ctrlPanel tvSetPictureColor [[_lbAdd], FAVORITES_COLOR];
    };
};

private _ctrlPanel = _display displayCtrl IDC_rightTabContent;

// Retrieve compatible items
private _isContainer = false;
private _selectedItem = "";
private _compatibleItems = [];
private _compatibleMagsMuzzle = [];
private _compatibleMagsAll = createHashMap;

switch (GVAR(currentLeftPanel)) do {
    // If weapons or binoculars are chosen, get their compatible magazines & items
    // Weapons and binoculars
    case IDC_buttonPrimaryWeapon;
    case IDC_buttonHandgun;
    case IDC_buttonSecondaryWeapon;
    case IDC_buttonBinoculars: {
        (switch (GVAR(currentLeftPanel)) do {
            case IDC_buttonPrimaryWeapon: {
                [IDX_CURR_PRIMARY_WEAPON, IDX_CURR_PRIMARY_WEAPON_ITEMS]
            };
            case IDC_buttonHandgun: {
                [IDX_CURR_HANDGUN_WEAPON, IDX_CURR_HANDGUN_WEAPON_ITEMS]
            };
            case IDC_buttonSecondaryWeapon: {
                [IDX_CURR_SECONDARY_WEAPON, IDX_CURR_SECONDARY_WEAPON_ITEMS]
            };
            case IDC_buttonBinoculars: {
                [IDX_CURR_BINO, IDX_CURR_BINO_ITEMS]
            };
        }) params ["_currentWeaponIndex", "_currentWeaponItemsIndex"];

        private _index = [IDC_buttonMuzzle, IDC_buttonItemAcc, IDC_buttonOptic, IDC_buttonBipod, IDC_buttonCurrentMag, IDC_buttonCurrentMag2] find _ctrlIDC;
        private _weapon = GVAR(currentItems) select _currentWeaponIndex;

        // Check if weapon attachement or magazine
        if (_index != -1) then {
            _selectedItem = (GVAR(currentItems) select _currentWeaponItemsIndex) select _index;

            // If weapon attachment, get base weapon; Get compatible items
            if (_index <= 3) then {
                _compatibleItems = compatibleItems _weapon;
                _selectedItem = _selectedItem call FUNC(baseWeapon);
            } else {
                // Get compatible magazines for primary & secondary muzzle (secondary muzzle is not guaranteed to exist)
                // Assumption: One weapon can have two muzzles maximum
                _compatibleMagsMuzzle = compatibleMagazines [_weapon, (_weapon call CBA_fnc_getMuzzles) param [_index - 4, ""]];
            };
        };
    };
    // Uniform, vest or backpack
    case IDC_buttonUniform;
    case IDC_buttonVest;
    case IDC_buttonBackpack: {
        _isContainer = true;

        // Get the currently selected item in tree panel
        private _treeSelection = tvCurSel _ctrlPanel;

        // If something is selected, save it
        if (count _treeSelection == 1) then {
            _selectedItem = _ctrlPanel tvData _treeSelection;
        };

        // This is for the "compatible magazines" tab when a container is open
        if (_ctrlIDC == IDC_buttonMag) then {
            // Get all compatibles magazines with unit's weapons (including compatible magazines that aren't in configItems)
            {
                _compatibleMagsAll insert [true, compatibleMagazines _x, []];
            } forEach [GVAR(currentItems) select IDX_CURR_PRIMARY_WEAPON, GVAR(currentItems) select IDX_CURR_HANDGUN_WEAPON, GVAR(currentItems) select IDX_CURR_SECONDARY_WEAPON, GVAR(currentItems) select IDX_CURR_BINO];
        };
        
        // Don't exit - let the switch statement continue to populate items based on right panel tab
    };
};

// Reset right panel content - now using tree control consistently
tvClear _ctrlPanel;
_ctrlPanel tvSetCurSel [];

// Force a "refresh" animation of the panel
if (_animate) then {
    _ctrlPanel ctrlSetFade 1;
    _ctrlPanel ctrlCommit 0;
    _ctrlPanel ctrlSetFade 0;
    _ctrlPanel ctrlCommit FADE_DELAY;
};

// Check if the left panel is a weapon. If so, right panel will be compatible items with weapon only
private _leftPanelState = GVAR(currentLeftPanel) in [IDC_buttonPrimaryWeapon, IDC_buttonHandgun, IDC_buttonSecondaryWeapon, IDC_buttonBinoculars];

// Add an empty entry if left panel is a weapon or bino
if (_leftPanelState && {_ctrlIDC in [RIGHT_PANEL_ACC_IDCS, IDC_buttonCurrentMag, IDC_buttonCurrentMag2]}) then {
    private _addEmpty = _ctrlPanel tvAdd [[], format [" <%1>", localize "str_empty"]];
    _ctrlPanel tvSetValue [[_addEmpty], -1];
};

// Fill right panel according to category choice
switch (_ctrlIDC) do {
    // Optics, flashlights, muzzle attachments, bipods
    case IDC_buttonOptic;
    case IDC_buttonItemAcc;
    case IDC_buttonMuzzle;
    case IDC_buttonBipod: {
        private _index = [IDX_VIRT_OPTICS_ATTACHMENTS, IDX_VIRT_FLASHLIGHT_ATTACHMENTS, IDX_VIRT_MUZZLE_ATTACHMENTS, IDX_VIRT_BIPOD_ATTACHMENTS] select ([RIGHT_PANEL_ACC_IDCS] find _ctrlIDC);

        if (_leftPanelState) then {
            {
                if (_x in ((GVAR(virtualItems) get IDX_VIRT_ATTACHMENTS) get _index)) then {
                    ["CfgWeapons", _x] call _fnc_fillRightContainer;
                };
            } forEach _compatibleItems;
        } else {
            {
                ["CfgWeapons", _x] call _fnc_fillRightContainer;
            } forEach (keys ((GVAR(virtualItems) get IDX_VIRT_ATTACHMENTS) get _index));

            {
                ["CfgWeapons", _x, true] call _fnc_fillRightContainer;
            } forEach (keys ((GVAR(virtualItems) get IDX_VIRT_UNIQUE_ATTACHMENTS) get _index));
        };
    };
    // Current primary & secondary muzzle compatible magazines
    case IDC_buttonCurrentMag;
    case IDC_buttonCurrentMag2: {
        if (_leftPanelState) then {
            {
                if (_x in (GVAR(virtualItems) get IDX_VIRT_ITEMS_ALL)) then {
                    ["CfgMagazines", _x] call _fnc_fillRightContainer;
                };
            } forEach _compatibleMagsMuzzle;
        };
    };
    // All compatible magazines
    case IDC_buttonMag: {
        {
            if (_x in (GVAR(virtualItems) get IDX_VIRT_ITEMS_ALL)) then {
                ["CfgMagazines", _x] call _fnc_fillRightContainer;

                continue;
            };

            if (_x in (GVAR(virtualItems) get IDX_VIRT_UNIQUE_VIRT_ITEMS_ALL)) then {
                ["CfgMagazines", _x, true] call _fnc_fillRightContainer;
            };
        } forEach (keys _compatibleMagsAll);
    };
    // All magazines
    case IDC_buttonMagALL: {
        {
            ["CfgMagazines", _x] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_ITEMS_ALL));

        {
            ["CfgMagazines", _x, true] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_UNIQUE_VIRT_ITEMS_ALL));
    };
    // Grenades
    case IDC_buttonThrow: {
        {
            ["CfgMagazines", _x] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_GRENADES));

        {
            ["CfgMagazines", _x, true] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_UNIQUE_GRENADES));
    };
    // Explosives
    case IDC_buttonPut: {
        {
            ["CfgMagazines", _x] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_EXPLOSIVES));

        {
            ["CfgMagazines", _x, true] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_UNIQUE_EXPLOSIVES));
    };
    // Misc. items
    case IDC_buttonMisc: {
        // Don't add items that will be in a custom right panel button
        private _items = createHashMap;

        if (!isNil QGVAR(customRightPanelButtons)) then {
            {
                if (!isNil "_x") then {
                    _items insert [true, _x select 0, []];
                };
            } forEach GVAR(customRightPanelButtons);
        };

        // "Regular" misc. items
        {
            if !(_x in _items) then {
                ["CfgWeapons", _x] call _fnc_fillRightContainer;
            };
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_MISC_ITEMS));
        // Unique items
        {
            if !(_x in _items) then {
                ["CfgWeapons", _x, true] call _fnc_fillRightContainer;
            };
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_UNIQUE_MISC_ITEMS));
        // Unique backpacks
        {
            if !(_x in _items) then {
                ["CfgVehicles", _x, true] call _fnc_fillRightContainer;
            };
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_UNIQUE_BACKPACKS));
        // Unique goggles
        {
            if !(_x in _items) then {
                // _y indicates if an item is truly unique or if it's a non-inventory item in a container (e.g. goggles in backpack)
                ["CfgGlasses", _x, _y] call _fnc_fillRightContainer;
            };
        } forEach (GVAR(virtualItems) get IDX_VIRT_UNIQUE_GOGGLES);
        // Unknown items
        {
            if !(_x in _items) then {
                // _y indicates if an item is truly unique or if it's a non-inventory item in a container (e.g. helmet in backpack)
                ["CfgWeapons", _x, _y, true] call _fnc_fillRightContainer;
            };
        } forEach (GVAR(virtualItems) get IDX_VIRT_UNIQUE_UNKNOWN_ITEMS); // if an item is here but in virtual items, it's just in the wrong place
    };
    // Custom buttons
    default {
        private _items = (GVAR(customRightPanelButtons) param [[RIGHT_PANEL_CUSTOM_BUTTONS] find _ctrlIDC, []]) param [0, []];

        if (_items isNotEqualTo []) then {
            {

                switch (true) do {
                    // "Regular" misc. items
                    case (_x in (GVAR(virtualItems) get IDX_VIRT_MISC_ITEMS)): {
                        ["CfgWeapons", _x] call _fnc_fillRightContainer;
                    };
                    // Unique items
                    case (_x in (GVAR(virtualItems) get IDX_VIRT_UNIQUE_MISC_ITEMS)): {
                        ["CfgWeapons", _x, true] call _fnc_fillRightContainer;
                    };
                    // Unique backpacks
                    case (_x in (GVAR(virtualItems) get IDX_VIRT_UNIQUE_BACKPACKS)): {
                        ["CfgVehicles", _x, true] call _fnc_fillRightContainer;
                    };
                    // Unique goggles
                    case (_x in (GVAR(virtualItems) get IDX_VIRT_UNIQUE_GOGGLES)): {
                        ["CfgGlasses", _x, GVAR(virtualItems) get IDX_VIRT_UNIQUE_GOGGLES get _x] call _fnc_fillRightContainer;
                    };
                    // Unknown items
                    case (_x in (GVAR(virtualItems) get IDX_VIRT_UNIQUE_UNKNOWN_ITEMS)): {
                        ["CfgWeapons", _x, GVAR(virtualItems) get IDX_VIRT_UNIQUE_UNKNOWN_ITEMS get _x, true] call _fnc_fillRightContainer;
                    };
                };
            } forEach _items;
        };
    };
};

// When switching tabs, clear searchbox
if (GVAR(currentRightPanel) != _ctrlIDC) then {
    (_display displayCtrl IDC_rightSearchbar) ctrlSetText "";
};

// Trigger event
GVAR(currentRightPanel) = _ctrlIDC;
[QGVAR(rightPanelFilled), [_display, GVAR(currentLeftPanel), _ctrlIDC]] call CBA_fnc_localEvent;

// Handle container display with new tree-based system
if (_isContainer) then {
    private _containerItems = [];
    private _container = "";
    private _containerType = "";
    
    switch (GVAR(currentLeftPanel)) do {
        // Uniform
        case IDC_buttonUniform: {
            // Update load bar
            (_display displayCtrl IDC_loadIndicatorBar) progressSetPosition (loadUniform GVAR(center));
            
            _containerItems = uniformItems GVAR(center);
            _container = uniformContainer GVAR(center);
            _containerType = "uniform";
        };
        // Vest
        case IDC_buttonVest: {
            // Update load bar
            (_display displayCtrl IDC_loadIndicatorBar) progressSetPosition (loadVest GVAR(center));
            
            _containerItems = vestItems GVAR(center);
            _container = vestContainer GVAR(center);
            _containerType = "vest";
        };
        // Backpack
        case IDC_buttonBackpack: {
            // Update load bar
            (_display displayCtrl IDC_loadIndicatorBar) progressSetPosition (loadBackpack GVAR(center));
            
            _containerItems = backpackItems GVAR(center);
            _container = backpackContainer GVAR(center);
            _containerType = "backpack";
        };
    };
    
    // Find out how many items of a type there are and update the number displayed
    for "_lbIndex" from 0 to (_ctrlPanel tvCount []) - 1 do {
        private _xItem = _ctrlPanel tvData [_lbIndex];
        // Count items in container 
        private _count = {_xItem == _x} count _containerItems;
        
        // Store count as tree value (like listnbox column 2)
        _ctrlPanel tvSetValue [[_lbIndex], _count];
        
        // Get original display name from our clean hashmap
        private _originalName = GVAR(originalDisplayNames) getOrDefault [_xItem, "Unknown"];
        
        // Always update display text - show quantity if > 0, otherwise just name
        if (_count > 0) then {
            _ctrlPanel tvSetText [[_lbIndex], format ["%1 (x%2)", _originalName, _count]];
        } else {
            _ctrlPanel tvSetText [[_lbIndex], _originalName];
        };
    };

    // Refresh availability of items based on space remaining in container
    [_ctrlPanel, _container, _containerItems isNotEqualTo []] call FUNC(updateRightPanel);
    
    // Create dynamic +/- buttons for each container item
    [_display, _ctrlPanel, _container, _containerItems] call FUNC(createContainerButtons);
};

// Clean up any existing container buttons when not in container mode
if (!_isContainer) then {
    private _existingButtons = uiNamespace getVariable [QGVAR(containerButtons), []];
    {
        ctrlDelete _x;
    } forEach _existingButtons;
    uiNamespace setVariable [QGVAR(containerButtons), []];
};

// Sorting
[_display, _control, _display displayCtrl IDC_sortRightTab, _display displayCtrl IDC_sortRightTabDirection] call FUNC(fillSort);

// Restore selection using unified tree logic
if (_selectedItem != "") then {
    private _found = false;
    private _itemCount = _ctrlPanel tvCount [];
    
    // Search through flat tree to find the selected item
    for "_itemIndex" from 0 to (_itemCount - 1) do {
        if ((_ctrlPanel tvData [_itemIndex]) == _selectedItem) exitWith {
            _ctrlPanel tvSetCurSel [_itemIndex];
            _found = true;
        };
    };
    
    // If not found, select first available item
    if (!_found && _itemCount > 0) then {
        _ctrlPanel tvSetCurSel [0];
    };
} else {
    // No previous selection - select first item if available
    if ((_ctrlPanel tvCount []) > 0) then {
        _ctrlPanel tvSetCurSel [0];
    };
};

