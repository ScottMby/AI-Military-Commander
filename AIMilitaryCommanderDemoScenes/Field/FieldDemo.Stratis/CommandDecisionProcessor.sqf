params["_controlSquad", "_LastState"];

aiSide = missionNamespace getVariable "_aiSide";


SCM_fnc_ProbabilitesCalculator = {
	params["_controlSquad"];

	_processedSquadMagazines = _controlSquad getVariable "_processedSquadMagazines";
	_processedUnitsAlive = _controlSquad getVariable "_processedUnitsAlive";
	_processedUnitsInjured = _controlSquad getVariable "_processedUnitsInjured";
	_processedKnownBases = _controlSquad getVariable "_processedKnownBases";
	_processedSquadSkill = _controlSquad getVariable "_processedSquadSkill";

	_enemyBases = [];
	_freindlyBases = [];
	_closestFriendlyBase = nil;
	_closestEnemyBase = nil;
	{
		if(_x select 1 == side _controlSquad) then
		{
			_freindlyBases append _x;
			if(isNil "_closestFriendlyBase") then
			{
				_closestFriendlyBase = _x;
			}
			else
			{
				_closestFriendlyBaseDistance = leader _controlSquad distance (_closestFriendlyBase select 0);
				_currentFriendlyBaseDistance = leader _controlSquad distance (_x select 0);
				if(_closestFriendlyBaseDistance > _currentFriendlyBaseDistance) then
				{
					_closestFriendlyBase = _x;
				};
			};
		}
		else
		{
			_enemyBases append _x;
			if(isNil "_closestEnemyBase") then
			{
				_closestEnemyBase = _x;
			}
			else
			{
				_closestEnemyBaseDistance = leader _controlSquad distance (_closestEnemyBase select 0);
				_currentEnemyBaseDistance = leader _controlSquad distance (_x select 0);
				if(_currentEnemyBaseDistance > _closestEnemyBaseDistance) then
				{
					_closestEnemyBase = _x;
				};
			};
		};
	} foreach _processedKnownBases;

	#define HIGH 2
	#define MID 1
	#define LOW 0

	_EnemyBaseConfidenceRateEffect = 0;
	
	if(isNil "_closestEnemyBase") then
	{
		_EnemyBaseConfidenceRateEffect = 30;
	}
	else
	{
		//systemChat format ["closestEnemyBase: %1", _closestEnemyBase];
		switch(_closestEnemyBase select 5) do
		{
		case LOW: { _EnemyBaseConfidenceRateEffect = 30 };
		case MID: { _EnemyBaseConfidenceRateEffect = 20 };
		case HIGH: { _EnemyBaseConfidenceRateEffect = 5 };
		default { _EnemyBaseConfidenceRateEffect = 20 };
		};

		//systemChat format ["EnemyBaseConfidenceRateEffect: %1", _EnemyBaseConfidenceRateEffect];
	};

	_SquadMagazineConfidenceRateEffect = 0;

	switch(_processedSquadMagazines) do
	{
		case LOW: { _SquadMagazineConfidenceRateEffect = 1 };
		case MID: { _SquadMagazineConfidenceRateEffect = 4 };
		case HIGH: { _SquadMagazineConfidenceRateEffect = 5 };
		default { _SquadMagazineConfidenceRateEffect = 4 };
	};

	//mChat format ["SquadMagazineConfidenceRateEffect: %1", _SquadMagazineConfidenceRateEffect];

	_UnitsInjuredConfidenceRateEffect = 0;

	switch(_processedUnitsInjured) do
	{
		case LOW: { _UnitsInjuredConfidenceRateEffect = 5 };
		case MID: { _UnitsInjuredConfidenceRateEffect = 2 };
		case HIGH: { _UnitsInjuredConfidenceRateEffect = 1 };
		default { _UnitsInjuredConfidenceRateEffect = 2 };
	};

	//systemChat format ["UnitsInjuredConfidenceRateEffect: %1", _UnitsInjuredConfidenceRateEffect];

	_UnitsAliveConfidenceRateEffect = 0;

	if (_processedUnitsAlive > 7) then
	{
		_UnitsAliveConfidenceRateEffect = 40;
	};
	if (_processedUnitsAlive < 7 && _processedUnitsAlive > 3) then
	{
		_UnitsAliveConfidenceRateEffect = 20;
	};
	if (_processedUnitsAlive < 3) then
	{
		_UnitsAliveConfidenceRateEffect = 5;
	};

	//systemChat format ["UnitsAliveConfidenceRateEffect: %1", _UnitsAliveConfidenceRateEffect];

	_UnitsSkillConfidenceRateEffect = 20 * _processedSquadSkill;

	if(isNil "_closestEnemyBase") then
	{
		_closestEnemyBase = "none";
	};

	if(isNil "_closestFriendlyBase") then
	{
		_closestEnemyBase = "none";
	};

	_ConfidenceRate = (_UnitsSkillConfidenceRateEffect + _UnitsAliveConfidenceRateEFfect + _UnitsInjuredConfidenceRateEffect + _SquadMagazineConfidenceRateEffect + _EnemyBaseConfidenceRateEffect) / 100;
	systemChat format ["Confidence Rate: %1", _ConfidenceRate];
	result = [_ConfidenceRate, _closestFriendlyBase, _closestEnemyBase];
	result;
};

