#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Alganthe, Dedmen, Brett Mayson, johnb43
 * Sort an arsenal panel.
 *
 * Arguments:
 * 0: Control <CONTROL>
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["_control"];

// https://community.bistudio.com/wiki/toString, see comment
// However, using 55295 did not work as expected, 55291 was found by trial and error
#define HIGHEST_VALUE_CHAR 55291

// When filling the sorting panel, FUNC(sortPanel) is called twice, so ignore first call
if (GVAR(ignoreFirstSortPanelCall)) exitWith {
    GVAR(ignoreFirstSortPanelCall) = false;
};

private _display = ctrlParent _control;
private _rightSort = (ctrlIDC _control) in [IDC_sortRightTab, IDC_sortRightTabDirection];
private _right = _rightSort && {GVAR(currentLeftPanel) in [IDC_buttonUniform, IDC_buttonVest, IDC_buttonBackpack]};
private _sortCtrl = _display displayCtrl ([IDC_sortLeftTab, IDC_sortRightTab] select _rightSort);
private _sortDirectionCtrl = _display displayCtrl ([IDC_sortLeftTabDirection, IDC_sortRightTabDirection] select _rightSort);

private _cfgMagazines = configFile >> "CfgMagazines";
private _cfgFaces = configFile >> "CfgFaces";
private _cfgUnitInsignia = configFile >> "CfgUnitInsignia";
private _cfgUnitInsigniaCampaign = campaignConfigFile >> "CfgUnitInsignia";
private _cfgUnitInsigniaMission = missionConfigFile >> "CfgUnitInsignia";

if (_rightSort) then {
    [
        _display displayCtrl IDC_rightTabContent,
        switch (GVAR(currentRightPanel)) do {
            case IDC_buttonCurrentMag;
            case IDC_buttonCurrentMag2;
            case IDC_buttonThrow;
            case IDC_buttonPut;
            case IDC_buttonMag;
            case IDC_buttonMagALL: {_cfgMagazines};
            default {configFile >> "CfgWeapons"};
        },
        GVAR(sortListRightPanel) select (
            switch (GVAR(currentRightPanel)) do {
                case IDC_buttonOptic: { 0 };
                case IDC_buttonItemAcc: { 1 };
                case IDC_buttonMuzzle: { 2 };
                case IDC_buttonBipod: { 3 };
                case IDC_buttonCurrentMag;
                case IDC_buttonCurrentMag2;
                case IDC_buttonMag;
                case IDC_buttonMagALL: { 4 };
                case IDC_buttonThrow: { 5 };
                case IDC_buttonPut: { 6 };
                case IDC_buttonMisc: { 7 };
            }
        )
    ]
} else {
    [
        _display displayCtrl IDC_leftTabContent,
        switch (GVAR(currentLeftPanel)) do {
            case IDC_buttonBackpack: {configFile >> "CfgVehicles"};
            case IDC_buttonGoggles: {configFile >> "CfgGlasses"};
            case IDC_buttonFace: {_cfgFaces};
            case IDC_buttonVoice: {configFile >> "CfgVoice"};
            case IDC_buttonInsignia: {_cfgUnitInsignia};
            default {configFile >> "CfgWeapons"};
        },
        (GVAR(sortListLeftPanel) select ([
            IDC_buttonPrimaryWeapon,
            IDC_buttonHandgun,
            IDC_buttonSecondaryWeapon,
            IDC_buttonUniform,
            IDC_buttonVest,
            IDC_buttonBackpack,
            IDC_buttonHeadgear,
            IDC_buttonGoggles,
            IDC_buttonNVG,
            IDC_buttonBinoculars,
            IDC_buttonMap,
            IDC_buttonGPS,
            IDC_buttonRadio,
            IDC_buttonCompass,
            IDC_buttonWatch,
            IDC_buttonFace,
            IDC_buttonVoice,
            IDC_buttonInsignia
        ] find GVAR(currentLeftPanel)))
    ]
} params ["_panel", "_cfgClass", "_sorts"];

// Get sort & sort direction
private _sortName = _sortCtrl lbData (0 max lbCurSel _sortCtrl);
private _sortDirection = _sortDirectionCtrl lbValue (0 max lbCurSel _sortDirectionCtrl);
(_sorts select (0 max (_sorts findIf {(_x select 0) == _sortName}))) params ["", "_displayName", "_statement"];

// Update last sort & sort direction
missionNamespace setVariable [
    [QGVAR(lastSortLeft), QGVAR(lastSortRight)] select _rightSort,
    _displayName
];

