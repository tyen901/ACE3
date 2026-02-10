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

private _fnc_pruneTree = {
    params ["_treeCtrl", "_pattern"];

    (["getSelectedLeaf", [_treeCtrl]] call FUNC(treeControlInterface)) params ["", "_selectedClass"];

    private _leafPaths = ["collectLeafPaths", [_treeCtrl, true]] call FUNC(treeControlInterface);
    for "_i" from (count _leafPaths) - 1 to 0 step -1 do {
        private _path = _leafPaths select _i;
        private _displayName = _treeCtrl tvText _path;
        private _className = _treeCtrl tvData _path;

        if ((_displayName == "") || {!(_displayName regexMatch _pattern) && {!(_className regexMatch _pattern)}}) then {
            _treeCtrl tvDelete _path;
        };
    };

    for "_groupIndex" from ((_treeCtrl tvCount []) - 1) to 0 step -1 do {
        private _groupPath = [_groupIndex];
        if ((["isGroupPath", [_treeCtrl, _groupPath]] call FUNC(treeControlInterface)) && {(_treeCtrl tvCount _groupPath) == 0}) then {
            _treeCtrl tvDelete _groupPath;
        };
    };

    if (_selectedClass != "") then {
        private _path = ["findLeafPathByData", [_treeCtrl, _selectedClass]] call FUNC(treeControlInterface);
        if (_path isNotEqualTo []) then {
            _treeCtrl tvSetCurSel _path;
        };
    };
};

if ((ctrlIDC _control) == IDC_rightSearchbar) then {
    // Right panel search bar
    // Don't refill if there is no need
    if (GVAR(lastSearchTextRight) != "" && {(_searchString find GVAR(lastSearchTextRight)) != 0}) then {
        [_display, _display displayCtrl GVAR(currentRightPanel), _animate] call FUNC(fillRightPanel);
    };

    GVAR(lastSearchTextRight) = _searchString;

    // If nothing searched, quit here
    if (_searchPattern == "") exitWith {
        forceUnicode -1;
    };

    [_display displayCtrl IDC_rightTabContent, _searchPattern] call _fnc_pruneTree;
    [_display, nil, [], configNull] call FUNC(itemInfo);
} else {
    // Left panel search bar
    // Don't refill if there is no need
    if (GVAR(lastSearchTextLeft) != "" && {(_searchString find GVAR(lastSearchTextLeft)) != 0}) then {
        [_display, _display displayCtrl GVAR(currentLeftPanel), _animate] call FUNC(fillLeftPanel);
    };

    GVAR(lastSearchTextLeft) = _searchString;

    // If nothing searched, quit here
    if (_searchPattern == "") exitWith {
        forceUnicode -1;
    };

    [_display displayCtrl IDC_leftTabContent, _searchPattern] call _fnc_pruneTree;
    [_display, nil, [], configNull] call FUNC(itemInfo);
};

// Reset unicode flag
forceUnicode -1;
