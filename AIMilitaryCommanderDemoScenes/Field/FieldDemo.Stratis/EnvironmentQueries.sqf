_aiSide = missionNamespace getVariable "_aiSide";

//Run for every squad on the AI's Side
{
	_pollingRate = missionNamespace getVariable "_pollingRate";
	_baseTriggers = missionNamespace getVariable "_baseTriggers";
	_responseTime = missionNamespace getVariable "_responseTime";

	_controlSquad = _x;

	//Returns trigger of a base along with its side.
	SCM_fnc_getBases = {
		params["_baseTriggers"];
		_bases = [];
		{
			_triggerActivation = triggerActivation _x;
			if (_triggerActivation select 0 == "WEST") then
			{
				_bases pushBack [_x, west, [], false];
			};
			if (_triggerActivation select 0 == "EAST") then
			{
				_bases pushBack [_x, east, [], false];
			};
		} forEach _baseTriggers;
		_bases;
	};

	//Sets up event handlers
	{
		_x addEventHandler ["FiredNear", {
					params ["_unit", "_firer", "_distance", "_weapon", "_muzzle", "_mode", "_ammo", "_gunner"];
					group _x setVariable ["_isEngaged", true];
				}];
	} forEach units _controlSquad;

	//Queries the squads condition, equipment etc...
	SCM_fnc_getSquadInformation = {
		params["_controlSquad"];

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
				_squadMagazines = _squadMagazines + count magazines _x;
			};
			_squadMagazines;
		};

		_unitsInjured = 0;
		_squadMagazines = 0;
		_squadEquipment = [];
		_unitsAlive = count units _controlSquad;

		{
			_unitsAlive = [_x, _unitsAlive] call SCM_fnc_checkAlive;
			_unitsInjured = [_x] call SCM_fnc_getDamage;
			_squadMagazines = [_x] call SCM_fnc_getMagazines;
			_squadEquipment = [_x, _squadEquipment] call SCM_fnc_squadEquipment;
			//Divide by the amount of squad members alive
			
		} forEach units _controlSquad;
		//systemChat format ["%1", _squadEquipment];

		if(_unitsAlive > 0) then
		{
			_squadMagazines = _squadMagazines / _unitsAlive;
		};

		_controlSquad setVariable ["_unitsAlive", _unitsAlive];
		_controlSquad setVariable ["_unitsInjured", _unitsInjured];
		_controlSquad setVariable ["_squadMagazines", _squadMagazines];
		_controlSquad setVariable ["_squadEquipment", _squadEquipment];
	};

	//Gets the enemy targets from squad leader and returns [Soldier/Vehicle, Type of Solider/Vehicle, [X pos, Y pos]]
	SCM_fnc_targetsQuery = {
		params["_controlSquad"];
		_allTargets = [];
		_targets = leader _controlSquad targetsQuery[objNull, east, "", [], 0];
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
		_controlSquad setVariable ["_squadTargets", _formattedTargets];
		_targets;
	};

	//Queries for specific classes within the squad in order to know what equipment is avaiable to them.
	SCM_fnc_squadEquipment = {
		params ["_x", "_unitEquipment"];
		_launcherAT = ["ACE_launch_NLAW_ready_F", "launch_RPG32_green_F", "launch_RPG32_ghex_F", "launch_RPG32_F", "launch_RPG7_F", "launch_O_Titan_short_F" , "launch_I_Titan_short_F", "launch_O_Titan_short_ghex_F", "launch_launch_B_Titan_short_F", "launch_B_Titan_short_tna_F", "launch_MRAWS_green_rail_F", "launch_MRAWS_olive_rail_F", "launch_MRAWS_sand_rail_F", "launch_MRAWS_green_F", "launch_MRAWS_olive_F", "launch_MRAWS_sand_F", "launch_O_Vorona_brown_F", "launch_O_Vorona_green_F"];
		_launcherAA = ["launch_I_Titan_F","launch_O_Titan_F", "launch_O_Titan_ghex_F", "launch_I_Titan_eaf_F", "launch_B_Titan_F", "launch_B_Titan_olive_F", "launch_B_Titan_tna_F"];
		_sniper = "srifle";
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

		if(_sniper in primaryWeapon _x) then
		{
			_unitEquipment pushBack "SNIPER";
		};
		//systemChat format ["%1", _unitEquipment];
		_unitEquipment;
	};

	//Returns the list of bases that a squad knows about. Format is [base name, side, targets array, knows about].
	SCM_squadBaseKnowledge = {
		params["_bases", "_knownBases", "_controlSquad", "_targetObjects"];
		_knownBases = [];
		index = 0;
		{
			if(_x select 1 == side _controlSquad) then 
			{
				_baseTargets = []; //targets within base
				{
					_trigger = _y;
					_target = _x;
					if(_target inArea _trigger) then {
						_baseTargets pushBack _x;
					};
				} forEach units side _controlSquad;
				_knownBases pushBack [_x select 0, west, _baseTargets, true];
			}
			else
			{
				_y = _x select 0; //So we can access both itterated elements.

				//We have several approches here to check whether any of our units have seen an enemy base. 
				//This implementation checks if the squad see any targets in base areas.
				//If the targets are in the base areas, we will assunme that the squad also saw the base.

				_baseTargets = []; //targets within base
				{
					_trigger = _y;
					_target = _x select 1;
					if(_target inArea _trigger) then {
						_baseTargets pushBack _x;
					};
				} forEach _targetObjects;

				if(count _baseTargets > 0) then
				{
					_knownBases pushBack [_y, east, _baseTargets, true];
				}
				else{
					_currentBase = _bases select index;
					_knownBases pushBack [_y, east, [], _currentBase select 3];
				};
			};
			index = index + 1;
		} forEach _bases;
		_controlSquad setVariable ["_bases", _knownBases];
		//systemChat format ["%1", _knownBases];
		_knownBases;
	};

	//Returns average of squad skill from range of 0 to 1
	SCM_fnc_getSquadSkill = {
		params["_controlSquad"];	
		_squadSkillAvg = 0;	
		{
			_squadSkillAvg = _squadSkillAvg + skill _x;
		} forEach units _controlSquad;
		_squadSkillAvg = _squadSkillAvg / count units _controlSquad;
		//systemChat format ["squad skill is %1", _squadSkillAvg];
		_squadSkillAvg;
	};

	//Returns whether the sun or moon is out from a range of 0 the moon is out and 1 the sun is out.
	SCM_fnc_getDayOrNight = {
		_dayOrNight = sunOrMoon;
		//systemChat format ["the dayNight cycle is at %1", _dayOrNight];
		_dayOrNight;
	};

	//Takes in input value and makes them inaccurate to simulate inacurracy within information exchanged from a squad to the commander.
	SCM_fnc_squadInaccuracies = {
		params["_controlSquad", "_squadMagazines", "_unitsAlive", "_unitsInjured", "_knownBases", "_squadSkill", "_dayOrNight", "_squadEngaged", "_responseTime"];

		_squadLeaderDown = !alive leader _controlSquad;
		_reactionTimeMultiplier = random _responseTime;

		//Uses a number of factors to calculate a misinformation multiplier that is applied to a weighted rng to calculate the chance of the squad delievering misinformation to the commander.
		_misinformationMultiplier = (1 - _squadSkill) * 10;
		_misinformationMultiplier = _misinformationMultiplier + (_dayOrNight * 5);
		if(_squadLeaderDown) then
		{
			_misinformationMultiplier = _misinformationMultiplier + 5;
		};
		if(_squadEngaged) then
		{
			_misinformationMultiplier = _misinformationMultiplier + 5;
		};

		_misinformationMultiplier = _misinformationMultiplier / 100;

		{

			//Randomise whether the multiplier has a positive or negative effect.
			_misinformationMultiplier = selectRandom [-_misinformationMultiplier, _misinformationMultiplier];

			//Use a weighted RNG to randomise the chance of misinfomation while being effected by the previous factors.
			_misinformationMultiplier = random [0.75, 1 + _misinformationMultiplier, 1.25];

			_x = _x * _misinformationMultiplier;

		} foreach [_squadMagazines, _unitsInjured, _unitsAlive, _reactionTimeMultiplier];

		{

			//Randomise whether the multiplier has a positive or negative effect.
			_misinformationMultiplier = selectRandom [-_misinformationMultiplier, _misinformationMultiplier];

			//Use a weighted RNG to randomise the chance of misinfomation while being effected by the previous factors.
			_misinformationMultiplier = random [0.75, 1 + _misinformationMultiplier, 1.25];

			_x select 4 = (_x select 4) * _misinformationMultiplier;

		} foreach [_knownBases];

		//fuzzification
		_squadMagazinesApprox = [_squadMagazines, [0,2,7,10,12]] call SCM_fnc_fuzzifier;
		_unitsInjuredApprox = [_unitsInjured, [0,1,3,4,6]] call SCM_fnc_fuzzifier;
		{
			targetsAtBase = _x select 2;
			_knownBasesUnitsApprox = [(count targetsAtBase), [0,5,10,15,20]] call SCM_fnc_fuzzifier;
			_x pushBack _knownBasesUnitsApprox;
		} forEach _knownBases;

		finalValues = [_knownBases, _unitsAlive, _unitsInjuredApprox, _squadMagazinesApprox, _squadEngaged];
	};

	SCM_fnc_fuzzifier = {
		params["_fuzzyInput", "_ranges"];

		#define HIGH 2
		#define MID 1
		#define LOW 0

		_fuzzyInputApprox = "null";

		if(_fuzzyInput <= _ranges select 1) then
		{
			_fuzzyInputApprox = LOW;
		};
		if(_fuzzyInput > _ranges select 1 && _fuzzyInput <= _ranges select 2) then
		{
			difference = (_ranges select 2) - (_ranges select 1);
			temp = _fuzzyInput - (_ranges select 1);
			low = -1/difference * temp + 1;
			high = 1/difference * temp;
			rndm = random 100;
			if(rndm <= (low * 100)) then
			{
				_fuzzyInputApprox = LOW;
			}
			else{
				_fuzzyInputApprox = MID;
			}
		};
		if(_fuzzyInput > _ranges select 2 && _fuzzyInput <= _ranges select 3) then
		{
			_fuzzyInputApprox = MID;
		};
		if(_fuzzyInput > _ranges select 3 && _fuzzyInput <= _ranges select 4) then
		{
			difference = (_ranges select 4) - (_ranges select 3);
			temp = _fuzzyInput - (_ranges select 3);
			low = -1/difference * temp + 1;
			high = 1/difference * temp;
			rndm = random 100;
			if(rndm <= (low * 100)) then
			{
				_fuzzyInputApprox = MID;
			}
			else{
				_fuzzyInputApprox = HIGH;
			}
		};
		if(_fuzzyInput > _ranges select 4) then
		{
				_fuzzyInputApprox = HIGH;
		};
		_fuzzyInputApprox;
	};

	//Calls all queries
	SCM_fnc_queryLoop = {
		params["_args"];

		_controlSquad = _args select 0;
		_baseTriggers = _args select 1;
		_knownBases = _args select 2;
		_bases = _controlSquad getVariable "_bases";

		[_controlSquad] call SCM_fnc_getSquadInformation;
		_targetObjects = [_controlSquad] call SCM_fnc_targetsQuery;

		_knownBases = [_bases, _knownBases, _controlSquad, _targetObjects] call SCM_squadBaseKnowledge;

		_squadEngaged = _controlSquad getVariable "_isEngaged";
		_unitsAlive = _controlSquad getVariable "_unitsAlive";
		_unitsInjured = _controlSquad getVariable "_unitsInjured";
		_squadMagazines = _controlSquad getVariable "_squadMagazines";

		_squadSkill = [] call SCM_fnc_getSquadSkill;
		_dayOrNight = [] call SCM_fnc_getDayOrNight;

		_inaccurateValues = [_controlSquad, _squadMagazines, _unitsInjured, _knownBases, _squadSkill, _dayOrNight, _squadEngaged, _args select 3] call SCM_fnc_squadInaccuracies;

		_controlSquad setVariable ["_processedSquadMagazines", _inaccurateValues select 1];
		_controlSquad setVariable ["_processedUnitsInjured", _inaccurateValues select 2];
		_controlSquad setVariable ["_processedKnownBases", _inaccurateValues select 3];
		_controlSquad setVariable ["_processedSquadSkill", _inaccurateValues select 4];

	};

	//Set squad variables
	_controlSquad setVariable ["_bases", [_baseTriggers] call SCM_fnc_getBases]; //Add bases that have been configured
	_controlSquad setVariable ["_priority", "MEDIUM"]; //Sets default sqaud priority
	_controlSquad setVariable ["_currentState", "START"]; //Sets default squad state
	_controlSquad setVariable ["_squadSkill",[_controlSquad] call SCM_fnc_getSquadSkill];
	_controlSquad setVariable ["_isEngaged", false];

	_knownBases = [];

	//Calls query loop every two seconds
	[SCM_fnc_queryLoop, _pollingRate, [_controlSquad, _baseTriggers, _knownBases, _responseTime]] call CBA_fnc_addPerFrameHandler;

} forEach groups _aiSide;