missionNamespace setVariable [
    [QGVAR(lastSortDirectionLeft), QGVAR(lastSortDirectionRight)] select _rightSort,
    _sortDirection
];

// Get currently selected item - all panels now use tree controls
private _curSel = tvCurSel _panel;  // Tree selection returns path array

private _selected = if (count _curSel > 0) then {
    _panel tvData _curSel
} else {
    ""
};

private _item = "";
private _quantity = "";
private _itemCfg = configNull;
private _value = "";
private _name = "";
private _fillerChar = toString [1];

private _magazineMiscItems = uiNamespace getVariable QGVAR(magazineMiscItems);
private _sortCache = uiNamespace getVariable QGVAR(sortCache);
private _faceCache = uiNamespace getVariable QGVAR(faceCache);
private _insigniaCache = uiNamespace getVariable QGVAR(insigniaCache);

// All panels now use tree controls - collect all items from tree structure for sorting
private _treeItems = [];
private _groupCount = _panel tvCount [];

// Check if this is a flat structure (right panel) or grouped structure (left panel)
private _isFlat = _rightSort && !_right;
if (_isFlat) then {
    // Right panel uses flat structure - all items are at root level
    for "_itemIndex" from 0 to (_groupCount - 1) do {
        _treeItems pushBack [_itemIndex];
    };
} else {
    // Left panel or right panel containers use grouped structure
    for "_groupIndex" from 0 to (_groupCount - 1) do {
        private _itemCount = _panel tvCount [_groupIndex];
        for "_itemIndex" from 0 to (_itemCount - 1) do {
            _treeItems pushBack [_groupIndex, _itemIndex];
        };
    };
};

private _for = for "_i" from 0 to (count _treeItems) - 1;

//IGNORE_PRIVATE_WARNING ["_i"];
_for do {
    // Get item from tree path
    private _itemPath = _treeItems select _i;
    _item = _panel tvData _itemPath;

    // Skip empty or group entries for tree
    if (_item == "" || {_item find "GROUP_" == 0}) then {
        continue;
    };

    // Get item's count (for right panel containers, this may be stored in tree value)
    _quantity = if (_rightSort && {_right}) then {
        _panel tvValue _itemPath
    } else {
        0
    };

    // "Misc. items" magazines (e.g. spare barrels, intel, photos)
    if (_item in _magazineMiscItems) then {
        _cfgClass = _cfgMagazines;
    };

    // Check item's config
    _itemCfg = if !(_cfgClass in [_cfgFaces, _cfgUnitInsignia]) then {
        _cfgClass >> _item
    } else {
        // If insignia, check for correct config: First mission, then campaign and finally regular config
        if (_cfgClass == _cfgUnitInsignia) then {
            _itemCfg = _cfgUnitInsigniaMission >> _item;

            if (isNull _itemCfg) then {
                _itemCfg = _cfgUnitInsigniaCampaign >> _item;
            };

            if (isNull _itemCfg) then {
                _itemCfg = _cfgUnitInsignia >> _item;
            };

            _itemCfg
        } else {
            // If face, check correct category
            _cfgClass >> (_faceCache getOrDefault [_item, []]) param [2, "Man_A3"] >> _item
        };
    };

    // Some items may not belong to the config class for the panel (e.g. misc. items panel can have unique items)
    if (isNull _itemCfg) then {
        _itemCfg = _item call CBA_fnc_getItemConfig;
    };

    // Value can be any type
    _value = _sortCache getOrDefaultCall [format ["%1_%2_%3", _sortName, _item, _quantity], {
        private _value = [_itemCfg, _item, _quantity] call _statement;

        // If number, convert to string (keep 2 decimal after comma; Needed for correct weight sorting)
        if (_value isEqualType 0) then {
            _value = [_value, 8, 2] call CBA_fnc_formatNumber;
        };

        // If empty string, add alphabetically small char at beginning to make it sort correctly
        if (_value isEqualTo "") then {
            _value = "_";
        };

        _value
    }, true];

    // Set the sort data temporarily in tooltip for tree sorting
    if (_item != "") then {
        private _itemPath = _treeItems select _i;
        private _displayName = _panel tvText _itemPath;
        // Store sort value in tooltip temporarily
        _panel tvSetTooltip [_itemPath, format ["%1%2%4%3", _value, _displayName, _item, _fillerChar]];
    };
};

// Custom tree sorting - handle both flat and grouped structures
private _selectedPath = [];

