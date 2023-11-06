//Initialize any boolean variables
controlSquad setVariable ["_isSuppressed", false];

//Sets up event handlers
{
	_x addEventHandler ["Suppressed", {
				params ["_unit", "_firer", "_distance", "_weapon", "_muzzle", "_mode", "_ammo", "_gunner"];
				controlSquad setVariable ["_isSuppressed", true];
			}];
} forEach units controlSquad;

//Queries the squads condition, equipment etc...
SCM_fnc_getSquadInformation = {

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
		_groupEquipment = [];
		_unitsAlive = count units controlSquad;

		{
			_unitsAlive = [_x, _unitsAlive] call SCM_fnc_checkAlive;
			_unitsInjured = [_x] call SCM_fnc_getDamage;
			_groupMagazines = [_x] call SCM_fnc_getMagazines;
			_groupEquipment = [_x, _groupEquipment] call SCM_fnc_sqaudEquipment;
			//Divide by the amount of squad members alive
			
		} forEach units controlSquad;
		//systemChat format ["%1", _groupEquipment];

		if(_unitsAlive > 0) then
		{
			_groupMagazines = _groupMagazines / _unitsAlive;
		};

			controlSquad setVariable ["_unitsAlive", _unitsAlive];
			controlSquad setVariable ["_unitsInjured", _unitsInjured];
			controlSquad setVariable ["_groupMagazines", _groupMagazines];
			controlSquad setVariable ["_groupEquipment", _groupEquipment];
			
	};

	//Gets the enemy targets from squad leader and returns [Soldier/Vehicle, Type of Solider/Vehicle, [X pos, Y pos]]
	SCM_fnc_targetsQuery = {
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
		//systemChat format ["%1", _formattedTargets];
		_formattedTargets;
	};

	//Queries for specific classes within the squad in order to know what equipment is avaiable to them.
	SCM_fnc_sqaudEquipment = {
		params ["_x", "_unitEquipment"];
		_launcherAT = ["ACE_launch_NLAW_ready_F", "launch_RPG32_green_F", "launch_RPG32_ghex_F", "launch_RPG32_F", "launch_RPG7_F", "launch_O_Titan_short_F" , "launch_I_Titan_short_F", "launch_O_Titan_short_ghex_F", "launch_launch_B_Titan_short_F", "launch_B_Titan_short_tna_F", "launch_MRAWS_green_rail_F", "launch_MRAWS_olive_rail_F", "launch_MRAWS_sand_rail_F", "launch_MRAWS_green_F", "launch_MRAWS_olive_F", "launch_MRAWS_sand_F", "launch_O_Vorona_brown_F", "launch_O_Vorona_green_F"];
		_launcherAA = ["launch_I_Titan_F","launch_O_Titan_F", "launch_O_Titan_ghex_F", "launch_I_Titan_eaf_F", "launch_B_Titan_F", "launch_B_Titan_olive_F", "launch_B_Titan_tna_F"];
		if(secondaryWeapon _x in _launcherAT) then
		{
			_unitEquipment pushBack "AT";
		};

		if(secondaryWeapon _x in _launcherAA) then
		{
			_unitEquipment pushBack "AA";
		};

		_targetObject = _x;
		_targetClass = typeOf _targetObject;
		_targetType = _targetClass call BIS_fnc_objectType;

		_soldierType = _targetType select 1;

		if(_soldierType == "MG") then
		{
			if(count magazines _x > 0) then
			{
				_unitEquipment pushBack "MG";
			};
		};

		if(_soldierType == "MEDIC") then
		{
			_unitEquipment pushBack "MEDIC";
		};
		_unitEquipment;
	};

//Calls all queries
SCM_fnc_queryLoop = {

	[] call SCM_fnc_getSquadInformation;
	[] call SCM_fnc_targetsQuery;

	_squadSuppressed = controlSquad getVariable "_isSuppressed";
	_unitsAlive = controlSquad getVariable "_unitsAlive";
	_unitsInjured = controlSquad getVariable "_unitsInjured";
	_groupMagazines = controlSquad getVariable "_groupMagazines";

	//Prints for debugging and test purposes
		//systemChat format ["There are %1 soldiers left in the squad with %2 injured soldiers. They have %3 magazines on average", _unitsAlive, _unitsInjured, _groupMagazines];

		if(_squadSuppressed) then 
		{
			//systemChat "squad is suppressed";
			controlSquad setVariable ["_isSuppressed", false];
		};
};

//Calls query loop every two seconds
[SCM_fnc_queryLoop, 2] call CBA_fnc_addPerFrameHandler;