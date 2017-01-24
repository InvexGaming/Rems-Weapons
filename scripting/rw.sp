#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <clientprefs>
#include <multicolors>

#undef REQUIRE_PLUGIN
#include <lastrequest>

#pragma newdecls required

// Plugin Informaiton  
#define VERSION "3.01"
#define SERVER_LOCK_IP "45.121.211.57"

//Convars
ConVar cvar_c4 = null;
ConVar cvar_antiflood_enable = null;
ConVar cvar_antiflood_duration = null;

public Plugin myinfo =
{
  name = "CS:GO VIP Plugin (rw)",
  author = "Invex | Byte",
  description = "Special actions for VIP players.",
  version = VERSION,
  url = "http://www.invexgaming.com.au"
};

//Definitions
#define CHAT_TAG_PREFIX "[{green}RW{default}] "

#define MAX_PAINTS 1000
#define NUM_PRESETS 12
#define NUM_CSGO_WEAPONS 44
#define NUM_WEAPONLIST (NUM_PRESETS+NUM_CSGO_WEAPONS)

#define MAX_MENU_OPTIONS 6
#define MAX_NAMETAGTEXT_LENGTH 100
#define MAX_NAMETAG_LENGTH_POSSIBLE 161

#define DEFAULT_PAINT 0
#define DEFAULT_WEAR 0.00001
#define DEFAULT_SEED 0
#define DEFAULT_STATTRAK -1
#define DEFAULT_STATTRAKLOCK true
#define DEFAULT_ENTITYQUALITY 0
#define DEFAULT_NAMETAGTEXT ""
#define DEFAULT_NAMETAGCOLOURCODE ""
#define DEFAULT_NAMETAGFONTSIZE -1

#define INPUT_NONE -1
#define INPUT_PAINT 0
#define INPUT_WEAR 1
#define INPUT_SEED 2
#define INPUT_STATTRAK 3
#define INPUT_STATTRAKLOCK 4
#define INPUT_ENTITYQUALITY 5
#define INPUT_NAMETAGTEXT 6
#define INPUT_NAMETAGCOLOUR 7
#define INPUT_NAMETAGFONTSIZE 8

#define WEARLEVEL_FN 0.00001
#define WEARLEVEL_MW 0.15
#define WEARLEVEL_FT 0.33
#define WEARLEVEL_WW 0.72
#define WEARLEVEL_BS 0.95
#define FLOAT_COMPARE_EPSILON 0.02

#define PRESET_ACTION_NONE 0
#define PRESET_ACTION_SAVE 1
#define PRESET_ACTION_LOAD 2
#define PRESET_ACTION_RESET 3
#define PRESET_ACTION_PRINTINFO 4

//Database
Handle db = null;
DBStatement hUpdateStmt = null;
DBStatement hInsertStmt = null;

//Flags
AdminFlag rwFlag = Admin_Custom3;

//Ints
enum Listing
{
  String:paintName[64],
  paintNum,
}

int g_paints[MAX_PAINTS][Listing];
int g_paintCount = 0;
bool g_canUse[MAXPLAYERS+1] = {true, ...}; //for anti-flood
bool g_hosties = false; //is server running hosties?
int g_iWaitingForSayInput[MAXPLAYERS+1] = {INPUT_NONE, ...};
int g_presetAction[MAXPLAYERS+1] = {PRESET_ACTION_NONE, ...};

//Cached preferences
enum Preferences
{
  paint,
  Float:wear,
  seed,
  stattrak,
  bool:stattrakLock,
  entityQuality,
  String:nametagText[255],
  String:nametagColourCode[10],
  nametagFontSize
}
int g_rwPreferences[MAXPLAYERS+1][NUM_WEAPONLIST][Preferences];
bool g_PreferencesLoaded[MAXPLAYERS+1] = {false, ...};

//CSGO Weapons (alphabetically sorted)
char weaponList[NUM_WEAPONLIST][] = {"weapon_ak47","weapon_aug","weapon_awp","weapon_c4","weapon_cz75a","weapon_deagle","weapon_elite","weapon_famas","weapon_fiveseven","weapon_g3sg1","weapon_galilar","weapon_glock","weapon_bayonet","weapon_knife_survival_bowie","weapon_knife_butterfly","weapon_knife_falchion","weapon_knife_flip","weapon_knife_gut","weapon_knife_tactical","weapon_knife_karambit","weapon_knife_m9_bayonet","weapon_knife_push","weapon_m249","weapon_m4a1","weapon_m4a1_silencer","weapon_mac10","weapon_mag7","weapon_mp7","weapon_mp9","weapon_negev","weapon_nova","weapon_hkp2000","weapon_p250","weapon_p90","weapon_bizon","weapon_revolver","weapon_sawedoff","weapon_scar20","weapon_sg556","weapon_ssg08","weapon_tec9","weapon_ump45","weapon_usp_silencer","weapon_xm1014", "preset_1","preset_2","preset_3","preset_4","preset_5","preset_6","preset_7","preset_8","preset_9","preset_10","preset_11","preset_12"};

char weaponListNiceNames[NUM_WEAPONLIST][] = {"AK-47","AUG","AWP","C4","CZ75 Auto","Deagle","Dual Berettas","Famas","Five-SeveN","G3SG1","Galil AR","Glock","Knife (Bayonet)","Knife (Bowie)","Knife (Butterfly)","Knife (Falchion)","Knife (Flip)","Knife (Gut)","Knife (Huntsman)","Knife (Karambit)","Knife (M9 Bayonet)","Knife (Shadow Daggers)","M249","M4A1","M4A1-S","MAC-10","MAG-7","MP7","MP9","Negev","Nova","P2000","P250","P90","PP-Bizon","R8 Revolver","Sawed-Off","SCAR-20","SG 553","SSG 08","Tec-9","UMP-45","USP-S","XM1014", "SLOT 1","SLOT 2","SLOT 3","SLOT 4","SLOT 5","SLOT 6","SLOT 7","SLOT 8","SLOT 9","SLOT 10","SLOT 11","SLOT 12"};

int g_selectedWeaponIndex[MAXPLAYERS+1] = {-1, ...}; //for menu

//Menus
Menu mainMenu[MAXPLAYERS+1] = {null, ...};
Menu gunSelectMenu = null;
Menu skinMenu = null;
Menu wearMenu = null;
Menu seedMenu = null;
Menu weaponTypeMenu = null;
Menu stattrakMenu = null;
Menu entityQualityMenu = null;
Menu nametagMenu = null;
Menu nametagColourMenu = null;
Menu nametagFontSizeMenu = null;
Menu presetManagerMenu = null;
Menu slotSelectMenu = null;

// Plugin Start
public void OnPluginStart()
{
  //Anti-share
  if (strcmp(SERVER_LOCK_IP, "") != 0) {
    char m_szIP[64];
    int m_unIP = GetConVarInt(FindConVar("hostip"));
    Format(m_szIP, sizeof(m_szIP), "%d.%d.%d.%d", (m_unIP >> 24) & 0x000000FF, (m_unIP >> 16) & 0x000000FF, (m_unIP >> 8) & 0x000000FF, m_unIP & 0x000000FF);

    if (strcmp(SERVER_LOCK_IP, m_szIP) != 0)
      SetFailState("Nope.");
  }
  
  //Translations
  LoadTranslations("rw.phrases");
  
  //Flags
  CreateConVar("sm_rw_version", VERSION, "", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);
  
  //Convars
  cvar_c4 = CreateConVar("sm_rw_c4", "1", "No description provided (see source). 1 = enabled, 0 = disabled");
  cvar_antiflood_enable = CreateConVar("sm_rw_antiflood_enable", "1", "No description provided (see source). 1 = enabled, 0 = disabled.");
  cvar_antiflood_duration = CreateConVar("sm_rw_antiflood_duration", "0.3", "No description provided (see source).");
  
  //Load config file info
  LoadPaintConfigFile();
  
  //Process players and set them up
  for (int client = 1; client <= MaxClients; ++client) {
    if (!IsClientInGame(client))
      continue;
    
    OnClientPutInServer(client);
  }
  
  //Hook events
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("player_death", Event_PlayerDeath);
  
  //Connect and load from database
  LoadDatabasePreferences(true);
  
  //Create Menus
  SetupMenus();
}

//Process clients when plugin ends (call cleanup for each client)
public void OnPluginEnd()
{
  for (int client = 1; client <= MaxClients; ++client) {
    if (IsClientInGame(client)) {
      OnClientDisconnect(client);
    }
  }
}

//SDKhook when clients connect to server
public void OnClientPutInServer(int client)
{
  if (!IsFakeClient(client))
    SDKHook(client, SDKHook_WeaponEquipPost, OnPostWeaponEquip);
  
  if (GetConVarBool(cvar_antiflood_enable))
    g_canUse[client] = true; //anti-flood
    
  g_selectedWeaponIndex[client] = -1;
}

//Clean up when client disconnects
public void OnClientDisconnect(int client)
{
  g_PreferencesLoaded[client] = false;
  g_selectedWeaponIndex[client] = -1;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  CancelMenu(mainMenu[client]);
  g_selectedWeaponIndex[client] = -1;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  
  CancelMenu(mainMenu[client]);
  
  //Check if client is targetting active weapon
  if (g_selectedWeaponIndex[client] == -1) {
    //If so change this to something else and we'll restore it when they respawn
    g_selectedWeaponIndex[client] = 0;
  }
  
  //Process stattrack kills for attacker
  int wlIndex = GetActiveWeaponListIndex(attacker);
  if (wlIndex != -1 && !g_rwPreferences[attacker][wlIndex][stattrakLock]) {
    if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker) && IsPlayerAlive(attacker)) {
      int newStattrakKills = g_rwPreferences[attacker][wlIndex][stattrak];
      if (newStattrakKills >= 0) {
        ++newStattrakKills; //increase by one
        g_rwPreferences[attacker][wlIndex][stattrak] = newStattrakKills;
        StorePreferenceValue(attacker, INPUT_STATTRAK, newStattrakKills, _, _, false);
      }
    }
  }
}

//Skin weapons that we pick up
public Action OnPostWeaponEquip(int client, int weapon)
{
  DataPack pack = new DataPack();
  CreateDataTimer(0.0, WeaponPickUpSkin, pack);
  pack.WriteCell(EntIndexToEntRef(client));
  pack.WriteCell(EntIndexToEntRef(weapon));
}

