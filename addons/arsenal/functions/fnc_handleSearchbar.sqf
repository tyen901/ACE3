#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Alganthe, johnb43
 * Handles keyboard inputs inside the searchbars text boxes.
 *
 * Arguments:
 * 0: Arsenal display <DISPLAY>
 * 1: Searchbar control <CONTROL>
 * 2: Animate panel refresh <BOOL> (default: true)
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["_display", "_control", ["_animate", true]];

forceUnicode 0; // handle non-ANSI characters

private _searchString = ctrlText _control;
private _searchPattern = "";
if (_searchString != "") then {
    _searchPattern = _searchString call EFUNC(common,escapeRegex);
    _searchPattern = ".*?" + (_searchPattern splitString " " joinString ".*?") + ".*?/io";
};

// Right panel search bar
if ((ctrlIDC _control) == IDC_rightSearchbar) then {
    // Don't refill if there is no need
    if (GVAR(lastSearchTextRight) != "" && {(_searchString find GVAR(lastSearchTextRight)) != 0}) then {
        [_display, _display displayCtrl GVAR(currentRightPanel), _animate] call FUNC(fillRightPanel);
    };

    GVAR(lastSearchTextRight) = _searchString;

    // If nothing searched, quit here
    if (_searchPattern == "") exitWith {};

    // All right panels now use tree controls exclusively
    private _rightPanelCtrl = _display displayCtrl IDC_rightTabContent;

    // Get the currently selected item in tree panel
    private _selectedPath = tvCurSel _rightPanelCtrl;
    private _selectedItem = "";

    // If something is selected, save it
    if (count _selectedPath > 0) then {
        _selectedItem = _rightPanelCtrl tvData _selectedPath;
    };

    private _currentDisplayName = "";
    private _currentClassname = "";
    private _foundMatch = false;

    // Check if we have grouped tree (containers) or flat tree (weapons)
    private _groupCount = _rightPanelCtrl tvCount [];
    private _hasGroups = false;
    
    // Check if first level has groups (nested tree structure)
    if (_groupCount > 0) then {
        private _firstItemData = _rightPanelCtrl tvData [0];
        _hasGroups = _firstItemData in ["CONTAINER_HEADER", "CURRENT_ITEMS_GROUP", "AVAILABLE_ITEMS_GROUP"] || 
                     ((_rightPanelCtrl tvCount [0]) > 0);
    };

    if (_hasGroups) then {
        // Handle grouped tree (containers)
        for "_groupIndex" from (_groupCount - 1) to 0 step -1 do {
            private _groupHasMatches = false;
            private _itemCount = _rightPanelCtrl tvCount [_groupIndex];
            
            // Check all items in this group
            for "_itemIndex" from (_itemCount - 1) to 0 step -1 do {
                private _itemPath = [_groupIndex, _itemIndex];
                _currentDisplayName = _rightPanelCtrl tvText _itemPath;
                _currentClassname = _rightPanelCtrl tvData _itemPath;
                
                // Keep items that match search pattern
                if ((_currentDisplayName != "") && {(_currentDisplayName regexMatch _searchPattern) || {_currentClassname regexMatch _searchPattern}}) then {
                    _groupHasMatches = true;
                    
                    // Track if we found the previously selected item
                    if (_currentClassname == _selectedItem) then {
                        _foundMatch = true;
                    };
                } else {
                    // Remove items that don't match
                    _rightPanelCtrl tvDelete [_groupIndex, _itemIndex];
                };
            };
            
            // Remove empty groups or groups with no matches
            if (!_groupHasMatches) then {
                _rightPanelCtrl tvDelete [_groupIndex];
            } else {
                // Expand groups that have matches for better visibility
                _rightPanelCtrl tvExpand [_groupIndex];
            };
        };
    } else {
        // Handle flat tree (weapons/attachments)
        for "_itemIndex" from (_groupCount - 1) to 0 step -1 do {
            _currentDisplayName = _rightPanelCtrl tvText [_itemIndex];
            _currentClassname = _rightPanelCtrl tvData [_itemIndex];

            // Remove item if it doesn't match search, skip otherwise
            if ((_currentDisplayName == "") || {!(_currentDisplayName regexMatch _searchPattern) && {!(_currentClassname regexMatch _searchPattern)}}) then {
                _rightPanelCtrl tvDelete [_itemIndex];
            } else {
                // Track if we found the previously selected item
                if (_currentClassname == _selectedItem) then {
                    _foundMatch = true;
                };
            };
        };
    };

    // Restore selection if possible
    if (_foundMatch) then {
        private _newGroupCount = _rightPanelCtrl tvCount [];
        if (_hasGroups) then {
            // Search in grouped tree
            for "_groupIndex" from 0 to (_newGroupCount - 1) do {
                private _newItemCount = _rightPanelCtrl tvCount [_groupIndex];
                for "_itemIndex" from 0 to (_newItemCount - 1) do {
                    private _itemPath = [_groupIndex, _itemIndex];
                    if ((_rightPanelCtrl tvData _itemPath) == _selectedItem) exitWith {
                        _rightPanelCtrl tvSetCurSel _itemPath;
                    };
                };
            };
        } else {
            // Search in flat tree
            for "_itemIndex" from 0 to (_newGroupCount - 1) do {
                if ((_rightPanelCtrl tvData [_itemIndex]) == _selectedItem) exitWith {
                    _rightPanelCtrl tvSetCurSel [_itemIndex];
                };
            };
        };
    } else {
        _rightPanelCtrl tvSetCurSel [];
    };

    [_display, nil, nil, configNull] call FUNC(itemInfo);
} else {
    // Left panel search bar
    // Don't refill if there is no need
    if (GVAR(lastSearchTextLeft) != "" && {(_searchString find GVAR(lastSearchTextLeft)) != 0}) then {
        [_display, _display displayCtrl GVAR(currentLeftPanel), _animate] call FUNC(fillLeftPanel);
    };

    GVAR(lastSearchTextLeft) = _searchString;

    // If nothing searched, quit here
    if (_searchPattern == "") exitWith {};

    private _leftPanelCtrl = _display displayCtrl IDC_leftTabContent;

    // Get the currently selected item in tree
    private _selectedPath = tvCurSel _leftPanelCtrl;
    private _selectedItem = "";

    // If something is selected, save it
    if (count _selectedPath == 2) then {
        _selectedItem = _leftPanelCtrl tvData _selectedPath;
    };

    private _currentDisplayName = "";
    private _currentClassname = "";
    private _foundMatch = false;

    // Go through all groups and items in tree to filter by search
    private _groupCount = _leftPanelCtrl tvCount [];
    for "_groupIndex" from (_groupCount - 1) to 0 step -1 do {
        private _groupHasMatches = false;
        private _itemCount = _leftPanelCtrl tvCount [_groupIndex];
        
        // Check all items in this group
        for "_itemIndex" from (_itemCount - 1) to 0 step -1 do {
            private _itemPath = [_groupIndex, _itemIndex];
            _currentDisplayName = _leftPanelCtrl tvText _itemPath;
            _currentClassname = _leftPanelCtrl tvData _itemPath;
            
            // Keep items that match search pattern
            if ((_currentDisplayName != "") && {(_currentDisplayName regexMatch _searchPattern) || {_currentClassname regexMatch _searchPattern}}) then {
                _groupHasMatches = true;
                
                // Track if we found the previously selected item
                if (_currentClassname == _selectedItem) then {
                    _foundMatch = true;
                };
            } else {
                // Remove items that don't match
                _leftPanelCtrl tvDelete [_groupIndex, _itemIndex];
            };
        };
        
        // Remove empty groups or groups with no matches
        if (!_groupHasMatches) then {
            _leftPanelCtrl tvDelete [_groupIndex];
        } else {
            // Expand groups that have matches for better visibility
            _leftPanelCtrl tvExpand [_groupIndex];
        };
    };

    // Try to select previously selected item again
    if (_foundMatch) then {
        private _newGroupCount = _leftPanelCtrl tvCount [];
        for "_groupIndex" from 0 to (_newGroupCount - 1) do {
            private _newItemCount = _leftPanelCtrl tvCount [_groupIndex];
            for "_itemIndex" from 0 to (_newItemCount - 1) do {
                private _itemPath = [_groupIndex, _itemIndex];
                if ((_leftPanelCtrl tvData _itemPath) == _selectedItem) exitWith {
                    _leftPanelCtrl tvSetCurSel _itemPath;
                };
            };
        };
    } else {
        _leftPanelCtrl tvSetCurSel [];
    };

    [_display, nil, nil, configNull] call FUNC(itemInfo);
};

// Reset unicode flag
forceUnicode -1;
