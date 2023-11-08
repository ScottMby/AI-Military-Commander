[] spawn {
    // Delay until the server time has sync'd
    waitUntil {time > 1};
	[] execVM "AICommanderRunner.sqf";
}