//Apply skin to weapon that was equiped
public Action WeaponPickUpSkin(Handle timer, DataPack pack)
{
  int client, weapon;
  pack.Reset();
  
  client = EntRefToEntIndex(pack.ReadCell());
  weapon = EntRefToEntIndex(pack.ReadCell());
  
  //Check client
  if (!IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Handled;
  
  //Check hosties
  if (g_hosties && IsClientInLastRequest(client))
    return Plugin_Handled;
  
  //Check if VIP
  int isVIP = CheckCommandAccess(client, "", FlagToBit(rwFlag));
  
  if (!isVIP)
    return Plugin_Handled;
  
  //Check weapon
  if(weapon == INVALID_ENT_REFERENCE || weapon < 1 || !IsValidEdict(weapon) || !IsValidEntity(weapon))
    return Plugin_Handled;
  
  //Check previous owner and item id's
  if (GetEntProp(weapon, Prop_Send, "m_hPrevOwner") > 0 || GetEntProp(weapon, Prop_Send, "m_iItemIDHigh") == -1)
    return Plugin_Handled;
  
  //Get the proper classname
  char Classname[64];
  int weaponItemDefinitionIndex = GetProperClassname(client, weapon, Classname);
  
  //Check to see if classname is allowed
  if (weaponItemDefinitionIndex == -1)
    return Plugin_Handled;
  
  //Get wlindex of gun
  int wlIndex = GetWeaponListIndex(Classname);
  if (wlIndex == -1)
    return Plugin_Handled;
  
  GivePlayerRWItem(client, weapon, Classname, g_rwPreferences[client][wlIndex][paint], g_rwPreferences[client][wlIndex][wear], g_rwPreferences[client][wlIndex][seed], g_rwPreferences[client][wlIndex][stattrak], g_rwPreferences[client][wlIndex][entityQuality], g_rwPreferences[client][wlIndex][nametagText], g_rwPreferences[client][wlIndex][nametagColourCode], g_rwPreferences[client][wlIndex][nametagFontSize]);
  
  return Plugin_Handled;
}

//Monitor chat to capture commands
public Action OnClientSayCommand(int client, const char[] command_t, const char[] command)
{
  //Check if this is say input
  if (g_iWaitingForSayInput[client] != INPUT_NONE) {
    //Get wlindex here
    int wlIndex = GetTargetedWeaponListIndex(client, true);
    
    if (g_iWaitingForSayInput[client] == INPUT_WEAR) {
      if (IsStringNumeric(command)) {
        float newWear = StringToFloat(command);
        
        if (newWear < 0.0 || newWear > 1.0) {
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Wear Value Wrong");
        } else if (wlIndex != -1) {
          StorePreferenceValue(client, INPUT_WEAR, newWear);
          char newWearString[64];
          FloatToString(newWear, newWearString, sizeof(newWearString));
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Value Updated", "wear", weaponListNiceNames[wlIndex], newWearString);
        }
      } else {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Wear Value Wrong");
      }
      
      DisplayMenu(wearMenu, client, MENU_TIME_FOREVER);
    }
    else if (g_iWaitingForSayInput[client] == INPUT_SEED) {
      if (IsStringNumeric(command)) {
        int newSeed = StringToInt(command);
        if (newSeed < 0) {
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Seed Value Wrong");
        } else if (wlIndex != -1) {
          StorePreferenceValue(client, INPUT_SEED, newSeed);
          char newSeedString[64];
          IntToString(newSeed, newSeedString, sizeof(newSeedString));
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Value Updated", "pattern seed", weaponListNiceNames[wlIndex], newSeedString);
        }
      } else {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Seed Value Wrong");
      }
      
      DisplayMenu(seedMenu, client, MENU_TIME_FOREVER);
    }
    else if (g_iWaitingForSayInput[client] == INPUT_PAINT) {
      //Perform skin search
      int newPaint = SearchPaintIndex(command);
      if (newPaint == -1)
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Skin Selected Not Found", command);
      else {
        if (wlIndex != -1) {
          StorePreferenceValue(client, INPUT_PAINT, newPaint);
          PrintSkinSelectionMessage(client, wlIndex);
        }
      }
        
      DisplayMenu(skinMenu, client, MENU_TIME_FOREVER);
    }
    else if (g_iWaitingForSayInput[client] == INPUT_STATTRAK) {
      if (IsStringNumeric(command)) {
        int newStattrak = StringToInt(command);
        if (newStattrak < 0) {
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Stattrak Kill Count Value Wrong");
        } else if (wlIndex != -1) {
          StorePreferenceValue(client, INPUT_STATTRAK, newStattrak);
          char newStattrakString[64];
          IntToString(newStattrak, newStattrakString, sizeof(newStattrakString));
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Value Updated", "StatTrak™ kill count value", weaponListNiceNames[wlIndex], newStattrakString);
        }
      } else {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Stattrak Kill Count Value Wrong");
      }
      
      DisplayMenu(stattrakMenu, client, MENU_TIME_FOREVER);
    }
    else if (g_iWaitingForSayInput[client] == INPUT_NAMETAGTEXT) {
      //Perform skin search
      if (strlen(command) > MAX_NAMETAGTEXT_LENGTH)
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Nametag Value Wrong", MAX_NAMETAGTEXT_LENGTH);
      else if (wlIndex != -1) {
        StorePreferenceValue(client, INPUT_NAMETAGTEXT, _, command);
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Value Updated", "nametag", weaponListNiceNames[wlIndex], command);
      }
      
      DisplayMenu(nametagMenu, client, MENU_TIME_FOREVER);
    }
    
    //Reset
    g_iWaitingForSayInput[client] = INPUT_NONE;
    return Plugin_Handled;
  }
  
  //Check if command starts with following strings
  if( StrContains(command, "!rw", false) == 0 ||
      StrContains(command, "!rwskin", false) == 0 ||
      StrContains(command, "!rwskins", false) == 0 ||
      StrContains(command, "!ws", false) == 0 ||
      StrContains(command, "!wskins", false) == 0 ||
      StrContains(command, "!pk", false) == 0 ||
      StrContains(command, "!paints", false) == 0 ||
      StrContains(command, "/rw", false) == 0 ||
      StrContains(command, "/rwskin", false) == 0 ||
      StrContains(command, "/rwskins", false) == 0 ||
      StrContains(command, "/ws", false) == 0 ||
      StrContains(command, "/wskins", false) == 0 ||
      StrContains(command, "/pk", false) == 0 ||
      StrContains(command, "/paints", false) == 0
    )
  {
    //Get VIP status
    int isVIP = CheckCommandAccess(client, "", FlagToBit(rwFlag));
    
    //Only VIPS can use this plugin unless you are setting the default skin
    if (!isVIP) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Must be VIP");
      return Plugin_Handled;
    }
    
    //Check if loaded
    if (!g_PreferencesLoaded[client]) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Preferences Not Loaded");
      return Plugin_Handled;
    }
    
    //Check if any arguments provided
    char buffer[16][255];
    int index = ExplodeString(command, " ", buffer, sizeof(buffer), sizeof(buffer[]), true);
    
    if (index > 1) {
      //Construct actual search term
      char searchQuery[255];
      for (int i = 1; i < index; ++i) { //start from index 1 to omit command
        Format(searchQuery, sizeof(searchQuery), "%s %s", searchQuery, buffer[i]);
      }
      TrimString(searchQuery);
      
      //Perform skin search
      int newPaint = SearchPaintIndex(searchQuery);
      if (newPaint == -1)
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Skin Selected Not Found", searchQuery);
      else {
        int wlIndex = GetTargetedWeaponListIndex(client, true);
        if (wlIndex != -1) {
          StorePreferenceValue(client, INPUT_PAINT, newPaint);
          PrintSkinSelectionMessage(client, wlIndex);
        }
      }
    }
    else {
      //Otherwise show menu
      DisplayMenu(mainMenu[client], client, MENU_TIME_FOREVER);
    }
    
    return Plugin_Handled;
  }
  
  return Plugin_Continue;
}

//Read config file containing paint information
void LoadPaintConfigFile()
{
  char configFile[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, configFile, sizeof(configFile), "configs/csgo_rw.cfg");
  
  //Set default paint values
  Format(g_paints[0][paintName], 64, "Default Skin");
  g_paints[0][paintNum] = 0;
  
  Handle kv;
  g_paintCount = 1;

  kv = CreateKeyValues("Paints");
  FileToKeyValues(kv, configFile);

  if (!KvGotoFirstSubKey(kv)) {
    SetFailState("CFG File not found: %s", configFile);
    CloseHandle(kv);
  }
  
  do {
    KvGetSectionName(kv, g_paints[g_paintCount][paintName], 64); //size hardcoded here due to olddecl enums
    g_paints[g_paintCount][paintNum] = KvGetNum(kv, "paint", 0);

    g_paintCount++;
  } while (KvGotoNextKey(kv));
  
  CloseHandle(kv);
}

void LoadDatabasePreferences(bool reconnect = false, char dbName[16] = "rw")
{
  //Check if we should reconnect
  if (db != null) {
    if (reconnect) {
      CloseHandle(db);
      db = null;
    }
    //If db is not null and we aren't reconnecting
    //We cant proceed
    else
      return;
  }

  //Check if databases.cfg entry exist
  if (!SQL_CheckConfig(dbName)) {
    LogMessage("rw database does not exist.");
    return;
  }
  
  SQL_TConnect(LoadDatabasePreferences_OnDBConnect, dbName);
}

public void LoadDatabasePreferences_OnDBConnect(Handle owner, Handle hndl, const char[] error, any data)
{
  if (hndl == null) {
    SetFailState("Database connection failed.");
  }
  else {
    //Update db handle
    db = hndl;
  
    char buffer[3096];
    SQL_GetDriverIdent(SQL_ReadDriver(hndl), buffer, sizeof(buffer));
    
    //Non sqlite databases not supported
    if (!StrEqual(buffer, "sqlite", false)) {
      SetFailState("Non sqlite databases are not supported.");
      return;
    }
    
    //Create SQL Database if it doesn't exist
    Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS rw (steamid VARCHAR(32) NOT NULL,weaponname VARCHAR(32) NOT NULL,paint INT NOT NULL,wear FLOAT NOT NULL,seed INT NOT NULL,stattrak INT NOT NULL,stattrakLock BOOLEAN NOT NULL,entityQuality INT NOT NULL,nametagText VARCHAR(255) NOT NULL,nametagColourCode VARCHAR(10) NOT NULL,nametagFontSize INT NOT NULL, PRIMARY KEY  (steamid, weaponname))");
    
    SQL_TQuery(hndl, LoadDatabasePreferences_InitCallBack, buffer);
  }
}

//Initial database callback
public void LoadDatabasePreferences_InitCallBack(Handle owner, Handle hndl, const char[] error, any data)
{
  if (hndl == null) {
    return;
  }
  
  for (int client = 1; client <= MaxClients; ++client) {
    if (IsClientInGame(client)) {
      OnClientPostAdminCheck(client);
    }
  }
}

//Check steamID once client is authorized 
public void OnClientPostAdminCheck(int client)
{
  if (!IsFakeClient(client)) {
    //Clear current values
    ClearLocalPreferences(client);
    
    //Do not load values in for nonVIPs
    int isVIP = CheckCommandAccess(client, "", FlagToBit(rwFlag));
    
    if (!isVIP) {
      g_PreferencesLoaded[client] = true;
      return;
    }
    
    //Load new values for VIPs
    CheckSteamID(client);
  }
}

//Check users steam ID in database
void CheckSteamID(int client)
{
  char query[1024], steamid[32];
  GetClientAuthId(client, AuthId_Steam2,  steamid, sizeof(steamid) );
  
  Format(query, sizeof(query), "SELECT weaponname, paint, wear, seed, stattrak, stattrakLock, entityQuality, nametagText, nametagColourCode, nametagFontSize FROM rw WHERE steamid = '%s'", steamid);
  SQL_TQuery(db, CheckSteamID_callback, query, GetClientUserId(client));
}