SCM_fnc_FSM = {
	params["_ConfidenceRate", "_LastState", "_controlSquad", "_closestFreindlyBase", "_closestEnemyBase"];
	_controlSquad allowFleeing 0;
	//systemChat format ["FSM called"];
	//systemChat format ["Last State %1", _LastState];
	CurrentState = "";
	_OffensiveChance = _ConfidenceRate;
	_DefenciveChance = 1-_ConfidenceRate;
	_SurrenderChance = 1-(_ConfidenceRate/0.25);

	_actionType = "";

	_rand = random 1;
	systemChat format ["Random number: %1", _rand];
	if(_rand >= _defenciveChance) then
	{
		//Offsenive
		_actionType = "offsensive";
	};
	if(_rand < _defenciveChance) then
	{
		//Defensive
		_actionType = "defensive";
		if(_ConfidenceRate <= 0.25) then
		{
			if(_rand < _SurrenderChance) then
			{
				//Surrender
				{
					_x setCaptive true;
				}forEach units _controlSquad;
			};
		};
	};

	if(_ConfidenceRate < 0.5) then
	{
		_controlSquad setVariable ["_needReinforcement", true];
	};
	if(_LastState isEqualTo "patrol") then
	{
		if(_actionType isEqualTo "offsensive") then
		{
			_reinforcementsRequired = [_controlSquad] call SCM_fnc_CheckReinforcementRequests;
			if((_reinforcementsRequired select 0)) then
			{
				systemChat format ["%1 Current State: %2", _controlSquad, "reinforcing"];
				[_controlSquad] call SCM_fnc_DeleteAllWaypoints;
				//reinforce
				_squadToReinforce = _reinforcementsRequired select 1;
				_squadPos = position leader _squadToReinforce;
				_controlSquad addWaypoint [_squadPos, 20, 0, "regroup"];
				_waypoints = waypoints _controlSquad;
				(_waypoints select 0) setWaypointType "MOVE";
				_attackPos = waypointPosition [_squadToReinforce, 0];
				_controlSquad addWaypoint [_attackPos, 100, 1, "attack"];
				(_waypoints select 1) setWaypointType "SAD";
				CurrentState = "offensive";
			}
			else
			{
				if(_closestEnemyBase isEqualTo "none") then
				{
					//stay in state
					systemChat format ["%1 Current State: %2", _controlSquad, "patroling"];
					CurrentState = "patrol";
				}
				else
				{
					[_controlSquad] call SCM_fnc_DeleteAllWaypoints;
					//attack
					_basePos = position (_closestEnemyBase select 0);
					_controlSquad addWaypoint [_basePos, 100, 0, "attack"];
					_waypoints = waypoints _controlSquad;
					(_waypoints select 0) setWaypointType "SAD";
					CurrentState = "offensive";
				};
			};
		};
		if(_actionType isEqualTo "defensive") then
		{
			systemChat format ["%1 Current State: %2", _controlSquad, "retreat"];
			[_controlSquad] call SCM_fnc_DeleteAllWaypoints;
			//Retreat
			_basePos = position (_closestFreindlyBase select 0);
			_controlSquad addWaypoint [_basePos, 20, 0, "regroup"];
			_waypoints = waypoints _controlSquad;
			(_waypoints select 0) setWaypointType "MOVE";
			(_waypoints select 0) setWaypointSpeed "FUll";
			{
				_x disableAI "AUTOTARGET";
				_x disableAI "AUTOCOMBAT";
				_x disableAI "TARGET";
				_x doWatch objNull;
			} forEach units _controlSquad;
			CurrentState = "retreat";
		};
	};

	if(_LastState isEqualTo "offensive") then
	{
		if(_actionType isEqualTo "offsensive") then
		{
			if(_closestEnemyBase isEqualTo "none") then
			{
				systemChat format ["%1 Current State: %2", _controlSquad, "defending"];
				[_controlSquad] call SCM_fnc_DeleteAllWaypoints;
				//Base Captured
				_basePos = position (_closestFreindlyBase select 0);
				_controlSquad addWaypoint [_basePos, 100, 0, "defend"];
				_waypoints = waypoints _controlSquad;
				(_waypoints select 0) setWaypointType "HOLD";
				CurrentState = "defensive";
			}
			else
			{
				//stay in state
				systemChat format ["%1 Current State: %2", _controlSquad, "attacking"];
				CurrentState = "offensive";
			};
		};
		if( _actionType isEqualTo "defensive") then
		{
			systemChat format ["%1 Current State: %2", _controlSquad, "retreat"];
			[_controlSquad] call SCM_fnc_DeleteAllWaypoints;
			//Retreat
			_basePos = position (_closestFreindlyBase select 0);
			_controlSquad addWaypoint [_basePos, 20, 0, "regroup"];
			_waypoints = waypoints _controlSquad;
			(_waypoints select 0) setWaypointType "MOVE";
			(_waypoints select 0) setWaypointSpeed "FUll";
			{
				_x disableAI "AUTOTARGET";
				_x disableAI "AUTOCOMBAT";
				_x disableAI "TARGET";
				_x doWatch objNull;
			} forEach units _controlSquad;
			CurrentState = "retreat";
		};
	};

	if(_LastState isEqualTo "defensive") then
	{
		if(_actionType isEqualTo "offsensive") then
		{
			_reinforcementsRequired = [_controlSquad] call SCM_fnc_CheckReinforcementRequests;
			if((_reinforcementsRequired select 0)) then
			{
				systemChat format ["%1 Current State: %2", _controlSquad, "reinforcing"];
				[_controlSquad] call SCM_fnc_DeleteAllWaypoints;
				//reinforce
				_squadToReinforce = _reinforcementsRequired select 1;
				_squadPos = position leader _squadToReinforce;
				_controlSquad addWaypoint [_squadPos, 20, 0, "regroup"];
				_waypoints = waypoints _controlSquad;
				(_waypoints select 0) setWaypointType "MOVE";
				_attackPos = waypointPosition [_squadToReinforce, 0];
				_controlSquad addWaypoint [_attackPos, 100, 1, "attack"];
				(_waypoints select 1) setWaypointType "SAD";
				CurrentState = "offensive";
			}
			else
			{
				systemChat format ["%1 Current State: %2", _controlSquad, "patroling"];
				[_controlSquad] call SCM_fnc_DeleteAllWaypoints;
				//Patrol
				_patrolPos = getPos leader _controlSquad;
				[_controlSquad, _patrolPos, 1000]call BIS_fnc_taskPatrol;
				CurrentState = "patrol";				
			};
		};
		if( _actionType isEqualTo "defensive") then
		{
			//Remain in state
			systemChat format ["%1 Current State: %2", _controlSquad, "defending"];
			CurrentState = "defensive";
		};
	};

	if(_LastState isEqualTo "reinforce") then
	{
		if(_actionType isEqualTo "offsensive") then
		{
			//Remain in state
			systemChat format ["%1 Current State: %2", _controlSquad, "reinforcing"];
			CurrentState = "reinforce";

		};
		if(_actionType isEqualTo "defensive") then
		{
			systemChat format ["%1 Current State: %2", _controlSquad, "retreat"];
			[_controlSquad] call SCM_fnc_DeleteAllWaypoints;
			//Retreat
			_basePos = position (_closestFreindlyBase select 0);
			_controlSquad addWaypoint [_basePos, 20, 0, "regroup"];
			_waypoints = waypoints _controlSquad;
			(_waypoints select 0) setWaypointType "HOLD";
			(_waypoints select 0) setWaypointSpeed "FUll";
			{
				_x disableAI "AUTOTARGET";
				_x disableAI "AUTOCOMBAT";
				_x disableAI "TARGET";
				_x doWatch objNull;
			} forEach units _controlSquad;
			CurrentState = "retreat";
		};
	};

	if(_LastState isEqualTo "retreat") then
	{
		{
			_x enableAI "AUTOTARGET";
			_x enableAI "AUTOCOMBAT";
			_x enableAI "TARGET";
		} forEach units _controlSquad;
		systemChat format ["%1 Current State: %2", _controlSquad, "defending"];
		[_controlSquad] call SCM_fnc_DeleteAllWaypoints;
		//defend
		_basePos = position (_closestFreindlyBase select 0);
		_controlSquad addWaypoint [_basePos, 100, 0, "defend"];
		_waypoints = waypoints _controlSquad;
		(_waypoints select 0) setWaypointType "MOVE";
		CurrentState = "defensive";
	}; 
	//systemChat format ["Current State: %1", CurrentState];
	CurrentState;
};

