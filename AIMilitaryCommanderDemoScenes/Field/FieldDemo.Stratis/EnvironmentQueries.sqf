//Initialize any boolean variables
controlSquad setVariable ["_isSuppressed", false];

//Sets up event handlers
{
	_x addEventHandler ["Suppressed", {
				params ["_unit", "_firer", "_distance", "_weapon", "_muzzle", "_mode", "_ammo", "_gunner"];
				controlSquad setVariable ["_isSuppressed", true];
			}];
} forEach units controlSquad;

//Queries the squads condition
SCM_fnc_getSquadCondition = {

		//Checks the amount of squad members alive
		SCM_fnc_checkAlive = {
			params ["_x", "_unitsAlive"];
			if(!alive _x) then
			{
				_unitsAlive = _unitsAlive - 1;
			};
			_unitsAlive;
		};

		//Checks the amount of injured soldiers in a squad
		SCM_fnc_getDamage = {
			params ["_x"];
			if(_x call ACE_medical_ai_fnc_isInjured) then
			{
				_unitsInjured = _unitsInjured + 1;
			};
			_unitsInjured;
		};

		//Gets average of magazines left in squads inventory
		SCM_fnc_getMagazines = {
			params ["_x"];
			if(alive _x) then{
				_groupMagazines = _groupMagazines + count magazines _x;
			};
			_groupMagazines;
		};

		_unitsInjured = 0;
		_groupMagazines = 0;
		_unitsAlive = count units controlSquad;

		{
			_unitsAlive = [_x, _unitsAlive] call SCM_fnc_checkAlive;
			_unitsInjured = [_x] call SCM_fnc_getDamage;
			_groupMagazines = [_x] call SCM_fnc_getMagazines;
			//Divide by the amount of squad members alive
			
		} forEach units controlSquad;

		if(_unitsAlive > 0) then
		{
			_groupMagazines = _groupMagazines / _unitsAlive;
		};

			controlSquad setVariable ["_unitsAlive", _unitsAlive];
			controlSquad setVariable ["_unitsInjured", _unitsInjured];
			controlSquad setVariable ["_groupMagazines", _groupMagazines];
			
	};

	//Gets the enemy targets from squad leader and returns [Soldier/Vehicle, Type of Solider/Vehicle, [X pos, Y pos]]
	SCM_fnc_TargetsQuery = {
		_allTargets = [];
		_targets = leader controlSquad targetsQuery[objNull, east, "", [], 0];
		_allTargets append _targets;
		_formattedTargets = [];
		{
			_targetObject = _x select 1;
			_targetClass = typeOf _targetObject;
			_targetType = _targetClass call BIS_fnc_objectType;
			_formattedTarget = _targetType;
			_targetPosition = _x select 4;
			_formattedTarget pushBack _targetPosition;
			_formattedTargets pushBack _formattedTarget;
		}forEach _allTargets;
		_formattedTargets;
	};

//Calls all queries
SCM_fnc_queryLoop = {

	[] call SCM_fnc_GetSquadCondition;
	[] call SCM_fnc_TargetsQuery;

	_squadSuppressed = controlSquad getVariable "_isSuppressed";
	_unitsAlive = controlSquad getVariable "_unitsAlive";
	_unitsInjured = controlSquad getVariable "_unitsInjured";
	_groupMagazines = controlSquad getVariable "_groupMagazines";

	//Prints for debugging and test purposes
		systemChat format ["There are %1 soldiers left in the squad with %2 injured soldiers. They have %3 magazines on average", _unitsAlive, _unitsInjured, _groupMagazines];

		if(_squadSuppressed) then 
		{
			systemChat "squad is suppressed";
			controlSquad setVariable ["_isSuppressed", false];
		};
};

//Calls query loop every two seconds
[SCM_fnc_queryLoop, 2] call CBA_fnc_addPerFrameHandler;