public void CheckSteamID_callback(Handle owner, Handle hndl, const char[] error, any data)
{
  int client = GetClientOfUserId(data);
 
  // Make sure the client didn't disconnect while the thread was running
  if (client == 0)
    return;
  
  //Check to see if database connection is up
  if (hndl == null) {
    LoadDatabasePreferences();
    return;
  }
  
  //Process rows
  while (SQL_FetchRow(hndl)) {
    //Variables
    char db_weaponName[32];
    int db_paint;
    float db_wear;
    int db_seed;
    int db_stattrak;
    bool db_stattrakLock;
    int db_entityQuality;
    char db_nametagText[255];
    char db_nametagColourCode[10];
    int db_nametagFontSize;
    
    //Fetch results
    SQL_FetchString(hndl, 0, db_weaponName, sizeof(db_weaponName));
    db_paint = SQL_FetchInt(hndl, 1);
    db_wear = SQL_FetchFloat(hndl, 2);
    db_seed = SQL_FetchInt(hndl, 3);
    db_stattrak = SQL_FetchInt(hndl, 4);
    db_stattrakLock = view_as<bool>(SQL_FetchInt(hndl, 5));
    db_entityQuality = SQL_FetchInt(hndl, 6);
    SQL_FetchString(hndl, 7, db_nametagText, sizeof(db_nametagText));
    SQL_FetchString(hndl, 8, db_nametagColourCode, sizeof(db_nametagColourCode));
    db_nametagFontSize = SQL_FetchInt(hndl, 9);
    
    //Find wlIndex via weapon name
    int wlIndex = GetWeaponListIndex(db_weaponName);
    if (wlIndex != -1) {
      //Store our values
      g_rwPreferences[client][wlIndex][paint] = db_paint;
      g_rwPreferences[client][wlIndex][wear] = db_wear;
      g_rwPreferences[client][wlIndex][seed] = db_seed;
      g_rwPreferences[client][wlIndex][stattrak] = db_stattrak;
      g_rwPreferences[client][wlIndex][stattrakLock] = db_stattrakLock;
      g_rwPreferences[client][wlIndex][entityQuality] = db_entityQuality;
      Format(g_rwPreferences[client][wlIndex][nametagText], 255, db_nametagText);
      Format(g_rwPreferences[client][wlIndex][nametagColourCode], 10, db_nametagColourCode);
      g_rwPreferences[client][wlIndex][nametagFontSize] = db_nametagFontSize;
    }
  }
  
  g_PreferencesLoaded[client] = true;
}

//Clear local values
void ClearLocalPreferences(int client)
{
  for (int wlIndex = 0; wlIndex < sizeof(weaponList); ++wlIndex) {
    ClearLocalPreferencesForWlIndex(client, wlIndex);
  }
}

//Clear local values for single weapon index
void ClearLocalPreferencesForWlIndex(int client, int wlIndex)
{
  g_rwPreferences[client][wlIndex][paint] = DEFAULT_PAINT;
  g_rwPreferences[client][wlIndex][wear] = DEFAULT_WEAR;
  g_rwPreferences[client][wlIndex][seed] = DEFAULT_SEED;
  g_rwPreferences[client][wlIndex][stattrak] = DEFAULT_STATTRAK;
  g_rwPreferences[client][wlIndex][stattrakLock] = DEFAULT_STATTRAKLOCK;
  g_rwPreferences[client][wlIndex][entityQuality] = DEFAULT_ENTITYQUALITY;
  Format(g_rwPreferences[client][wlIndex][nametagText], 255, DEFAULT_NAMETAGTEXT);
  Format(g_rwPreferences[client][wlIndex][nametagColourCode], 10, DEFAULT_NAMETAGCOLOURCODE);
  g_rwPreferences[client][wlIndex][nametagFontSize] = DEFAULT_NAMETAGFONTSIZE;
}

//Check if preferences are default for a wlindex
bool IsDefaultPreferencesForWlIndex(int client, int wlIndex)
{
  if (g_rwPreferences[client][wlIndex][paint] != DEFAULT_PAINT)
    return false;
  
  if (FloatAbs(g_rwPreferences[client][wlIndex][wear] - DEFAULT_WEAR) > FLOAT_COMPARE_EPSILON)
    return false;
  
  if (g_rwPreferences[client][wlIndex][seed] != DEFAULT_SEED)
    return false;
  
  if (g_rwPreferences[client][wlIndex][stattrak] != DEFAULT_STATTRAK)
    return false;
    
  if (g_rwPreferences[client][wlIndex][stattrak] != DEFAULT_STATTRAK)
    return false;
    
  if (g_rwPreferences[client][wlIndex][stattrakLock] != DEFAULT_STATTRAKLOCK)
    return false;
  
  if (g_rwPreferences[client][wlIndex][entityQuality] != DEFAULT_ENTITYQUALITY)
    return false;
  
  if (!StrEqual(g_rwPreferences[client][wlIndex][nametagText], DEFAULT_NAMETAGTEXT))
    return false;
  
  if (!StrEqual(g_rwPreferences[client][wlIndex][nametagColourCode], DEFAULT_NAMETAGCOLOURCODE))
    return false;
  
  if (g_rwPreferences[client][wlIndex][nametagFontSize] != DEFAULT_NAMETAGFONTSIZE)
    return false;
  
  return true;
}

//Copy preferences from one wlIndex to another
void CopyLocalPreferences(int client, int sourceWlIndex, int destWlIndex)
{
  g_rwPreferences[client][destWlIndex][paint] = g_rwPreferences[client][sourceWlIndex][paint];
  g_rwPreferences[client][destWlIndex][wear] = g_rwPreferences[client][sourceWlIndex][wear];
  g_rwPreferences[client][destWlIndex][seed] = g_rwPreferences[client][sourceWlIndex][seed];
  g_rwPreferences[client][destWlIndex][stattrak] = g_rwPreferences[client][sourceWlIndex][stattrak];
  g_rwPreferences[client][destWlIndex][stattrakLock] = g_rwPreferences[client][sourceWlIndex][stattrakLock];
  g_rwPreferences[client][destWlIndex][entityQuality] = g_rwPreferences[client][sourceWlIndex][entityQuality];
  Format(g_rwPreferences[client][destWlIndex][nametagText], 255, g_rwPreferences[client][sourceWlIndex][nametagText]);
  Format(g_rwPreferences[client][destWlIndex][nametagColourCode], 10, g_rwPreferences[client][sourceWlIndex][nametagColourCode]);
  g_rwPreferences[client][destWlIndex][nametagFontSize] = g_rwPreferences[client][sourceWlIndex][nametagFontSize];
}

