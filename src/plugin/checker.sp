#include <sdktools>
#include <sourcemod>

// MySQL
Database gB_DBSQL = null;

// Player Stats
int gB_PKills[MAXPLAYERS + 1] = 0;
int gB_PDeaths[MAXPLAYERS + 1] = 0;
int gB_PShots[MAXPLAYERS + 1] = 0;
int gB_PHits[MAXPLAYERS + 1] = 0;
int gB_PHS[MAXPLAYERS + 1] = 0;
int gB_PlayTime[MAXPLAYERS + 1] = 0;
char gB_PSteamID64[32];
char gB_ESteamID64[32];
char gB_Map[64];
int gB_MatchKey = 0;
bool gB_activeMatch = false;

public Plugin myinfo = {
  name = "CS:GO EndGameCheck",
  author = "BenediktBertsch",
  description = "Checks if the match is over and stops the server.",
  version = "0.1"};

public void OnPluginStart()
{
    SQL_StartConnection();
    if(gB_DBSQL != null)
    {
        HookEvent("round_end", Event_RoundEnd);
        HookEvent("player_death", Event_PlayerDeath);
        HookEvent("weapon_fire", Event_WeaponFire);
        HookEvent("player_hurt", Event_PlayerHurt);
        HookEvent("client_disconnect", Event_PlayerDisconnect);
        HookEvent("cs_win_panel_match", Event_End); // End of match -> shutdown

        for(int i = 0; i <= MaxClients; i++)
        {
            if(IsValidClient(i))
            {
                GetCurrentMap(gB_Map, 64);
                OnClientPutInServer(i);
            }
        }

        CreateTimer(5.0, CheckPlayerCount, _, TIMER_REPEAT)
    }
    else
    {
        SetFailState("[Checker] Error on start. Deactivate Plugin no DB Connection!");
    }
}

public Action Event_PlayerDisconnect(Handle event, const char[] name, bool dontBroadcast)
{
    // TODO
} 

public Action CheckPlayerCount(Handle timer)
{
    if(GetPlayersCount() == 2 && gB_activeMatch == false)
    {
        CreateTimer(5.0, LoadExec);
        gB_activeMatch = true;
    }
    else if(!gB_activeMatch)
    {
        PrintToChatAll("Waiting for players...")
    }
}

public Action LoadExec(Handle timer)
{
    ServerCommand("exec autoexec.cfg");
}

public Action Event_End(Event event, const char[] name, bool dontBroadcast)
{
    PrintToChatAll("Server shutting down in 10 seconds...");
    CreateTimer(10.0, Shutdown);
}

public Action Shutdown(Handle timer)
{
    ServerCommand("quit");
}

public void Event_WeaponFire(Event e, const char[] name, bool dontBroadcast)
{
    char FiredWeapon[32];
    GetEventString(e, "weapon", FiredWeapon, sizeof(FiredWeapon));

    if(StrEqual(FiredWeapon, "hegrenade") || StrEqual(FiredWeapon, "flashbang") || StrEqual(FiredWeapon, "smokegrenade") || StrEqual(FiredWeapon, "molotov") || StrEqual(FiredWeapon, "incgrenade") || StrEqual(FiredWeapon, "decoy"))
    {
        return;
    }

    int client = GetClientOfUserId(GetEventInt(e, "userid"));
    if(!IsValidClient(client))
    {
        return;
    }

    gB_PShots[client]++;
}

public void Event_PlayerDeath(Event e, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(e, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(e, "attacker"));
    bool headshot = GetEventBool(e, "headshot");

    if(!IsValidClient(client) || !IsValidClient(attacker))
    {
        return;
    }

    if(attacker == client)
    {
        return;
    }

    // Player Stats
    gB_PKills[attacker]++;
    gB_PDeaths[client]++;
    if(headshot)
        gB_PHS[attacker]++;
}

