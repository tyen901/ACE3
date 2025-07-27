#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: ACE Team
 * Creates dynamic +/- buttons for container items to simulate column functionality.
 *
 * Arguments:
 * 0: Arsenal display <DISPLAY>
 * 1: Tree control <CONTROL>
 * 2: Container object <OBJECT>
 * 3: Container items array <ARRAY>
 *
 * Return Value:
 * None
 *
 * Public: No
 */

params ["_display", "_treeCtrl", "_container", "_containerItems"];

// Clean up any existing buttons
private _existingButtons = uiNamespace getVariable [QGVAR(containerButtons), []];
{
    ctrlDelete _x;
} forEach _existingButtons;

private _newButtons = [];
private _treePos = ctrlPosition _treeCtrl;
private _itemCount = _treeCtrl tvCount [];

// Create buttons for each tree item
for "_itemIndex" from 0 to (_itemCount - 1) do {
    private _item = _treeCtrl tvData [_itemIndex];
    
    // Skip empty items
    if (_item != "") then {
        // Calculate button positions (to the right of the tree item)
        private _itemHeight = (_treePos select 3) / _itemCount;
        private _yPos = (_treePos select 1) + (_itemIndex * _itemHeight) + (_itemHeight / 2) - (1.25 * GRID_H);
        private _buttonWidth = 2.5 * GRID_W;
        private _buttonHeight = 2.5 * GRID_H;
        private _buttonSpacing = 0.5 * GRID_W;
        private _totalButtonWidth = (2 * _buttonWidth) + _buttonSpacing;
        private _xPosMinus = (_treePos select 0) + (_treePos select 2) - _totalButtonWidth;
        private _xPosPlus = _xPosMinus + _buttonWidth + _buttonSpacing;
        
        // Get current item quantity
        private _currentQuantity = {_item == _x} count _containerItems;
        
        // Check if item is unique (backpacks are unique)
        private _isUnique = _item in ((uiNamespace getVariable QGVAR(configItems)) get IDX_VIRT_BACKPACK);
        
        // Create quantity label
        private _quantityLabel = _display ctrlCreate ["ctrlStatic", -1];
        private _labelWidth = 3 * GRID_W;
        private _xPosLabel = _xPosMinus - _labelWidth - (0.5 * GRID_W);
        _quantityLabel ctrlSetPosition [_xPosLabel, _yPos, _labelWidth, _buttonHeight];
        _quantityLabel ctrlSetText (if (_currentQuantity > 0) then {format ["x%1", _currentQuantity]} else {""});
        _quantityLabel ctrlSetFont "RobotoCondensedBold";
        _quantityLabel ctrlSetTextColor [1, 1, 1, 0.8];
        _quantityLabel ctrlSetBackgroundColor [0, 0, 0, 0];
        _quantityLabel ctrlCommit 0;
        _newButtons pushBack _quantityLabel;
        
        // Create minus button
        private _minusBtn = _display ctrlCreate ["ctrlButton", -1];
        _minusBtn ctrlSetPosition [_xPosMinus, _yPos, _buttonWidth, _buttonHeight];
        _minusBtn ctrlSetText "-";
        _minusBtn ctrlSetTooltip "Remove item";
        _minusBtn ctrlSetFont "RobotoCondensedBold";
        _minusBtn ctrlSetTextColor [1, 1, 1, 1];
        _minusBtn ctrlSetBackgroundColor [0.3, 0.3, 0.3, 0.8];
        _minusBtn ctrlEnable (_currentQuantity > 0);
        _minusBtn setVariable [QGVAR(itemClass), _item];
        _minusBtn setVariable [QGVAR(itemIndex), _itemIndex];
        _minusBtn setVariable [QGVAR(buttonType), "minus"];
        _minusBtn ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _item = _ctrl getVariable QGVAR(itemClass);
            private _display = ctrlParent _ctrl;
            [_display, -1] call FUNC(buttonCargo);
        }];
        _minusBtn ctrlCommit 0;
        _newButtons pushBack _minusBtn;
        
        // Create plus button
        private _plusBtn = _display ctrlCreate ["ctrlButton", -1];
        _plusBtn ctrlSetPosition [_xPosPlus, _yPos, _buttonWidth, _buttonHeight];
        _plusBtn ctrlSetText "+";
        _plusBtn ctrlSetTooltip "Add item";
        _plusBtn ctrlSetFont "RobotoCondensedBold";
        _plusBtn ctrlSetTextColor [1, 1, 1, 1];
        _plusBtn ctrlSetBackgroundColor [0.3, 0.3, 0.3, 0.8];
        _plusBtn ctrlEnable (!_isUnique && {_container canAdd _item});
        _plusBtn setVariable [QGVAR(itemClass), _item];
        _plusBtn setVariable [QGVAR(itemIndex), _itemIndex];
        _plusBtn setVariable [QGVAR(buttonType), "plus"];
        _plusBtn ctrlAddEventHandler ["ButtonClick", {
            params ["_ctrl"];
            private _item = _ctrl getVariable QGVAR(itemClass);
            private _display = ctrlParent _ctrl;
            [_display, 1] call FUNC(buttonCargo);
        }];
        _plusBtn ctrlCommit 0;
        _newButtons pushBack _plusBtn;
    };
};

// Store button references for cleanup
uiNamespace setVariable [QGVAR(containerButtons), _newButtons];