//Update cached preferences for a wlIndex and persist them in DB
//We will use two prepared statements to achieve an INSERT OR UPDATE effect
//First we update (which will fail if keys not present)
//Then we insert which will result in a NOP if the two primary keys are already present
void UpdateStoredDatabasePreferences(int client, int wlIndex)
{
  if (IsFakeClient(client))
    return;
    
  //Save changes to datebase
  char steamid[32];
  if (!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
    return;
  
  //Check prepared statement
  if (hUpdateStmt == null) {
    char error[512];
    hUpdateStmt = SQL_PrepareQuery(db, "UPDATE rw SET paint=?, wear=?, seed=?, stattrak=?, stattrakLock=?, entityQuality=?, nametagText=?, nametagColourCode=?, nametagFontSize=? WHERE steamid=? AND weaponname=?", error, sizeof(error));
    
    if (hUpdateStmt == null) {
      return;
    }
  }
  
  if (hInsertStmt == null) {
    char error2[512];
    hInsertStmt = SQL_PrepareQuery(db, "INSERT OR IGNORE INTO rw (steamid, weaponname, paint, wear, seed, stattrak, stattrakLock, entityQuality, nametagText, nametagColourCode, nametagFontSize) VALUES (?,?,?,?,?,?,?,?,?,?,?)", error2, sizeof(error2));
    
    if (hInsertStmt == null) {
      return;
    }
  }

  //Update
  SQL_BindParamInt(hUpdateStmt, 0, g_rwPreferences[client][wlIndex][paint], true);
  SQL_BindParamFloat(hUpdateStmt, 1, g_rwPreferences[client][wlIndex][wear]);
  SQL_BindParamInt(hUpdateStmt, 2, g_rwPreferences[client][wlIndex][seed], true);
  SQL_BindParamInt(hUpdateStmt, 3, g_rwPreferences[client][wlIndex][stattrak], true);
  SQL_BindParamInt(hUpdateStmt, 4, g_rwPreferences[client][wlIndex][stattrakLock], true);
  SQL_BindParamInt(hUpdateStmt, 5, g_rwPreferences[client][wlIndex][entityQuality], true);
  SQL_BindParamString(hUpdateStmt, 6, g_rwPreferences[client][wlIndex][nametagText], false);
  SQL_BindParamString(hUpdateStmt, 7, g_rwPreferences[client][wlIndex][nametagColourCode], false);
  SQL_BindParamInt(hUpdateStmt, 8, g_rwPreferences[client][wlIndex][nametagFontSize], true);
  SQL_BindParamString(hUpdateStmt, 9, steamid, false);
  SQL_BindParamString(hUpdateStmt, 10, weaponList[wlIndex], false);
  
  //Insert
  SQL_BindParamString(hInsertStmt, 0, steamid, false);
  SQL_BindParamString(hInsertStmt, 1, weaponList[wlIndex], false);
  SQL_BindParamInt(hInsertStmt, 2, g_rwPreferences[client][wlIndex][paint], true);
  SQL_BindParamFloat(hInsertStmt, 3, g_rwPreferences[client][wlIndex][wear]);
  SQL_BindParamInt(hInsertStmt, 4, g_rwPreferences[client][wlIndex][seed], true);
  SQL_BindParamInt(hInsertStmt, 5, g_rwPreferences[client][wlIndex][stattrak], true);
  SQL_BindParamInt(hInsertStmt, 6, g_rwPreferences[client][wlIndex][stattrakLock], true);
  SQL_BindParamInt(hInsertStmt, 7, g_rwPreferences[client][wlIndex][entityQuality], true);
  SQL_BindParamString(hInsertStmt, 8, g_rwPreferences[client][wlIndex][nametagText], false);
  SQL_BindParamString(hInsertStmt, 9, g_rwPreferences[client][wlIndex][nametagColourCode], false);
  SQL_BindParamInt(hInsertStmt, 10, g_rwPreferences[client][wlIndex][nametagFontSize], true);
  
  SQL_Execute(hUpdateStmt);
  SQL_Execute(hInsertStmt);
}

//General database callback
public void DBGeneral_callback(Handle owner, Handle hndl, const char[] error, any data)
{
  return;
}

//Setup all menus program will use
void SetupMenus()
{
  //Delete old menus
  if (gunSelectMenu != null)
    delete gunSelectMenu;
    
  if (skinMenu != null)
    delete skinMenu;
  
  if (wearMenu != null)
    delete wearMenu;
  
  if (seedMenu != null)
    delete seedMenu;
    
  if (weaponTypeMenu != null)
    delete weaponTypeMenu; 
   
  if (stattrakMenu != null)
    delete stattrakMenu;
    
  if (entityQualityMenu != null)
    delete entityQualityMenu;
    
  if (nametagMenu != null)
    delete nametagMenu;
    
  if (nametagColourMenu != null)
    delete nametagColourMenu;
    
  if (nametagFontSizeMenu != null)
    delete nametagFontSizeMenu;
    
  if (presetManagerMenu != null)
    delete presetManagerMenu;
    
  if (slotSelectMenu != null)
    delete slotSelectMenu;
  
  //Main menu
  for (int client = 1; client < MaxClients; ++client) {
    //Delete old main menus
    if (mainMenu[client] != null)
      delete mainMenu[client];
    
    mainMenu[client] = new Menu(MainMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End |MenuAction_DisplayItem|MenuAction_DrawItem);
    
    char selectWeaponText[64];
    char currentWeapon[64];
    if (g_selectedWeaponIndex[client] == -1)
      Format(currentWeapon, sizeof(currentWeapon), "Active Weapon");
    else
      Format(currentWeapon, sizeof(currentWeapon), weaponListNiceNames[g_selectedWeaponIndex[client]]);
    
    Format(selectWeaponText, sizeof(selectWeaponText), "Targetting: %s", currentWeapon);
    
    //Use new line trick to add spacers that don't take menu number slots
    SetMenuTitle(mainMenu[client], "Rems Weapons (RW) V%s\n \n%s", VERSION, selectWeaponText);
    
    AddMenuItem(mainMenu[client], "selectweapon", "Select Weapon");
    AddMenuItem(mainMenu[client], "selectskin", "Select Skin");
    AddMenuItem(mainMenu[client], "selectwear", "Select Wear");
    AddMenuItem(mainMenu[client], "selectseed", "Select Seed");
    AddMenuItem(mainMenu[client], "customizeweapontype", "Customize Weapon Type");
    AddMenuItem(mainMenu[client], "applynametag", "Apply Nametag");
    AddMenuItem(mainMenu[client], "presetmanager", "Preset Manager");
    SetMenuPagination(mainMenu[client], MENU_NO_PAGINATION);
    SetMenuExitButton(mainMenu[client], true);
  }
  
  //Weapon select menu
  gunSelectMenu = new Menu(GunSelectMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(gunSelectMenu, "Select Gun");
  AddMenuItem(gunSelectMenu, "-1", "Active Weapon");

  for (int i = 0; i < sizeof(weaponList); ++i) {
    //Check if C4 allowed
    if (StrEqual(weaponListNiceNames[i], "C4") && !GetConVarBool(cvar_c4))
      continue;
    
    //Ignore presets
    if (StrContains(weaponList[i], "preset_", false) != -1)
      continue;
    
    char item[4];
    Format(item, sizeof(item), "%i", i);
    AddMenuItem(gunSelectMenu, item, weaponListNiceNames[i]);
  }
  SetMenuExitBackButton(gunSelectMenu, true);
  
  //Skin Menu
  skinMenu = new Menu(SkinMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End |MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(skinMenu, "Select Skin:");
  AddMenuItem(skinMenu, "search", "Search For Skin");
  AddMenuItem(skinMenu, "-1", "Random Skin");
  AddMenuItem(skinMenu, "0", "Default Skin");
  
  for (int i = 1; i < g_paintCount; ++i) {
    char item[4];
    Format(item, sizeof(item), "%i", i);
    AddMenuItem(skinMenu, item, g_paints[i][paintName]);
  }
  SetMenuExitBackButton(skinMenu, true);
  
  //Wear Menu
  wearMenu = new Menu(WearMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End |MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(wearMenu, "Select Wear:");
  AddMenuItem(wearMenu, "custom", "Enter Custom Wear/Float");
  char item[12];
  Format(item, sizeof(item), "%f", WEARLEVEL_FN);
  AddMenuItem(wearMenu, item, "Factory New (FN)");
  Format(item, sizeof(item), "%f", WEARLEVEL_MW);
  AddMenuItem(wearMenu, item, "Minimal Wear (MW)")
  Format(item, sizeof(item), "%f", WEARLEVEL_FT);
  AddMenuItem(wearMenu, item, "Field Tested (FT)");
  Format(item, sizeof(item), "%f", WEARLEVEL_WW);
  AddMenuItem(wearMenu, item, "Well Worn (WW)");
  Format(item, sizeof(item), "%f", WEARLEVEL_BS);
  AddMenuItem(wearMenu, item, "Battle Scared (BS)");
  SetMenuExitBackButton(wearMenu, true);
  
  //Seed Menu
  seedMenu = new Menu(SeedMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem);
  SetMenuTitle(seedMenu, "Select Seed:");
  AddMenuItem(seedMenu, "custom", "Enter Custom Seed");
  AddMenuItem(seedMenu, "-1", "Random Seed");
  AddMenuItem(seedMenu, "0", "Default Seed");
  AddMenuItem(seedMenu, "next", "Next Seed");
  AddMenuItem(seedMenu, "prev", "Previous Seed");
  SetMenuExitBackButton(seedMenu, true);
  
  //Weapon Type Menu
  weaponTypeMenu = new Menu(WeaponTypeMenuHandler);
  SetMenuTitle(weaponTypeMenu, "Customize Weapon Type:");
  AddMenuItem(weaponTypeMenu, "stattrak", "StatTrak™ Options");
  AddMenuItem(weaponTypeMenu, "entityQuality", "Select Weapon Type");
  SetMenuExitBackButton(weaponTypeMenu, true);
  
  //Stattrak menu
  stattrakMenu = new Menu(StattrakMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem);
  SetMenuTitle(stattrakMenu, "StatTrak™ Options:");
  AddMenuItem(stattrakMenu, "toggle", "Toggle StatTrak™");
  AddMenuItem(stattrakMenu, "setkills", "Set StatTrak™ Kills");
  AddMenuItem(stattrakMenu, "togglelock", "Toggle Kill Counter Lock");
  SetMenuExitBackButton(stattrakMenu, true);
  
  //entityQuality Menu
  entityQualityMenu = new Menu(EntityQualityMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(entityQualityMenu, "Select Weapon Type:");
  AddMenuItem(entityQualityMenu, "0", "Default (Normal)");
  AddMenuItem(entityQualityMenu, "1", "Genuine");
  AddMenuItem(entityQualityMenu, "2", "Vintage");
  AddMenuItem(entityQualityMenu, "5", "Community");
  AddMenuItem(entityQualityMenu, "6", "Developer (Valve)");
  AddMenuItem(entityQualityMenu, "7", "Self-Made (Prototype)");
  AddMenuItem(entityQualityMenu, "8", "Customized");
  AddMenuItem(entityQualityMenu, "10", "Completed");
  AddMenuItem(entityQualityMenu, "12", "Souvenir");
  SetMenuExitBackButton(entityQualityMenu, true);
  
  //Nametag
  nametagMenu = new Menu(NametagMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DrawItem);
  SetMenuTitle(nametagMenu, "Apply Nametag:");
  AddMenuItem(nametagMenu, "removenametag", "Remove Nametag");
  AddMenuItem(nametagMenu, "setnametagtext", "Set Nametag Text");
  AddMenuItem(nametagMenu, "selectcolour", "Select Nametag Colour");
  AddMenuItem(nametagMenu, "selectfontsize", "Select Nametag Font Size");
  SetMenuExitBackButton(nametagMenu, true);
  
  //Nametag Colour
  nametagColourMenu = new Menu(NametagColourMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(nametagColourMenu, "Select Nametag Colour:");
  AddMenuItem(nametagColourMenu, "", "Default (White)");
  AddMenuItem(nametagColourMenu, "#ED0A3F", "Red");
  AddMenuItem(nametagColourMenu, "#FF861F", "Orange");
  AddMenuItem(nametagColourMenu, "#FBE870", "Yellow");
  AddMenuItem(nametagColourMenu, "#C5E17A", "Lime");
  AddMenuItem(nametagColourMenu, "#01A368", "Green");
  AddMenuItem(nametagColourMenu, "#76D7EA", "Sky Blue");
  AddMenuItem(nametagColourMenu, "#0066FF", "Blue");
  AddMenuItem(nametagColourMenu, "#F660AB", "Pink");
  AddMenuItem(nametagColourMenu, "#8359A3", "Purple");
  AddMenuItem(nametagColourMenu, "#AF593E", "Brown");
  AddMenuItem(nametagColourMenu, "#B6B6B4", "Grey");
  AddMenuItem(nametagColourMenu, "#000000", "Black");
  
  SetMenuExitBackButton(nametagColourMenu, true);
  
  //Nametag Font Size
  nametagFontSizeMenu = new Menu(NametagFontSizeMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem|MenuAction_DrawItem);
  SetMenuTitle(nametagFontSizeMenu, "Select Nametag Font Size:");
  AddMenuItem(nametagFontSizeMenu, "-1", "Default");
  AddMenuItem(nametagFontSizeMenu, "10", "Very Small");
  AddMenuItem(nametagFontSizeMenu, "13", "Small");
  AddMenuItem(nametagFontSizeMenu, "15", "Medium");
  AddMenuItem(nametagFontSizeMenu, "18", "Large");
  AddMenuItem(nametagFontSizeMenu, "20", "Very Large");
  SetMenuExitBackButton(nametagFontSizeMenu, true);
  
  //Preset Menu
  presetManagerMenu = new Menu(PresetManagerMenuHandler);
  SetMenuTitle(presetManagerMenu, "Preset Manager:");
  AddMenuItem(presetManagerMenu, "save", "Save Preset");
  AddMenuItem(presetManagerMenu, "load", "Load Preset");
  AddMenuItem(presetManagerMenu, "reset", "Reset Preset");
  AddMenuItem(presetManagerMenu, "printinfo", "Print Preset Info");
  AddMenuItem(presetManagerMenu, "resetweapon", "Reset Weapon");
  SetMenuExitBackButton(presetManagerMenu, true);
  
  //Slot Selection Menu
  slotSelectMenu = new Menu(SlotSelectMenuHandler, MenuAction_Select|MenuAction_Cancel|MenuAction_End|MenuAction_DisplayItem);
  SetMenuTitle(slotSelectMenu, "Select a Slot:");
  
  //Start index at 1
  for (int i = 1; i <= NUM_PRESETS; ++i) {
    char presetItem[16];
    char presetname[16];
    Format(presetItem, sizeof(presetItem), "SLOT %i", i);
    Format(presetname, sizeof(presetname), "preset_%i", i);
    AddMenuItem(slotSelectMenu, presetname, presetItem);
  }
  
  SetMenuExitBackButton(slotSelectMenu, true);
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DrawItem) {
    if (itemNum > 0) { //First option allowed
      //Check for unsupported active item
      if (g_selectedWeaponIndex[client] == -1) {
        int wlIndex = GetTargetedWeaponListIndex(client, (itemNum == 1)); //print error message once
        if (wlIndex == -1)
          return ITEMDRAW_DISABLED;
      }
    }
  }
  else if (action == MenuAction_DisplayItem) {
    //Kind of hacky, reset the menu title only if its first item of each page
    //This is so we only 'refresh' the title once per menu page
    if (itemNum % MAX_MENU_OPTIONS == 0) {
      char selectWeaponText[64];
      char currentWeapon[64];
      if (g_selectedWeaponIndex[client] == -1)
        Format(currentWeapon, sizeof(currentWeapon), "Active Weapon");
      else
        Format(currentWeapon, sizeof(currentWeapon), weaponListNiceNames[g_selectedWeaponIndex[client]]);
      
      Format(selectWeaponText, sizeof(selectWeaponText), "Targetting: %s", currentWeapon);
      SetMenuTitle(menu, "Rems Weapons (RW) V%s\n \n%s", VERSION, selectWeaponText);
    }
  }
  else if (action == MenuAction_Select) {
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    if (StrEqual(info, "selectweapon")) {
      DisplayMenu(gunSelectMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "selectskin")) {
      DisplayMenu(skinMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "selectwear")) {
      DisplayMenu(wearMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "selectseed")) {
      DisplayMenu(seedMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "customizeweapontype")) {
      DisplayMenu(weaponTypeMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "applynametag")) {
      DisplayMenu(nametagMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "presetmanager")) {
      DisplayMenu(presetManagerMenu, client, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int GunSelectMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DrawItem) {
    if (itemNum == 0 && !IsPlayerAlive(client))
      return ITEMDRAW_DISABLED;
    
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    int selectedGunNum = StringToInt(info);
    
    if (g_selectedWeaponIndex[client] == selectedGunNum) {
      return ITEMDRAW_DISABLED;
    } else {
      return ITEMDRAW_DEFAULT;
    }
  }
  else if (action == MenuAction_DisplayItem) {
    char info[64];
    int temp;
    char display[64];
    GetMenuItem(menu, itemNum, info, sizeof(info), temp, display, sizeof(display));
    int selectedGunNum = StringToInt(info);
    
    if (g_selectedWeaponIndex[client] == selectedGunNum) {
      char equipedText[64];
      Format(equipedText, sizeof(equipedText), "%s [*]", display);
      return RedrawMenuItem(equipedText);
    }
  }
  else if (action == MenuAction_Select) {
    
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
   
    //Select weapon to target
    g_selectedWeaponIndex[client] = StringToInt(info);
    
    int wlIndex = GetTargetedWeaponListIndex(client, false);
    
    if (wlIndex != -1) {
      char weaponName[64];
      Format(weaponName, sizeof(weaponName), weaponListNiceNames[wlIndex]);
      if (g_selectedWeaponIndex[client] == -1)
        Format(weaponName, sizeof(weaponName), "Active Weapon");
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Weapon Selected", weaponName);
    }

    DisplayMenuAtItem(mainMenu[client], client, 0, MENU_TIME_FOREVER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(mainMenu[client], client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int SkinMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DrawItem) {
    if (itemNum > 1) { //ignore first 2 options
      int wlIndex = GetTargetedWeaponListIndex(client);
      char info[64];
      GetMenuItem(menu, itemNum, info, sizeof(info));
      int selectedPaintNum = StringToInt(info);
      
      if (wlIndex != -1 && g_rwPreferences[client][wlIndex][paint] == selectedPaintNum) {
        return ITEMDRAW_DISABLED;
      } else {
        return ITEMDRAW_DEFAULT;
      }
    }
  }
  else if (action == MenuAction_DisplayItem) {
    if (itemNum % MAX_MENU_OPTIONS == 0) {
      //Set the menu title in here
      int wlIndex = GetTargetedWeaponListIndex(client);
      if (wlIndex != -1) {
        SetMenuTitle(menu, "Select Skin\nCurrently: %s", g_paints[g_rwPreferences[client][wlIndex][paint]][paintName]);
      }
      else {
        SetMenuTitle(menu, "Select Skin:");
      }
    }
    else if (itemNum > 1) { //ignore first 2 options
      int wlIndex = GetTargetedWeaponListIndex(client);
      char info[64];
      GetMenuItem(menu, itemNum, info, sizeof(info));
      int selectedPaintNum = StringToInt(info);
      
      if (wlIndex != -1 && g_rwPreferences[client][wlIndex][paint] == selectedPaintNum) {
        char equipedText[64];
        Format(equipedText, sizeof(equipedText), "%s [*]", g_paints[selectedPaintNum][paintName]);
        return RedrawMenuItem(equipedText);
      }
    }
  }
  else if (action == MenuAction_Select) {
    //Ensure valid target exists
    int wlIndex = GetTargetedWeaponListIndex(client, true);
    if (wlIndex == -1) {
      DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
      return 0;
    }

    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    if (StrEqual(info, "search")) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Enter Chat", "skin name");
      g_iWaitingForSayInput[client] = INPUT_PAINT;
      return 0;
    }
    
    int newPaint = StringToInt(info);
    
    if(newPaint == -1)  //randomised index if needed
      newPaint = GetRandomInt(1, g_paintCount - 1);
    
    StorePreferenceValue(client, INPUT_PAINT, newPaint);
    PrintSkinSelectionMessage(client, wlIndex);
    
    DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(mainMenu[client], client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int WearMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DrawItem) {
    if (itemNum > 0) { //ignore first option
      int wlIndex = GetTargetedWeaponListIndex(client);
      char info[64];
      int temp;
      char display[64];
      GetMenuItem(menu, itemNum, info, sizeof(info), temp, display, sizeof(display));
      float selectedWear = StringToFloat(info);
      
      if (wlIndex != -1 && FloatAbs(g_rwPreferences[client][wlIndex][wear] - selectedWear) <= FLOAT_COMPARE_EPSILON) {
        return ITEMDRAW_DISABLED;
      } else {
        return ITEMDRAW_DEFAULT;
      }
    }
  }
  else if (action == MenuAction_DisplayItem) {
    if (itemNum % MAX_MENU_OPTIONS == 0) {
      //Set the menu title in here
      int wlIndex = GetTargetedWeaponListIndex(client);
      if (wlIndex != -1) {
        SetMenuTitle(menu, "Select Wear\nCurrently: %f", g_rwPreferences[client][wlIndex][wear]);
      }
      else {
        SetMenuTitle(menu, "Select Wear:");
      }
    }
    else { //ignore first option
      int wlIndex = GetTargetedWeaponListIndex(client);
      char info[64];
      int temp;
      char display[64];
      GetMenuItem(menu, itemNum, info, sizeof(info), temp, display, sizeof(display));
      float selectedWear = StringToFloat(info);
      
      if (wlIndex != -1 && FloatAbs(g_rwPreferences[client][wlIndex][wear] - selectedWear) <= FLOAT_COMPARE_EPSILON) {
        char equipedText[64];
        Format(equipedText, sizeof(equipedText), "%s [*]", display);
        return RedrawMenuItem(equipedText);
      }
    }
  }
  else if (action == MenuAction_Select) {
    //Ensure valid target exists
    int wlIndex = GetTargetedWeaponListIndex(client, true);
    if (wlIndex == -1) {
      DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
      return 0;
    }
    
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    float newWear = DEFAULT_WEAR;
    if (StrEqual(info, "custom")) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Enter Chat", "wear value");
      g_iWaitingForSayInput[client] = INPUT_WEAR;
      return 0;
    }
    else {
      newWear = StringToFloat(info);
    }
    
    StorePreferenceValue(client, INPUT_WEAR, newWear);
    char newWearString[64];
    FloatToString(newWear, newWearString, sizeof(newWearString));
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Value Updated", "wear", weaponListNiceNames[wlIndex], newWearString);
    
    DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(mainMenu[client], client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

//Returns the targeted weapon list index or -1 if invalid state
//Invalid state includes targetting active weapon while dead
int GetTargetedWeaponListIndex(int client, bool printErrorMessages = false)
{
  int wlIndex = 0;
  if (!IsClientInGame(client))
    wlIndex = -1;
    
  if (!IsPlayerAlive(client) && g_selectedWeaponIndex[client] == -1) {
    //Can't target active weapon while dead
    wlIndex = -1;
  }
  
  //Select skin to use if we haven't hit an error already
  if (wlIndex != -1) {
    if (g_selectedWeaponIndex[client] == -1)
      wlIndex = GetActiveWeaponListIndex(client);
    else
      wlIndex = g_selectedWeaponIndex[client];
  }
  
  //Print error message if bool set
  if (printErrorMessages && wlIndex == -1)
    PrintBadWeaponTargetMessage(client);
  
  return wlIndex;
}

//Set a preference in the global array for a client
void StorePreferenceValue(int client, int mode, any newValue = -1, const char[] newStringValue = "", bool saveDatabasePreferences = true, bool autoReloadWeapon = true)
{
  if (mode == INPUT_NONE)
    return;
  
  int wlIndex = GetTargetedWeaponListIndex(client, false);
  if (wlIndex == -1)
    return;
    
  //Set preference
  if (mode == INPUT_PAINT)
    g_rwPreferences[client][wlIndex][paint] = newValue;
  else if (mode == INPUT_WEAR)
    g_rwPreferences[client][wlIndex][wear] = newValue;
  else if (mode == INPUT_SEED)
    g_rwPreferences[client][wlIndex][seed] = newValue;
  else if (mode == INPUT_STATTRAK)
    g_rwPreferences[client][wlIndex][stattrak] = newValue;
  else if (mode == INPUT_STATTRAKLOCK)
    g_rwPreferences[client][wlIndex][stattrakLock] = view_as<bool>(newValue);
  else if (mode == INPUT_ENTITYQUALITY) {
    g_rwPreferences[client][wlIndex][entityQuality] = newValue;
    g_rwPreferences[client][wlIndex][stattrak] = -1; //not compatible with stattrak mode
  }
  else if (mode == INPUT_NAMETAGTEXT)
    Format(g_rwPreferences[client][wlIndex][nametagText], 255, newStringValue);
  else if (mode == INPUT_NAMETAGCOLOUR)
    Format(g_rwPreferences[client][wlIndex][nametagColourCode], 10, newStringValue);
  else if (mode == INPUT_NAMETAGFONTSIZE)
    g_rwPreferences[client][wlIndex][nametagFontSize] = newValue;
  else
    return;
  
  //Save settings to database
  if (saveDatabasePreferences)
    UpdateStoredDatabasePreferences(client, wlIndex);
  
  if (autoReloadWeapon)
    SwitchToThenReloadWeapon(client, wlIndex);
}

public int SeedMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DisplayItem) {
    if (itemNum % MAX_MENU_OPTIONS == 0) {
      //Set the menu title in here
      int wlIndex = GetTargetedWeaponListIndex(client);
      if (wlIndex != -1) {
        SetMenuTitle(menu, "Select Seed\nCurrently: %d", g_rwPreferences[client][wlIndex][seed]);
      }
      else {
        SetMenuTitle(menu, "Select Seed:");
      }
    }
  }
  else if (action == MenuAction_Select) {
    //Ensure valid target exists
    int wlIndex = GetTargetedWeaponListIndex(client, true);
    if (wlIndex == -1) {
      DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
      return 0;
    }

    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    int newSeed = g_rwPreferences[client][wlIndex][seed];
    
    if (StrEqual(info, "custom")) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Enter Chat", "seed value");
      g_iWaitingForSayInput[client] = INPUT_SEED;
      return 0;
    }
    else if (StrEqual(info, "-1")) {
      newSeed = GetRandomInt(0, 2147483647);
    }
    else if (StrEqual(info, "0")) {
      newSeed = 0;
    }
    else if (StrEqual(info, "next")) {
      ++newSeed;
      if (newSeed < 0) //handle overflow
        newSeed = 0;
    }
    else if (StrEqual(info, "prev")) {
      --newSeed;
      if (newSeed < 0) //handle underflow
        newSeed = 2147483647;
    }
    
    StorePreferenceValue(client, INPUT_SEED, newSeed);
    char newSeedString[64];
    IntToString(newSeed, newSeedString, sizeof(newSeedString));
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Value Updated", "pattern seed", weaponListNiceNames[wlIndex], newSeedString);
    
    DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(mainMenu[client], client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int WeaponTypeMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_Select) {
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    if (StrEqual(info, "stattrak")) {
      DisplayMenu(stattrakMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "entityQuality")) {
      DisplayMenu(entityQualityMenu, client, MENU_TIME_FOREVER);
    }
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(mainMenu[client], client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int StattrakMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DisplayItem) {
    int wlIndex = GetTargetedWeaponListIndex(client);
    
    if (itemNum == 0) {
      char toggleStattrakText[64];
      if (g_selectedWeaponIndex[client] == -1 && wlIndex == -1) {
        Format(toggleStattrakText, sizeof(toggleStattrakText), "Toggle StatTrak™");
      } else {
        Format(toggleStattrakText, sizeof(toggleStattrakText), "Toggle StatTrak™ (%s)", (g_rwPreferences[client][wlIndex][stattrak] == -1) ? "OFF" : "ON");
      }
      return RedrawMenuItem(toggleStattrakText);
    }
    else if (itemNum == 2) {
      char toggleStattrakLockText[64];
      if (g_selectedWeaponIndex[client] == -1 && wlIndex == -1) {
        Format(toggleStattrakLockText, sizeof(toggleStattrakLockText), "Toggle Kill Counter Lock");
      } else {
        Format(toggleStattrakLockText, sizeof(toggleStattrakLockText), "Toggle Kill Counter Lock (%s)", (g_rwPreferences[client][wlIndex][stattrakLock]) ? "ON" : "OFF");
      }
      return RedrawMenuItem(toggleStattrakLockText);
    }
  }
  else if (action == MenuAction_Select) {
    //Ensure valid target exists
    int wlIndex = GetTargetedWeaponListIndex(client, true);
    if (wlIndex == -1) {
      DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
      return 0;
    }
    
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    if (StrEqual(info, "toggle")) {
      int newStattrak = g_rwPreferences[client][wlIndex][stattrak];
      if (newStattrak == -1)
        newStattrak = 0;
      else
        newStattrak = -1;
     
      StorePreferenceValue(client, INPUT_STATTRAK, newStattrak);
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Stattrak Toggled", (newStattrak == -1) ? "OFF" : "ON", weaponListNiceNames[wlIndex]);
    }
    else if (StrEqual(info, "setkills")) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Enter Chat", "StatTrak™ kill count value");
      g_iWaitingForSayInput[client] = INPUT_STATTRAK;
      return 0;
    }
    else if (StrEqual(info, "togglelock")) {
      bool newStattrakLockToggle = g_rwPreferences[client][wlIndex][stattrakLock];
      newStattrakLockToggle = !newStattrakLockToggle;
      StorePreferenceValue(client, INPUT_STATTRAKLOCK, view_as<int>(newStattrakLockToggle), _, _, false);
      if (newStattrakLockToggle)
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Stattrak Lock Toggled On", weaponListNiceNames[wlIndex]);
      else
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Stattrak Lock Toggled Off", weaponListNiceNames[wlIndex]);
    }
    
    DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(weaponTypeMenu, client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int EntityQualityMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DrawItem) {
    int wlIndex = GetTargetedWeaponListIndex(client);
    char info[64];
    int temp;
    char display[64];
    GetMenuItem(menu, itemNum, info, sizeof(info), temp, display, sizeof(display));
    int selectedEntityQuality = StringToInt(info);
    
    if (wlIndex != -1 && g_rwPreferences[client][wlIndex][entityQuality] == selectedEntityQuality) {
      return ITEMDRAW_DISABLED;
    } else {
      return ITEMDRAW_DEFAULT;
    }
  }
  else if (action == MenuAction_DisplayItem) {
    int wlIndex = GetTargetedWeaponListIndex(client);
    char info[64];
    int temp;
    char display[64];
    GetMenuItem(menu, itemNum, info, sizeof(info), temp, display, sizeof(display));
    int selectedEntityQuality = StringToInt(info);
    
    if (wlIndex != -1 && g_rwPreferences[client][wlIndex][entityQuality] == selectedEntityQuality) {
      char equipedText[64];
      Format(equipedText, sizeof(equipedText), "%s [*]", display);
      return RedrawMenuItem(equipedText);
    }
  }
  else if (action == MenuAction_Select) {
    //Ensure valid target exists
    int wlIndex = GetTargetedWeaponListIndex(client, true);
    if (wlIndex == -1) {
      DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
      return 0;
    }
    
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    int newEntityQuality = StringToInt(info);
    char buffer[64];
    StorePreferenceValue(client, INPUT_ENTITYQUALITY, newEntityQuality);
    EntityQualityToString(newEntityQuality, buffer, sizeof(buffer));
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Value Updated", "weapon type", weaponListNiceNames[wlIndex], buffer);
    
    DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(weaponTypeMenu, client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int NametagMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DrawItem) {
    //Can't remove nametag if one hasn't been set
    if (itemNum == 0) {
      int wlIndex = GetTargetedWeaponListIndex(client);
      if (wlIndex != -1 && StrEqual(g_rwPreferences[client][wlIndex][nametagText], DEFAULT_NAMETAGTEXT)) {
        return ITEMDRAW_DISABLED;
      }
    }
  }
  else if (action == MenuAction_Select) {
    //Ensure valid target exists
    int wlIndex = GetTargetedWeaponListIndex(client, true);
    if (wlIndex == -1) {
      DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
      return 0;
    }

    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    if (StrEqual(info, "removenametag")) {
      StorePreferenceValue(client, INPUT_NAMETAGTEXT, _, "");
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Nametag Removed", weaponListNiceNames[wlIndex]);
      DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "setnametagtext")) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Enter Chat", "nametag name");
      g_iWaitingForSayInput[client] = INPUT_NAMETAGTEXT;
      return 0;
    }
    else if (StrEqual(info, "selectcolour")) {
      DisplayMenu(nametagColourMenu, client, MENU_TIME_FOREVER);
    }
    else if (StrEqual(info, "selectfontsize")) {
      DisplayMenu(nametagFontSizeMenu, client, MENU_TIME_FOREVER);
    }
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(mainMenu[client], client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int NametagColourMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DrawItem) {
    int wlIndex = GetTargetedWeaponListIndex(client);
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    if (wlIndex != -1 && StrEqual(g_rwPreferences[client][wlIndex][nametagColourCode], info)) {
      return ITEMDRAW_DISABLED;
    } else {
      return ITEMDRAW_DEFAULT;
    }
  }
  else if (action == MenuAction_DisplayItem) {
    int wlIndex = GetTargetedWeaponListIndex(client);
    char info[64];
    int temp;
    char display[64];
    GetMenuItem(menu, itemNum, info, sizeof(info), temp, display, sizeof(display));
    
    if (wlIndex != -1 && StrEqual(g_rwPreferences[client][wlIndex][nametagColourCode], info)) {
      char equipedText[64];
      Format(equipedText, sizeof(equipedText), "%s [*]", display);
      return RedrawMenuItem(equipedText);
    }
  }
  else if (action == MenuAction_Select) {
    //Ensure valid target exists
    int wlIndex = GetTargetedWeaponListIndex(client, true);
    if (wlIndex == -1) {
      DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
      return 0;
    }

    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    char buffer[64];
    StorePreferenceValue(client, INPUT_NAMETAGCOLOUR, _, info);
    ColourToString(info, buffer, sizeof(buffer));
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Value Updated", "nametag colour", weaponListNiceNames[wlIndex], buffer);
    
    DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(nametagMenu, client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int NametagFontSizeMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DrawItem) {
    int wlIndex = GetTargetedWeaponListIndex(client);
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    int selectedFontSize = StringToInt(info);
    
    if (wlIndex != -1 && g_rwPreferences[client][wlIndex][nametagFontSize] == selectedFontSize) {
      return ITEMDRAW_DISABLED;
    } else {
      return ITEMDRAW_DEFAULT;
    }
  }
  else if (action == MenuAction_DisplayItem) {
    int wlIndex = GetTargetedWeaponListIndex(client);
    char info[64];
    int temp;
    char display[64];
    GetMenuItem(menu, itemNum, info, sizeof(info), temp, display, sizeof(display));
    int selectedFontSize = StringToInt(info);
    
    if (wlIndex != -1 && g_rwPreferences[client][wlIndex][nametagFontSize] == selectedFontSize) {
      char equipedText[64];
      Format(equipedText, sizeof(equipedText), "%s [*]", display);
      return RedrawMenuItem(equipedText);
    }
  }
  else if (action == MenuAction_Select) {
    //Ensure valid target exists
    int wlIndex = GetTargetedWeaponListIndex(client, true);
    if (wlIndex == -1) {
      DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
      return 0;
    }

    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    char buffer[64];
    StorePreferenceValue(client, INPUT_NAMETAGFONTSIZE, StringToInt(info));
    NametagFontSizeToString(StringToInt(info), buffer, sizeof(buffer));
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Generic Value Updated", "nametag font size", weaponListNiceNames[wlIndex], buffer);
  
    DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(nametagMenu, client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int PresetManagerMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_Select) {
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    if (StrEqual(info, "save")) {
      g_presetAction[client] = PRESET_ACTION_SAVE;
      DisplayMenu(slotSelectMenu, client, MENU_TIME_FOREVER);
      return 0;
    }
    else if (StrEqual(info, "load")) {
      g_presetAction[client] = PRESET_ACTION_LOAD;
      DisplayMenu(slotSelectMenu, client, MENU_TIME_FOREVER);
      return 0;
    }
    else if (StrEqual(info, "reset")) {
      g_presetAction[client] = PRESET_ACTION_RESET;
      DisplayMenu(slotSelectMenu, client, MENU_TIME_FOREVER);
      return 0;
    }
    else if (StrEqual(info, "printinfo")) {
      g_presetAction[client] = PRESET_ACTION_PRINTINFO;
      DisplayMenu(slotSelectMenu, client, MENU_TIME_FOREVER);
      return 0;
    }
    else if (StrEqual(info, "resetweapon")) {
      int wlIndex = GetTargetedWeaponListIndex(client, true);
      if (wlIndex != -1) {
        //Clear then save to database
        ClearLocalPreferencesForWlIndex(client, wlIndex);
        UpdateStoredDatabasePreferences(client, wlIndex);
        SwitchToThenReloadWeapon(client, wlIndex);
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Weapon Preferences Reset", weaponListNiceNames[wlIndex]);
      }
    }
    
    DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(mainMenu[client], client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

public int SlotSelectMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
  if (action == MenuAction_DisplayItem) {
    char info[64];
    int temp;
    char display[64];
    GetMenuItem(menu, itemNum, info, sizeof(info), temp, display, sizeof(display));
    int wlIndex = GetWeaponListIndex(info);
    
    if (wlIndex != -1 && IsDefaultPreferencesForWlIndex(client, wlIndex)) {
      char unusedText[64];
      Format(unusedText, sizeof(unusedText), "%s (unused)", display);
      return RedrawMenuItem(unusedText);
    }
  }
  else if (action == MenuAction_Select) {
    char info[64];
    GetMenuItem(menu, itemNum, info, sizeof(info));
    
    //Get presets wlindex
    int presetWlIndex = GetWeaponListIndex(info);
    if (presetWlIndex != -1) {
      //Now determine what action to perform
      switch (g_presetAction[client]) {
        case PRESET_ACTION_SAVE:
        {
          int wlIndex = GetTargetedWeaponListIndex(client, true);
          if (wlIndex != -1) {
            //Copy settings from targetted weapon to preset
            CopyLocalPreferences(client, wlIndex, presetWlIndex);
            UpdateStoredDatabasePreferences(client, presetWlIndex);
            CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Preset Save", weaponListNiceNames[wlIndex], weaponListNiceNames[presetWlIndex]);
          }
        }
        case PRESET_ACTION_LOAD:
        {
          int wlIndex = GetTargetedWeaponListIndex(client, true);
          if (wlIndex != -1) {
            //Copy settings from preset to targetted gun
            CopyLocalPreferences(client, presetWlIndex, wlIndex);
            UpdateStoredDatabasePreferences(client, wlIndex);
            
            //Switch to then reload weapon
            SwitchToThenReloadWeapon(client, wlIndex);
            
            CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Preset Load", weaponListNiceNames[presetWlIndex], weaponListNiceNames[wlIndex]);
          }
        }
        case PRESET_ACTION_RESET:
        {
          //Clear then save to databse
          ClearLocalPreferencesForWlIndex(client, presetWlIndex);
          UpdateStoredDatabasePreferences(client, presetWlIndex);
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Preset Reset", weaponListNiceNames[presetWlIndex]);
        }
        case PRESET_ACTION_PRINTINFO:
        {
          char buffer[1024];
          PrintToConsole(client, "");
          PrintToConsole(client, "");
          PrintToConsole(client, "[Rems Weapons (RW) V%s]", VERSION);
          PrintToConsole(client, "");
          PrintToConsole(client, "%-35s %-25s", "Field", "Value");
          PrintToConsole(client, "-------------------------------------------");
          PrintToConsole(client, "%-35s %-25s", "Slot", weaponListNiceNames[presetWlIndex]);
          PrintToConsole(client, "%-35s %-25d", "Skin ID", g_rwPreferences[client][presetWlIndex][paint]);
          PrintToConsole(client, "%-35s %-25s", "Skin Name", g_paints[g_rwPreferences[client][presetWlIndex][paint]][paintName]);
          PrintToConsole(client, "%-35s %-25f", "Wear", g_rwPreferences[client][presetWlIndex][wear]);
          PrintToConsole(client, "%-35s %-25d", "Seed", g_rwPreferences[client][presetWlIndex][seed]);
          PrintToConsole(client, "%-35s %-25s", "StatTrak", (g_rwPreferences[client][presetWlIndex][stattrak] == -1) ? "OFF" : "ON");
          
          IntToString(g_rwPreferences[client][presetWlIndex][stattrak], buffer, sizeof(buffer));
          PrintToConsole(client, "%-35s %-25s", "StatTrak Kills", (g_rwPreferences[client][presetWlIndex][stattrak] == -1) ? "N/A" : buffer);
          
          PrintToConsole(client, "%-35s %-25s", "StatTrak Kill Counter Lock", (g_rwPreferences[client][presetWlIndex][stattrakLock]) ? "ON" : "OFF");
          
          EntityQualityToString(g_rwPreferences[client][presetWlIndex][entityQuality], buffer, sizeof(buffer));
          PrintToConsole(client, "%-35s %-25s", "Weapon Type", buffer);
          
          Format(buffer, sizeof(buffer), g_rwPreferences[client][presetWlIndex][nametagText]);
          PrintToConsole(client, "%-35s %-25s", "Nametag Text", strlen(g_rwPreferences[client][presetWlIndex][nametagText]) == 0 ? "(empty)" : buffer);
          
          ColourToString(g_rwPreferences[client][presetWlIndex][nametagColourCode], buffer, sizeof(buffer));
          PrintToConsole(client, "%-35s %-25s", "Nametag Colour", buffer);
          
          NametagFontSizeToString(g_rwPreferences[client][presetWlIndex][nametagFontSize], buffer, sizeof(buffer));
          PrintToConsole(client, "%-35s %-25s", "Nametag Font Size", buffer);

          PrintToConsole(client, "");
          PrintToConsole(client, "");
          
          //Alert user
          CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Preset Print Info", weaponListNiceNames[presetWlIndex]);
        }
      }
    }
    
    DisplayMenuAtItem(menu, client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
  }
  else if (action == MenuAction_Cancel)
  {
    if (itemNum == MenuCancel_ExitBack) {
      DisplayMenuAtItem(presetManagerMenu, client, 0, MENU_TIME_FOREVER);
    }
  }
  
  return 0;
}

//Switches to target weapon before calling ReloadWeapon
void SwitchToThenReloadWeapon(int client, int wlIndex)
{
  if (!IsClientInGame(client) || !IsPlayerAlive(client))
    return;
    
  //Switch to the weapon
  SwitchToWeapon(client, wlIndex);
  
  int newActiveItem = GetActiveWeaponListIndex(client);
  if (newActiveItem == wlIndex) //we just set preferences for this gun
    ReloadWeapon(client);
}

//Switches client to given weapon
void SwitchToWeaponClassname(int client, char[] classname)
{
  if (!IsClientInGame(client) || !IsPlayerAlive(client))
    return;
    
  char weaponName[64];
  bool isKnife = IsKnife(classname);
  if (isKnife)
    Format(weaponName, sizeof(weaponName), "weapon_knife");
  else
    Format(weaponName, sizeof(weaponName), classname);
  
  //Handle special cases
  if (StrEqual(weaponName, "weapon_usp_silencer"))
    Format(weaponName, sizeof(weaponName), "weapon_hkp2000");
  else if (StrEqual(weaponName, "weapon_m4a1_silencer"))
    Format(weaponName, sizeof(weaponName), "weapon_m4a1");
  else if (StrEqual(weaponName, "weapon_cz75a"))
    Format(weaponName, sizeof(weaponName), "weapon_p250");
  else if (StrEqual(weaponName, "weapon_revolver"))
    Format(weaponName, sizeof(weaponName), "weapon_deagle");
    
  FakeClientCommand(client, "use %s", weaponName);
}

//Switches client to given weapon
void SwitchToWeapon(int client, int wlIndex)
{
  if (wlIndex != -1)
    SwitchToWeaponClassname(client, weaponList[wlIndex]);
}

//Reload a players active weapon to apply new settings
//Also conducts various checks to ensure player is eligble to apply skin at this moment
void ReloadWeapon(int client)
{
  if (!IsClientInGame(client) || !IsPlayerAlive(client))
    return;
  
  if (!g_PreferencesLoaded[client])
    return;
    
  //Antiflood checks
  if (GetConVarBool(cvar_antiflood_enable)) {
    if (!g_canUse[client]) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Anti Flood Message");
      return;
    }
  }

  //Hosties
  if(g_hosties && IsClientInLastRequest(client)) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "In LastRequest");
    return;
  }

  int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

  if (weapon < 1 || !IsValidEdict(weapon) || !IsValidEntity(weapon))
    return;
  
  char Classname[64];
  int weaponItemDefinitionIndex = GetProperClassname(client, weapon, Classname);
  
  if (weaponItemDefinitionIndex == -1)
    return;
  
  //Find index
  int wlIndex = GetWeaponListIndex(Classname);
  if (wlIndex == -1)
    return;
  
  GivePlayerRWItem(client, weapon, Classname, g_rwPreferences[client][wlIndex][paint], g_rwPreferences[client][wlIndex][wear], g_rwPreferences[client][wlIndex][seed], g_rwPreferences[client][wlIndex][stattrak], g_rwPreferences[client][wlIndex][entityQuality], g_rwPreferences[client][wlIndex][nametagText], g_rwPreferences[client][wlIndex][nametagColourCode], g_rwPreferences[client][wlIndex][nametagFontSize]);
  
  //Switch to weapon that we just have to player
  SwitchToWeapon(client, wlIndex);
  
  //Set anti flood timer
  if (GetConVarBool(cvar_antiflood_enable)) {
    g_canUse[client] = false;
    CreateTimer(GetConVarFloat(cvar_antiflood_duration), Timer_ReallowUse, client);
  }
}

//Reallow usage of plugin
public Action Timer_ReallowUse(Handle timer, int client)
{
  g_canUse[client] = true;
}

stock int GetReserveAmmo(int client, int weapon)
{
  int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
  if (ammotype == -1) return -1;
  
  return GetEntProp(client, Prop_Send, "m_iAmmo", _, ammotype);
}

stock void SetReserveAmmo(int client, int weaponEntity, int ammo, int primaryReserve)
{
  int ammotype = GetEntProp(weaponEntity, Prop_Send, "m_iPrimaryAmmoType");
  if (ammotype == -1) return;
  
  SetEntProp(weaponEntity, Prop_Send, "m_iPrimaryReserveAmmoCount", primaryReserve); 
  SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammotype);
}

//Function that perfoms actual paint change for weapon entity
void GivePlayerRWItem(int client, int weaponEntity, char[] weaponClassname, int inputPaint, float inputWear, int inputSeed, int inputStattrak, int inputEntityQuality, char[] inputNametagText, char[] inputNametagColourCode, int inputNametagFontSize)
{
  //Detect knives
  bool knife = IsKnife(weaponClassname);
  
  //Preserve primary clip + reserve ammo for weapons so they can be restored later
  int ammo, clip, primaryReserve;
  
  if (!knife) {
    ammo = GetReserveAmmo(client, weaponEntity);
    clip = GetEntProp(weaponEntity, Prop_Send, "m_iClip1");
    primaryReserve = GetEntProp(weaponEntity, Prop_Send, "m_iPrimaryReserveAmmoCount");
  }
  
  //Remove current weapon
  SafeRemoveWeapon(client, weaponEntity);
  
  //Give player new weapon
  int newWeaponEntity = GivePlayerItem(client, weaponClassname);
  if (newWeaponEntity == -1)
    return;
  
  if (!knife) {
    //Set ammo to correct ammount
    SetReserveAmmo(client, newWeaponEntity, ammo, primaryReserve);
    SetEntProp(newWeaponEntity, Prop_Send, "m_iClip1", clip);
  }
  
  //When m_iItemIDHigh SET to a non-zero value, fallback values will be used.
  SetEntProp(newWeaponEntity, Prop_Send, "m_iItemIDHigh", -1);
  
  //Set skin
  SetEntProp(newWeaponEntity, Prop_Send, "m_nFallbackPaintKit", g_paints[inputPaint][paintNum]);
  
  //Set wear
  SetEntPropFloat(newWeaponEntity, Prop_Send, "m_flFallbackWear", inputWear);
  
  //Set seed
  SetEntProp(newWeaponEntity, Prop_Send, "m_nFallbackSeed", inputSeed);
  
  //Set Entity Quality
  SetEntProp(newWeaponEntity, Prop_Send, "m_iEntityQuality", inputEntityQuality);
  
  //Set stattrak
  SetEntProp(newWeaponEntity, Prop_Send, "m_nFallbackStatTrak", inputStattrak);
  if (inputStattrak != -1)
    SetEntProp(newWeaponEntity, Prop_Send, "m_iEntityQuality", 9);
  
  //Auto star knives if entity quality is normal
  if (knife && inputEntityQuality == 0)
    SetEntProp(newWeaponEntity, Prop_Send, "m_iEntityQuality", 3); //3 is for the star
  
  //Set name tag here
  if (strlen(inputNametagText) != 0) {
    char nametagString[255];
    char nametagFontSizeString[4];
    
    IntToString(inputNametagFontSize, nametagFontSizeString, sizeof(nametagFontSizeString));
    
    if (inputNametagFontSize == DEFAULT_NAMETAGFONTSIZE)
      Format(nametagFontSizeString, sizeof(nametagFontSizeString), "");
    
    Format(nametagString, sizeof(nametagString), "<font color='%s' size='%s'>%s</font>", inputNametagColourCode, nametagFontSizeString, inputNametagText);
    
    //Set nametag
    int iNameOffset = FindSendPropInfo("CEconEntity", "m_szCustomName");
    if (iNameOffset != -1)
      SetEntDataString(newWeaponEntity, iNameOffset, nametagString, MAX_NAMETAG_LENGTH_POSSIBLE, true);
  }
  
  //Set other required net props
  SetEntProp(newWeaponEntity, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
  SetEntPropEnt(newWeaponEntity, Prop_Data, "m_hParent", client);
  SetEntPropEnt(newWeaponEntity, Prop_Data, "m_hOwner", client);
  SetEntPropEnt(newWeaponEntity, Prop_Data, "m_hOwnerEntity", client);
  SetEntProp(newWeaponEntity, Prop_Send, "m_bInitialized", 1);
  
  if (knife) {
    //SERVER CRASH FIX
    //For some reason we have to drop the knife before equiping
    //Or else a crash is caused if weapons are left on the ground
    //And we reach the end of 'round_end' time
    CS_DropWeapon(client, newWeaponEntity, false, true);
    EquipPlayerWeapon(client, newWeaponEntity);
  }
}

//Is classname a knife
bool IsKnife(char[] classname)
{
  if (StrContains(classname, "weapon_knife", false) == 0 || StrContains(classname, "weapon_bayonet", false) == 0)
    return true;
    
  return false;
}

//Helper function, get clients active weapon as index
int GetActiveWeaponListIndex(int client)
{
  int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  
  if (weapon < 1 || !IsValidEdict(weapon) || !IsValidEntity(weapon))
    return -1;
  
  char Classname[64];
  int response = GetProperClassname(client, weapon, Classname);
  
  if (response == -1)
    return -1;
  
  //Find index
  return GetWeaponListIndex(Classname);
}

int GetWeaponListIndex(const char[] classname)
{
  for (int i = 0; i < sizeof(weaponList); ++i) {
    if (StrEqual(weaponList[i], classname))
      return i;
  }
  return -1;
}

//Functions returns the proper completed classname for a given classname
//Disallowed weapons or weapon slots will return -1
//Otherwise, the weaponItemDefinitionIndex is returned on success and the Classname is altered
int GetProperClassname(int client, int weapon, char Classname[64])
{
  if (!GetEdictClassname(weapon, Classname, sizeof(Classname)))
    return -1;
  
  int weaponItemDefinitionIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
  
  //Ignore these weapon indexes
  //31 = Taser - 42 = CT knife default - 59 = T knife default 
  if(weaponItemDefinitionIndex == 31 || weaponItemDefinitionIndex == 42 || weaponItemDefinitionIndex == 59)
    return -1;
  
  if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == weapon || GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) == weapon || GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == weapon || (GetConVarBool(cvar_c4) && GetPlayerWeaponSlot(client, CS_SLOT_C4) == weapon))
  {
    switch (weaponItemDefinitionIndex) {
      case 60: strcopy(Classname, sizeof(Classname), "weapon_m4a1_silencer");
      case 61: strcopy(Classname, sizeof(Classname), "weapon_usp_silencer");
      case 63: strcopy(Classname, sizeof(Classname), "weapon_cz75a");
      case 64: strcopy(Classname, sizeof(Classname), "weapon_revolver");
      case 500: strcopy(Classname, sizeof(Classname), "weapon_bayonet");
      case 506: strcopy(Classname, sizeof(Classname), "weapon_knife_gut");
      case 505: strcopy(Classname, sizeof(Classname), "weapon_knife_flip");
      case 508: strcopy(Classname, sizeof(Classname), "weapon_knife_m9_bayonet");
      case 507: strcopy(Classname, sizeof(Classname), "weapon_knife_karambit");
      case 509: strcopy(Classname, sizeof(Classname), "weapon_knife_tactical");
      case 512: strcopy(Classname, sizeof(Classname), "weapon_knife_falchion");
      case 514: strcopy(Classname, sizeof(Classname), "weapon_knife_survival_bowie");
      case 515: strcopy(Classname, sizeof(Classname), "weapon_knife_butterfly");
      case 516: strcopy(Classname, sizeof(Classname), "weapon_knife_push");
    }
    
    return weaponItemDefinitionIndex;
  }
  else
    return -1;
}

//Search for a skin using a string
//Returns -1 if no skin found
int SearchPaintIndex(const char[] query) {
  
  //Index search
  if (IsStringNumeric(query)) {
    int index = StringToInt(query);
    //Allow -1 (random) and 0 (default) indices
    if (index >= -1 && index < g_paintCount) {
      return index;
    }
  }
  
  //String search
  int partialMatch = -1;
  
  for (int i = 0; i < g_paintCount; ++i) {
    //First find exact matches
    if (StrEqual(g_paints[i][paintName], query, false)) {
      return i;
    }
    //Then try to find partial matches
    if (StrContains(g_paints[i][paintName], query, false) != -1) {
      partialMatch = i;
    }
  }
  
  return partialMatch;
}

//Helper function that tells you if a string is numeric (int or floating point)
bool IsStringNumeric(const char[] s) {
  bool decimalFound = false;
  
  for (int i = 0; i < strlen(s); ++i) {
    if (!IsCharNumeric(s[i]))
      if (s[i] == '.') {
        //Cant have two decimal points
        if (decimalFound)
          return false;
        
        //First and last digits can't be the decimal point
        if (i == 0 || i == strlen(s) - 1)
          return false;
        
        decimalFound = true;
      }
      else if (s[i] == '-') {
        //Negative sign only allowed in first position and if more numbers follow
        if (i != 0 || strlen(s) <= 1)
          return false;
      }
      else
        return false;
  }
  
  return true;
}

void EntityQualityToString(int entityQualityValue, char[] string, int stringLength)
{
  switch (entityQualityValue){
    case 0:
    {
      Format(string, stringLength, "Default (Normal)");
    }
    case 1:
    {
      Format(string, stringLength, "Genuine");
    }
    case 2:
    {
      Format(string, stringLength, "Vintage");
    }
    case 5:
    {
      Format(string, stringLength, "Community");
    }
    case 6:
    {
      Format(string, stringLength, "Developer (Valve)");
    }
    case 7:
    {
      Format(string, stringLength, "Self-Made (Prototype)");
    }
    case 8:
    {
      Format(string, stringLength, "Customized");
    }
    case 10:
    {
      Format(string, stringLength, "Completed");
    }
    case 12:
    {
      Format(string, stringLength, "Souvenir");
    }
    default:
    {
      Format(string, stringLength, "N/A");
    }
  }
}

void ColourToString(const char[] colourCode, char[] string, int stringLength)
{
  if (StrEqual(colourCode, "")) {
    Format(string, stringLength, "Default (White)");
  }
  else if (StrEqual(colourCode, "#ED0A3F")) {
    Format(string, stringLength, "Red");
  }
  else if (StrEqual(colourCode, "#FF861F")) {
    Format(string, stringLength, "Orange");
  }
  else if (StrEqual(colourCode, "#FBE870")) {
    Format(string, stringLength, "Yellow");
  }
  else if (StrEqual(colourCode, "#C5E17A")) {
    Format(string, stringLength, "Lime");
  }
  else if (StrEqual(colourCode, "#01A368")) {
    Format(string, stringLength, "Green");
  }
  else if (StrEqual(colourCode, "#76D7EA")) {
    Format(string, stringLength, "Sky Blue");
  }
  else if (StrEqual(colourCode, "#0066FF")) {
    Format(string, stringLength, "Blue");
  }
  else if (StrEqual(colourCode, "#F660AB")) {
    Format(string, stringLength, "Pink");
  }
  else if (StrEqual(colourCode, "#8359A3")) {
    Format(string, stringLength, "Purple");
  }
  else if (StrEqual(colourCode, "#AF593E")) {
    Format(string, stringLength, "Brown");
  }
  else if (StrEqual(colourCode, "#B6B6B4")) {
    Format(string, stringLength, "Grey");
  }
  else if (StrEqual(colourCode, "#000000")) {
    Format(string, stringLength, "Black");
  }
  else {
    Format(string, stringLength, "Unknown");
  }
}

void NametagFontSizeToString(int fontSizeValue, char[] string, int stringLength)
{
  switch (fontSizeValue){
    case -1:
    {
      Format(string, stringLength, "Default");
    }
    case 10:
    {
      Format(string, stringLength, "Very Small");
    }
    case 13:
    {
      Format(string, stringLength, "Small");
    }
    case 15:
    {
      Format(string, stringLength, "Medium");
    }
    case 18:
    {
      Format(string, stringLength, "Large");
    }
    case 20:
    {
      Format(string, stringLength, "Very Large");
    }
    default:
    {
      Format(string, stringLength, "Unknown");
    }
  }
}

//Print messages
void PrintBadWeaponTargetMessage(int client)
{
  if (IsClientInGame(client)) {
    if (IsPlayerAlive(client)) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Bad Targetted Weapon - Alive");
    } else {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Bad Targetted Weapon - Dead");
    }
  }
}

void PrintSkinSelectionMessage(int client, int wlIndex)
{
  //Print weapon skin changed message based on type of change
  if (g_rwPreferences[client][wlIndex][paint] == 0)
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Skin Selected Default", weaponListNiceNames[wlIndex]);
  else
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Skin Selected Normal", g_paints[g_rwPreferences[client][wlIndex][paint]][paintName], weaponListNiceNames[wlIndex]);
}

//Stock by SM9()
//https://forums.alliedmods.net/showthread.php?t=288614
stock bool SafeRemoveWeapon(int iClient, int iWeapon)
{
  if (!IsValidEntity(iWeapon) || !IsValidEdict(iWeapon)) {
    return false;
  }

  if (!HasEntProp(iWeapon, Prop_Send, "m_hOwnerEntity")) {
    return false;
  }

  int iOwnerEntity = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");

  if (iOwnerEntity != iClient) {
    SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iClient, true);
  }

  CS_DropWeapon(iClient, iWeapon, false);

  if (HasEntProp(iWeapon, Prop_Send, "m_hWeaponWorldModel")) {
    int iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
    
    if (IsValidEdict(iWorldModel) && IsValidEntity(iWorldModel)) {
      if (!AcceptEntityInput(iWorldModel, "Kill")) {
        return false;
      }
    }
  }

  if (!AcceptEntityInput(iWeapon, "Kill")) {
    return false;
  }

  return true;
}

//Natives
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
  MarkNativeAsOptional("IsClientInLastRequest");
  return APLRes_Success;
}

//Detect hosties - add
public void OnLibraryAdded(const char[] name)
{
  if (StrEqual(name, "hosties")) {
    g_hosties = true;
  }
}

//Detect hosties - remove
public void OnLibraryRemoved(const char[] name)
{
  if (StrEqual(name, "hosties")) {
    g_hosties = false;
  }
}