public void Event_RoundEnd(Event e, const char[] name, bool dontBroadcast)
{
    for(int i = 0; i <= MaxClients; i++)
    {
        if(IsValidClient(i))
        {
            UpdatePlayer(i, GetClientTime(i));
        }
    }
}

public void SQL_StartConnection()
{
    if(gB_DBSQL != null)
    {
        delete gB_DBSQL;
    }

    char gB_Error[255];
    if(SQL_CheckConfig("stats"))
    {
        gB_DBSQL = SQL_Connect("stats", true, gB_Error, 255);

        if(gB_DBSQL == null)
        {
            SetFailState("[Checker] Error on start. Reason: %s", gB_Error);
        }
    }
    else
    {
        SetFailState("[Checker] Cant find `stats` on database.cfg");
    }

    gB_DBSQL.SetCharset("utf8");

    char gB_Query[512];

    // User details
    FormatEx(gB_Query, 512, "CREATE TABLE IF NOT EXISTS `users` (`steamid` VARCHAR(17) NOT NULL, `name` BINARY(64), `ip` VARCHAR(64), `lastconn` TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY (`steamid`))");
    if(!SQL_FastQuery(gB_DBSQL, gB_Query))
    {
        SQL_GetError(gB_DBSQL, gB_Error, 255);
        LogError("[Checker] Cant create table. Error : %s", gB_Error);
    }

    // Match details
    FormatEx(gB_Query, 1024, "CREATE TABLE IF NOT EXISTS `matchdetails` (`matchid` INT NOT NULL AUTO_INCREMENT, `map` VARCHAR(32) NOT NULL, `user` VARCHAR(17) NOT NULL, `headshots` INT NOT NULL DEFAULT 0, `hits` INT NOT NULL DEFAULT 0, `shots` INT NOT NULL DEFAULT 0, `deaths` INT NOT NULL DEFAULT 0, `kills` INT NOT NULL DEFAULT 0, `seconds` INT NOT NULL DEFAULT 0, `winner` VARCHAR(17), PRIMARY KEY (`matchid`))");
    if(!SQL_FastQuery(gB_DBSQL, gB_Query))
    {
        SQL_GetError(gB_DBSQL, gB_Error, 255);
        LogError("[Checker] Cant create table. Error : %s", gB_Error);
    }
}

public void SQL_InsertMatch_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    // Get primary key
    int client = GetClientFromSerial(data);
    char gB_Query[512];
    FormatEx(gB_Query, 512, "SELECT (matchid) FROM `matchdetails` WHERE user = '%s' AND map = '%s' AND winner IS NULL;", gB_PSteamID64, gB_Map);
    PrintToChatAll(gB_Query);
    gB_DBSQL.Query(SQL_GetPrimaryKey_Callback, gB_Query, GetClientSerial(client), DBPrio_Normal);
}

public void SQL_GetPrimaryKey_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    if(results == null) {
        LogError("[Checker] Selecting match id error. Reason: %s", error);
    }

    // Set primary key
    while(results.FetchRow()){
        gB_MatchKey = results.FetchInt(0);
    }
}

public void Event_PlayerHurt(Event e, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(e, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(e, "attacker"));

    if(!IsValidClient(client) || !IsValidClient(attacker))
    {
        return;
    }

    if(!GetClientAuthId(attacker, AuthId_SteamID64, gB_ESteamID64, 32))
    {
        KickClient(client, "Verification problem , please reconnect.");
        return;
    }

    int gB_ClientTeam = GetClientTeam(client);
    int gB_AttackerTeam = GetClientTeam(attacker);

    if(gB_ClientTeam != gB_AttackerTeam)
    {
        gB_PHits[attacker]++;
    }
}

stock int GetPlayersCount()
{
    int count = 0;
    for(int i = 0; i < MaxClients; i++)
    {
        if(IsValidClient(i))
        {
            count++;
        }
    }
    return count;
}