SCM_fnc_CheckReinforcementRequests = {
	params["_controlSquad"];

	_squad = "none";
	_reinforcing = false;

	{
		if(_x isEqualTo _controlSquad) then
		{
			continue;
		}
		else
		{
			_status = _x getVariable "_needReinforcement";
			if(_status isEqualTo true) then
			{
				_squad = _x;
				_reinforcing = true;
			};
		};
	}forEach groups aiSide;
	_result = [_reinforcing, _squad];
	_result;
};

SCM_fnc_CheckBaseIsDefended = {
	params["_controlSquad", "_closestFriendlyBase"];
	_defended = false;
	_squadSize = count (units _controlSquad);
	_unitsInArea = count (_closestFriendlyBase select 2);
	if((_squadSize - _unitsInArea) > 0) then
	{
	_defended = true;	
	};
	_defended;
};

SCM_fnc_DeleteAllWaypoints = {
	params["_controlSquad"];
	while {(count (waypoints _controlSquad)) > 0} do
	{
		deleteWaypoint ((waypoints _controlSquad) select 0);
	};	
};

result = [_controlSquad] call SCM_fnc_ProbabilitesCalculator;

CurrentState = [result select 0, _LastState, _controlSquad, result select 1, result select 2] call SCM_fnc_FSM;
//systemChat format ["Current State: %1", CurrentState];
_controlSquad setVariable["_LastState", CurrentState];