if (_isFlat) then {
    // Right panel uses flat structure - sort all items at root level
    private _allItems = [];
    private _itemCount = _panel tvCount [];
    
    // Collect all items with their sort data
    for "_itemIndex" from 0 to (_itemCount - 1) do {
        private _itemPath = [_itemIndex];
        private _sortData = _panel tvTooltip _itemPath;
        private _itemData = _panel tvData _itemPath;
        private _itemText = _panel tvText _itemPath;
        private _itemPicture = _panel tvPicture _itemPath;
        private _itemPictureRight = _panel tvPictureRight _itemPath;
        private _itemValue = _panel tvValue _itemPath;
        
        _allItems pushBack [_sortData, _itemData, _itemText, _itemPicture, _itemPictureRight, _itemValue];
        
        // Track selected item
        if (_itemData == _selected) then {
            _selectedPath = [count _allItems - 1]; // Will be updated after sort
        };
    };
    
    // Sort all items
    _allItems sort (_sortDirection == ASCENDING);
    
    // Clear and repopulate with sorted items
    tvClear _panel;
    
    {
        _x params ["_sortData", "_itemData", "_itemText", "_itemPicture", "_itemPictureRight", "_itemValue"];
        private _newItemIndex = _panel tvAdd [[], _itemText];
        _panel tvSetData [[_newItemIndex], _itemData];
        _panel tvSetPicture [[_newItemIndex], _itemPicture];
        _panel tvSetPictureRight [[_newItemIndex], _itemPictureRight];
        _panel tvSetValue [[_newItemIndex], _itemValue];
        
        // Restore favorites color if needed
        if ((toLowerANSI _itemData) in GVAR(favorites)) then {
            _panel tvSetPictureColor [[_newItemIndex], FAVORITES_COLOR];
        };
        
        // Restore original tooltip (remove sort data)
        private _originalTooltip = format ["%1\n%2", _itemText, _itemData];
        _panel tvSetTooltip [[_newItemIndex], _originalTooltip];
        
        // Update selected path
        if (_itemData == _selected) then {
            _selectedPath = [_newItemIndex];
        };
    } forEach _allItems;
} else {
    // Left panel or right panel containers use grouped structure - sort items within each group
    private _groupCount = _panel tvCount [];
    
    for "_groupIndex" from 0 to (_groupCount - 1) do {
        private _itemsInGroup = [];
        private _itemCount = _panel tvCount [_groupIndex];
        
        // Collect items with their sort data
        for "_itemIndex" from 0 to (_itemCount - 1) do {
            private _itemPath = [_groupIndex, _itemIndex];
            private _sortData = _panel tvTooltip _itemPath;
            private _itemData = _panel tvData _itemPath;
            private _itemText = _panel tvText _itemPath;
            private _itemPicture = _panel tvPicture _itemPath;
            private _itemPictureRight = _panel tvPictureRight _itemPath;
            private _itemValue = _panel tvValue _itemPath;
            
            _itemsInGroup pushBack [_sortData, _itemData, _itemText, _itemPicture, _itemPictureRight, _itemValue];
            
            // Track selected item
            if (_itemData == _selected) then {
                _selectedPath = [_groupIndex, count _itemsInGroup - 1]; // Will be updated after sort
            };
        };
        
        // Sort items within group
        _itemsInGroup sort (_sortDirection == ASCENDING);
        
        // Clear group and repopulate with sorted items
        for "_itemIndex" from (_itemCount - 1) to 0 step -1 do {
            _panel tvDelete [_groupIndex, _itemIndex];
        };
        
        // Add sorted items back
        {
            _x params ["_sortData", "_itemData", "_itemText", "_itemPicture", "_itemPictureRight", "_itemValue"];
            private _newItemIndex = _panel tvAdd [[_groupIndex], _itemText];
            _panel tvSetData [[_groupIndex, _newItemIndex], _itemData];
            _panel tvSetPicture [[_groupIndex, _newItemIndex], _itemPicture];
            _panel tvSetPictureRight [[_groupIndex, _newItemIndex], _itemPictureRight];
            _panel tvSetValue [[_groupIndex, _newItemIndex], _itemValue];
            
            // Restore favorites color if needed
            if ((toLowerANSI _itemData) in GVAR(favorites)) then {
                _panel tvSetPictureColor [[_groupIndex, _newItemIndex], FAVORITES_COLOR];
            };
            
            // Restore original tooltip (remove sort data)
            private _originalTooltip = format ["%1\n%2", _itemText, _itemData];
            _panel tvSetTooltip [[_groupIndex, _newItemIndex], _originalTooltip];
            
            // Update selected path
            if (_itemData == _selected) then {
                _selectedPath = [_groupIndex, _newItemIndex];
            };
        } forEach _itemsInGroup;
    };
};

// Restore selection
if (count _selectedPath > 0) then {
    _panel tvSetCurSel _selectedPath;
};