public void OnClientPutInServer(int client)
{
    // Player Stuff
    gB_PKills[client] = 0;
    gB_PDeaths[client] = 0;
    gB_PShots[client] = 0;
    gB_PHits[client] = 0;
    gB_PHS[client] = 0;
    gB_PlayTime[client] = 0;

    char gB_PlayerName[MAX_NAME_LENGTH];
    GetClientName(client, gB_PlayerName, MAX_NAME_LENGTH);

    if(!GetClientAuthId(client, AuthId_SteamID64, gB_PSteamID64, 32))
    {
        KickClient(client, "Verification problem , please reconnect.");
        return;
    }

    // escaping name, dynamic array;
    int iLength = ((strlen(gB_PlayerName) * 2) + 1);
    char[] gB_EscapedName = new char[iLength];
    gB_DBSQL.Escape(gB_PlayerName, gB_EscapedName, iLength);

    char gB_ClientIP[64];
    GetClientIP(client, gB_ClientIP, 64);

    char gB_Query[512];

    // Set user details
    FormatEx(gB_Query, 512, "INSERT INTO `users` (`steamid`, `name`, `ip`) VALUES ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE `name` = '%s', `ip` = '%s';", gB_PSteamID64, gB_EscapedName, gB_ClientIP, gB_EscapedName, gB_ClientIP);
    gB_DBSQL.Query(SQL_InsertPlayer_Callback, gB_Query, GetClientSerial(client), DBPrio_Normal);

    // Set matchdetails for current user
    // If both are on the server start creating statistics (TODO: CHECK IF WORKING)
    if (gB_activeMatch) {
        FormatEx(gB_Query, 512, "INSERT INTO `matchdetails` (`map`, `user`) VALUES ('%s', '%s');", gB_Map, gB_PSteamID64);
        gB_DBSQL.Query(SQL_InsertMatch_Callback, gB_Query, GetClientSerial(client), DBPrio_Normal);
    }
}

public void SQL_InsertPlayer_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    int client = GetClientFromSerial(data);
    if(results == null)
    {
        if(client == 0)
        {
            LogError("[Checker] Client is not valid. Reason: %s", error);
        }
        else
        {
            LogError("[Checker] Cant use client data. Reason: %s", client, error);
        }
        return;
    }
}

stock bool IsValidClient(int client, bool alive = false, bool bots = false)
{
    if(client > 0 && client <= MaxClients && IsClientInGame(client) && (alive == false || IsPlayerAlive(client)) && (bots == false && !IsFakeClient(client)))
    {
        return true;
    }
    return false;
}

public void UpdatePlayer(int client, float timeonserver)
{
    if(!GetClientAuthId(client, AuthId_SteamID64, gB_PSteamID64, 32) && !gB_activeMatch)
    {
        return;
    }

    int gB_Seconds = RoundToNearest(timeonserver);

    char gB_Query[512];

    // Update matchdetails for current match
    FormatEx(gB_Query, 512, "UPDATE `matchdetails` SET `kills`= %d,`deaths`= %d,`shots`= %d,`hits`= %d,`headshots`= %d, `seconds` = seconds + %d WHERE `matchid` = %d;", gB_PKills[client], gB_PDeaths[client], gB_PShots[client], gB_PHits[client], gB_PHS[client], gB_Seconds, gB_MatchKey);
    gB_DBSQL.Query(SQL_UpdatePlayer_Callback, gB_Query, GetClientSerial(client), DBPrio_Normal);
}

public void SQL_UpdatePlayer_Callback(Database db, DBResultSet results, const char[] error, any data)
{
    int client = GetClientFromSerial(data);
    if(results == null)
    {
        if(client == 0)
        {
            LogError("[Checker] Client is not valid. Reason: %s", error);
        }
        else
        {
            PrintToChatAll(error);
            LogError("[Checker] Cant use client data. Reason: %s", client, error);
        }
        return;
    }
}