#include "..\script_component.hpp"
#include "..\defines.hpp"
#include "\a3\ui_f\hpp\defineDIKCodes.inc"
/*
 * Author: Alganthe, johnb43
 * Handles keyboard inputs in arsenal.
 *
 * Arguments:
 * 0: Arsenal display <DISPLAY>
 * 1: Key being pressed <NUMBER>
 * 2: Shift state <BOOL>
 * 3: Ctrl state <BOOL>
 * 4: Alt state <BOOL>
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["", "_args"];
_args params ["_display", "_keyPressed", "_shiftState", "_ctrlState", "_altState"];

GVAR(shiftState) = _shiftState;
private _return = true;
private _loadoutsDisplay = findDisplay IDD_loadouts_display;

private _fnc_getFocusedClassName = {
    params ["_display"];

    private _className = "";

    switch (true) do {
        case (GVAR(leftTabFocus)): {
            private _control = _display displayCtrl IDC_leftTabContent;
            (["getSelectedLeaf", [_control]] call FUNC(treeControlInterface)) params ["", "_className"];
        };
        case (GVAR(rightTabFocus)): {
            private _control = _display displayCtrl IDC_rightTabContent;
            (["getSelectedLeaf", [_control]] call FUNC(treeControlInterface)) params ["", "_className"];
        };
    };

    _className
};

private _treeCollapsedRoots = uiNamespace getVariable [QGVAR(treeCollapsedRoots), createHashMap];
uiNamespace setVariable [QGVAR(treeCollapsedRoots), _treeCollapsedRoots];

private _fnc_focusTreeControl = {
    params ["_display"];

    if (GVAR(leftTabFocus) || {GVAR(rightTabFocus)}) exitWith {};

    ctrlSetFocus (_display displayCtrl IDC_leftTabContent);
};

private _fnc_getPreferredTreeControl = {
    params ["_display"];

    private _leftTree = _display displayCtrl IDC_leftTabContent;
    private _rightTree = _display displayCtrl IDC_rightTabContent;

    if (GVAR(rightTabFocus)) exitWith {_rightTree};
    if (GVAR(leftTabFocus)) exitWith {_leftTree};

    _leftTree
};

private _fnc_treeCollectVisiblePaths = {
    params ["_tree"];

    private _paths = [];

    for "_rootIndex" from 0 to ((_tree tvCount []) - 1) do {
        private _rootPath = [_rootIndex];
        private _rootKey = format ["%1|%2", ctrlIDC _tree, _rootIndex];
        _paths pushBack _rootPath;

        if (
            (["isGroupPath", [_tree, _rootPath]] call FUNC(treeControlInterface)) &&
            {!(_treeCollapsedRoots getOrDefault [_rootKey, false])}
        ) then {
            for "_leafIndex" from 0 to ((_tree tvCount _rootPath) - 1) do {
                _paths pushBack (_rootPath + [_leafIndex]);
            };
        };
    };

    _paths
};

private _fnc_treeMoveSelection = {
    params ["_tree", "_step"];

    private _visiblePaths = [_tree] call _fnc_treeCollectVisiblePaths;
    if (_visiblePaths isEqualTo []) exitWith {};

    private _currentPath = tvCurSel _tree;
    private _currentIndex = _visiblePaths find _currentPath;
    if (_currentIndex == -1) then {
        _currentIndex = 0;
    };

    private _targetIndex = (_currentIndex + _step) max 0 min ((count _visiblePaths) - 1);
    _tree tvSetCurSel (_visiblePaths select _targetIndex);
};

private _fnc_handleTreeArrowNavigation = {
    params ["_display", "_keyPressed", "_shiftState"];

    [_display] call _fnc_focusTreeControl;
    private _tree = [_display] call _fnc_getPreferredTreeControl;
    if (isNull _tree) exitWith {false};

    private _path = tvCurSel _tree;
    if (_path isEqualTo []) then {
        private _visiblePaths = [_tree] call _fnc_treeCollectVisiblePaths;
        if (_visiblePaths isEqualTo []) exitWith {false};
        _tree tvSetCurSel (_visiblePaths select 0);
        _path = tvCurSel _tree;
    };

    // Shift+Left/Right adjusts container quantity for right tree leaf selections.
    if (
        (_keyPressed in [DIK_LEFT, DIK_RIGHT]) &&
        {_shiftState} &&
        {_tree isEqualTo (_display displayCtrl IDC_rightTabContent)} &&
        {GVAR(currentLeftPanel) in [IDC_buttonUniform, IDC_buttonVest, IDC_buttonBackpack]}
    ) exitWith {
        (["getSelectedLeaf", [_tree]] call FUNC(treeControlInterface)) params ["", "_className"];
        if (_className != "") then {
            [_display, parseNumber (_keyPressed != DIK_LEFT)] call FUNC(buttonCargo);
        };

        // Consume Shift+Left/Right in container mode so group rows don't collapse/expand.
        true
    };

    switch (_keyPressed) do {
        case DIK_UP: {
            [_tree, -1] call _fnc_treeMoveSelection;
            true
        };
        case DIK_DOWN: {
            [_tree, 1] call _fnc_treeMoveSelection;
            true
        };
        case DIK_LEFT: {
            if (["isGroupPath", [_tree, _path]] call FUNC(treeControlInterface)) then {
                _treeCollapsedRoots set [format ["%1|%2", ctrlIDC _tree, _path select 0], true];
                _tree tvCollapse _path;
            } else {
                private _parentPath = _path select [0, (count _path) - 1];
                if (_parentPath isNotEqualTo []) then {
                    _tree tvSetCurSel _parentPath;
                };
            };
            true
        };
        case DIK_RIGHT: {
            if (["isGroupPath", [_tree, _path]] call FUNC(treeControlInterface)) then {
                if ((_tree tvCount _path) > 0) then {
                    _treeCollapsedRoots set [format ["%1|%2", ctrlIDC _tree, _path select 0], false];
                    _tree tvExpand _path;
                    _tree tvSetCurSel (_path + [0]);
                };
            };
            true
        };
        default {false};
    };
};

// If in loadout screen
if (!isNull _loadoutsDisplay) then {
    // If loadout search bar isn't focussed
    if (!GVAR(loadoutsSearchbarFocus)) then {
        switch (true) do {
            // Close button
            case (_keyPressed == DIK_ESCAPE): {
                _display closeDisplay IDC_CANCEL;
            };
            // Search field
            case (_keyPressed == DIK_F && {_ctrlState}): {
                ctrlSetFocus (_loadoutsDisplay displayCtrl IDC_loadoutsSearchbar);
            };
        };
    } else {
        // If loadout search bar is focussed
        switch (true) do {
            // Close button
            case (_keyPressed == DIK_ESCAPE): {
                _display closeDisplay IDC_CANCEL;
            };
            // Search
            case (_keyPressed == DIK_NUMPADENTER);
            case (_keyPressed == DIK_RETURN): {
                [_loadoutsDisplay, _loadoutsDisplay displayCtrl IDC_loadoutsSearchbar] call FUNC(handleLoadoutsSearchBar);
            };
            case (_keyPressed == DIK_BACKSPACE);
            case (_keyPressed in [DIK_LEFT, DIK_RIGHT]): {
                _return = false;
            };
        };
    };

    switch (true) do {
        case (_keyPressed in [DIK_C, DIK_V, DIK_A, DIK_X] && {_ctrlState});
        case (GVAR(loadoutsPanelFocus) && {_keyPressed in [DIK_UP, DIK_DOWN]}): {
            _return = false;
        };
    };
} else {
    // If in arsenal and no search bar is selected
    if (!GVAR(leftSearchbarFocus) && {!GVAR(rightSearchbarFocus)}) then {
        switch (true) do {
            // Close button
            case (_keyPressed == DIK_ESCAPE): {
                _display closeDisplay IDC_CANCEL;
            };
            // Hide button
            case (_keyPressed == DIK_BACKSPACE): {
                [_display] call FUNC(buttonHide);
            };
            // Export button / export classname
            case (_keyPressed == DIK_C && {_ctrlState}): {
                if (GVAR(leftTabFocus) || {GVAR(rightTabFocus)}) then {
                    private _className = [_display] call _fnc_getFocusedClassName;

                    "ace" callExtension ["clipboard:append", [_className]];
                    "ace" callExtension ["clipboard:complete", []];

                    [_display, format ["%1 - %2", LLSTRING(exportedClassnameText), _className]] call FUNC(message);
                } else {
                    [_display] call FUNC(buttonExport);
                };
            };
            // Export Parent
            case (_keyPressed == DIK_P && {_ctrlState}): {
                if !(GVAR(leftTabFocus) || {GVAR(rightTabFocus)}) exitWith {};
                private _className = [_display] call _fnc_getFocusedClassName;

                private _cfgConfig = if (GVAR(leftTabFocus)) then {
                    switch (GVAR(currentLeftPanel)) do {
                        case IDC_buttonBackpack: {configFile >> "CfgVehicles"};
                        case IDC_buttonGoggles: {configFile >> "CfgGlasses"};
                        case IDC_buttonFace: {configFile >> "CfgFaces"};
                        case IDC_buttonVoice: {configFile >> "CfgVoice"};
                        case IDC_buttonInsignia: {configFile >> "CfgUnitInsignia"};
                        default {configFile >> "CfgWeapons"};
                    }
                } else {
                    switch (GVAR(currentRightPanel)) do {
                        case IDC_buttonCurrentMag;
                        case IDC_buttonCurrentMag2;
                        case IDC_buttonThrow;
                        case IDC_buttonPut;
                        case IDC_buttonMag;
                        case IDC_buttonMagALL: {configFile >> "CfgMagazines"};
                        default {configFile >> "CfgWeapons"};
                    }
                };

                private _parent = configName inheritsFrom (_cfgConfig >> _className);
                "ace" callExtension ["clipboard:append", [_parent]];
                "ace" callExtension ["clipboard:complete", []];

                [_display, format ["%1 - %2", LLSTRING(exportedClassnameText), _parent]] call FUNC(message);
            };
            // Import button
            case (_keyPressed == DIK_V && {_ctrlState}): {
                [_display] call FUNC(buttonImport);
            };
            // Focus search
            case (_keyPressed == DIK_F && {_ctrlState}): {
                ctrlSetFocus (_display displayCtrl IDC_leftSearchbar);
            };
            // Switch vision mode
            case (_keyPressed in (actionKeys "nightvision")): {
                if (isNil QGVAR(visionMode)) then {
                    GVAR(visionMode) = 0;
                };

                GVAR(visionMode) = (GVAR(visionMode) + 1) % 3;

                switch (GVAR(visionMode)) do {
                    // Normal
                    case 0: {
                        camUseNVG false;
                        false setCamUseTI 0;
                    };
                    // NVG
                    case 1: {
                        camUseNVG true;
                        false setCamUseTI 0;
                    };
                    // TI
                    default {
                        camUseNVG false;
                        true setCamUseTI 0;
                    };
                };

                playSound ["RscDisplayCurator_visionMode", true];
            };
            // Panel up down
            case (_keyPressed in [DIK_UP, DIK_DOWN]): {
                _return = [_display, _keyPressed, _shiftState] call _fnc_handleTreeArrowNavigation;
            };
            // Tree left/right navigation, with Shift+Left/Right quantity adjust on right container leaves.
            case (_keyPressed in [DIK_LEFT, DIK_RIGHT]): {
                _return = [_display, _keyPressed, _shiftState] call _fnc_handleTreeArrowNavigation;
            };
        };
    } else {
        // If in arsenal and a search bar is selected
        switch (true) do {
            // Close button
            case (_keyPressed == DIK_ESCAPE): {
                _display closeDisplay IDC_CANCEL;
            };
            // Search
            case (_keyPressed == DIK_NUMPADENTER);
            case (_keyPressed == DIK_RETURN): {
                if (GVAR(leftSearchbarFocus)) then {
                    [_display, _display displayCtrl IDC_leftSearchbar] call FUNC(handleSearchBar);
                };

                if (GVAR(rightSearchbarFocus)) then {
                    [_display, _display displayCtrl IDC_rightSearchbar] call FUNC(handleSearchBar);
                };
            };
            case (_keyPressed in [DIK_LEFT, DIK_RIGHT]);
            case (_keyPressed == DIK_BACKSPACE);
            case (_keyPressed in [DIK_C, DIK_V, DIK_A, DIK_X] && {_ctrlState}): {
                _return = false;
            };
            // Focus search fields
            case (_keyPressed == DIK_F && {_ctrlState}): {
                if (GVAR(rightSearchbarFocus)) then {
                    ctrlSetFocus (_display displayCtrl IDC_leftSearchbar);
                } else {
                    ctrlSetFocus (_display displayCtrl IDC_rightSearchbar);
                };
            };
        };
    };
};

_return
