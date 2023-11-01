while {true} do 
{
	sleep 2; //Polling Rate for Environment Queries

	[] call SCM_fnc_GetSquadCondition;
	[] call SCM_fnc_TargetsQuery;

	SCM_fnc_getSquadCondition = {

		_unitsAlive = count units controlSquad;

		groupDamage = 0;
		groupMagazines = 0;
		squadSuppressed = false;

		{
			_unitsAlive = [_x, _unitsAlive] call SCM_fnc_checkAlive;
			groupDamage = [_x] call SCM_fnc_getDamage;
			groupMagazines = [_x] call SCM_fnc_getMagazines;
		} forEach units controlSquad;

		//Avoids divide by zero (still works despite game erroring)
		if(_unitsAlive > 0) then
		{
			groupDamage = groupDamage / _unitsAlive;
		};
		groupDamage = groupDamage * 100;

		groupMagazines = groupMagazines / _unitsAlive;

		

		//Checks the amount of squad members alive
		SCM_fnc_checkAlive = {
			params ["_x", "_unitsAlive"];
			if(!alive _x) then
			{
				_unitsAlive = _unitsAlive - 1;
			};
			_unitsAlive;
		};

		//Gets an average of the damage of the squad (NOT WORKING)
		SCM_fnc_getDamage = {
			params ["_x"];
			if(alive _x) then
			{
				unitDamage = damage _x;
				groupDamage = groupDamage + unitDamage;
			};
			groupDamage;
		};

		//Gets average of magazines left in squads inventory
		SCM_fnc_getMagazines = {
			params ["_x"];
			if(alive _x) then{
				groupMagazines = groupMagazines + count magazines _x;
			};
			groupMagazines;
		};

		//Gets if the squad is suppressed. (Not working)
		SCM_fnc_getSuppressed = {
			params["_x"];
			_x addEventHandler ["FiredNear", {
				params ["_unit", "_firer", "_distance", "_weapon", "_muzzle", "_mode", "_ammo", "_gunner"];
				squadSuppressed = true;
			}];
			squadSuppressed;
		};

		//Prints for debugging and test purposes
		systemChat format ["There are %1 soldiers left in the squad with %2 average damage. They have %3 magazines on average", _unitsAlive, groupDamage, groupMagazines];
		if(squadSuppressed) then {
			systemChat "squad suppressed";
		};
	};
	
	//Gets the enemy targets from squad leader
	SCM_fnc_TargetsQuery = {
		_allTargets = [];
			_targets = leader controlSquad targetsQuery[objNull, east, "", [], 0];
			_allTargets append _targets;
		systemChat format ["The targets are: %1", _allTargets];
	};
};