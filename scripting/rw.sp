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
#define VERSION "2.14"
#define SERVER_LOCK_IP "45.121.211.57"

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

#define MAX_PAINTS 500
#define NUM_CSGO_WEAPONS 44
#define CSGO_MAX_WEAPON_NAME_LENGTH 28
#define IDWEARSEED_COMPONENT_LENGTH 12 //max length for any id, wear, seed component 

#define WS_ANTI_FLOOD_TIME 0.75
#define MAX_DIGITS_WEAR 10
#define MAX_PRE_WEAR_BLOCKS 4

#define TYPE_MENU 0
#define TYPE_QUICK 1

#define DEFAULT_ID 0
#define DEFAULT_WEAR 0.00001
#define DEFAULT_SEED 0

//Listing variable used to store information about each paint entry
//Old-delc used
enum Listing
{
  String:listName[64],
  paintNum,
  Float:wear,
  stattrak,
  quality
}

//Global variables

//Flags
AdminFlag wsFlag = Admin_Custom3;

//Handles
Menu menuw = null;
Handle db = null;
Handle tree[MAXPLAYERS+1] = null;
Handle saytimer = null;
Handle rtimer = null;
ArrayList csgo_weapons = null;

//Cvars
Handle cvar_c4 = null;
Handle cvar_saytimer = null;
Handle cvar_rtimer = null;
Handle cvar_rmenu = null;
Handle cvar_anti_flood = null;

//Ints
int g_paints[MAX_PAINTS][Listing];
int g_paintCount = 0;
int g_saytimer;
int g_rtimer;
int g_rmenu;

//Chars
char path_paints[PLATFORM_MAX_PATH];
char g_sCmdLogPath[256]; //log filename path

//Booleans
bool g_hosties = false;
bool g_c4 = false;
bool g_antiflood = true;
bool isChecked[MAXPLAYERS+1] = false;
bool g_canUseWS[MAXPLAYERS+1] = true; //for anti-flood

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

  //Store log file path, unique log per plugin load
  for (int i = 0;; i++) {
    BuildPath(Path_SM, g_sCmdLogPath, sizeof(g_sCmdLogPath), "logs/wpaints_%d.log", i);
    if ( !FileExists(g_sCmdLogPath) )
      break;
  }
  
  //Flags
  CreateConVar("sm_vipspecial_version", VERSION, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);

  //Commands
  RegAdminCmd("sm_reload_vipspecial", ReloadSkins, ADMFLAG_ROOT);
  
  //Convars
  cvar_c4 = CreateConVar("sm_vipspecial_c4", "1", "No description provided (see source). 1 = enabled, 0 = disabled");
  cvar_saytimer = CreateConVar("sm_vipspecial_saytimer", "10", "No description provided (see source). -1.0 = never show the commands in chat");
  cvar_rtimer = CreateConVar("sm_vipspecial_roundtimer", "-1.0", "No description provided (see source). -1.0 = always can use the command");
  cvar_rmenu = CreateConVar("sm_vipspecial_rmenu", "1", "No description provided (see source). 1 = enabled, 0 = disabled.");
  cvar_anti_flood = CreateConVar("sm_vipspecial_antiflood", "1", "No description provided (see source). 1 = enabled, 0 = disabled.");
  
  g_c4 = GetConVarBool(cvar_c4);
  g_saytimer = GetConVarInt(cvar_saytimer);
  g_rtimer = GetConVarInt(cvar_rtimer);
  g_rmenu = GetConVarBool(cvar_rmenu);
  g_antiflood = GetConVarBool(cvar_anti_flood);
  
  //Hooks
  HookEvent("round_start", roundStart);
  HookConVarChange(cvar_c4, OnConVarChanged);
  HookConVarChange(cvar_saytimer, OnConVarChanged);
  HookConVarChange(cvar_rtimer, OnConVarChanged);
  HookConVarChange(cvar_rmenu, OnConVarChanged);
  
  //Read paints from config file
  ReadPaints();
  
  //Populate csgo_weapons array
  if (csgo_weapons != null)
    CloseHandle(csgo_weapons);
  
  csgo_weapons = CreateArray(NUM_CSGO_WEAPONS);
  char weapon[CSGO_MAX_WEAPON_NAME_LENGTH];
  
  Format(weapon, sizeof(weapon), "weapon_negev");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_m249");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_bizon");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_p90");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_scar20");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_g3sg1");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_m4a1");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_m4a1_silencer");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_ak47");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_aug");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_galilar");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_awp");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_sg556");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_ump45");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_mp7");
  PushArrayString(csgo_weapons, weapon);

  Format(weapon, sizeof(weapon), "weapon_famas");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_mp9");
  PushArrayString(csgo_weapons, weapon);

  Format(weapon, sizeof(weapon), "weapon_mac10");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_ssg08");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_nova");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_xm1014");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_sawedoff");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_mag7");
  PushArrayString(csgo_weapons, weapon);
  
  // Secondary weapons
  Format(weapon, sizeof(weapon), "weapon_elite");
  PushArrayString(csgo_weapons, weapon);

  Format(weapon, sizeof(weapon), "weapon_deagle");
  PushArrayString(csgo_weapons, weapon);

  Format(weapon, sizeof(weapon), "weapon_revolver");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_tec9"); 
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_fiveseven");
  PushArrayString(csgo_weapons, weapon);

  Format(weapon, sizeof(weapon), "weapon_cz75a");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_glock");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_usp_silencer");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_p250");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_hkp2000");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_bayonet");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_knife_gut");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_knife_flip");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_knife_m9_bayonet");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_knife_karambit");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_knife_tactical");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_knife_butterfly");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_c4");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_knife_falchion");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_knife_push");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, sizeof(weapon), "weapon_knife_survival_bowie");
  PushArrayString(csgo_weapons, weapon);

  //Process players and set them up
  for (int client = 1; client <= MaxClients; ++client) {
    if (!IsClientInGame(client))
      continue;
    
    OnClientPutInServer(client);
    
    if (g_antiflood) g_canUseWS[client] = true;
  }
  
  //Check the database
  CheckDB(true);
}

//Update variables if convars change
public void OnConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
  if (convar == cvar_c4) {
    g_c4 = view_as<bool>(StringToInt(newValue));
  }
  else if (convar == cvar_saytimer) {
    g_saytimer = StringToInt(newValue);
  }
  else if (convar == cvar_rtimer) {
    g_rtimer = StringToInt(newValue);
  }
  else if (convar == cvar_rmenu) {
    g_rmenu = view_as<bool>(StringToInt(newValue));
  }
  else if (convar == cvar_anti_flood) {
    g_antiflood = view_as<bool>(StringToInt(newValue));
  }
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

//Monitor chat to capture commands
public Action OnClientSayCommand(int client, const char[] command_t, const char[] sArgs)
{
  char command[32];
  SplitString(sArgs, " ", command, sizeof(command));
  
  //If no spaces then user is calling command with no function
  if (strcmp(command, "") == 0)
    strcopy(command, sizeof(command), sArgs);
  
  //Check if command starts with following strings
  if( StrEqual(command, "!rw", false) ||
      StrEqual(command, "!rwskin", false) ||
      StrEqual(command, "!rwskins", false) ||
      StrEqual(command, "!ws", false) ||
      StrEqual(command, "!wskins", false) ||
      StrEqual(command, "!pk", false) ||
      StrEqual(command, "!paints", false)
    )
  {
    //Get arguments
    char idWearSeed[8][64];
    int argNum = ExplodeString(sArgs, " ", idWearSeed, sizeof(idWearSeed), sizeof(idWearSeed[]), true);
    argNum -= 1; //dont count the command name as an argument
    
    //Create search string
    char skinSearch[64];
    int preWearBlocks = 0;  //number of blocks before wear value argument (if provided)
    int offsetSkinNum = 0;  //number of skins to skip if search term matches more than one skin (if provided)
    
    for (int i = 1; i < sizeof(idWearSeed); ++i) {
      //If we have reached the wear quick codes, break
      if (StrEqual("FN", idWearSeed[i], false) ||
          StrEqual("MW", idWearSeed[i], false) ||
          StrEqual("FT", idWearSeed[i], false) ||
          StrEqual("WW", idWearSeed[i], false) ||
          StrEqual("BS", idWearSeed[i], false)
          ) 
      {
        break;     
      }
      
      //If string is numeric, we must have reached numeric id, wear or seed, break
      if (isStringNumeric(idWearSeed[i]))
        break;
      
      ++preWearBlocks;
    }
    
    //Exit if too many strings provided
    if (preWearBlocks > MAX_PRE_WEAR_BLOCKS ) {
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Too Many Preblocks");
      return Plugin_Handled;
    }
    
    //Implode string into complete search string
    if (preWearBlocks != 0) {
      Format(skinSearch, sizeof(skinSearch), "%s", idWearSeed[1]);
      
      for (int i = 1; i < preWearBlocks; ++i) {
        //Check for offset modifier
        if (strlen(idWearSeed[i+1]) == 2) {
          char firstChar = idWearSeed[i+1][0];
          char secondChar = idWearSeed[i+1][1];
          
          //Get offset number
          if (firstChar == '+' && IsCharNumeric(secondChar)) {
            offsetSkinNum = StringToInt(idWearSeed[i+1]);
            break;  //Don't add anymore search blocks to skinSearch after offset block
          }
        }
        
        Format(skinSearch, sizeof(skinSearch), "%s %s", skinSearch, idWearSeed[i+1]);
      }
    }
    
    //Parameters
    int inputIndex = DEFAULT_ID;
    float inputWear = DEFAULT_WEAR;
    int inputSeed = DEFAULT_SEED;
    
    //Set correct indexes for the wear and seed arguments
    //Compensate if we have no pre wear blocks
    int wearIndex = (preWearBlocks - 1) + ((preWearBlocks == 0) ? 3 : 2);
    int seedIndex = (preWearBlocks - 1) + ((preWearBlocks == 0) ? 4 : 3);
    
    //Get correct input index (via ID or skin search)
    if (preWearBlocks == 0) {
      inputIndex = StringToInt(idWearSeed[1]);
    }
    else {
      if (g_paintCount == 0) {
        LogError("Skin list failed to load or was unloaded at time of search.");
        return Plugin_Handled;
      }
      
      //Find a match, taking in consideration the offsetSkinNum
      bool matchFound = false;
      
      for (int i = 0; i < g_paintCount; ++i) {
        if (StrContains(g_paints[i][listName], skinSearch, false) != -1) {
          
          //Match found, check if offset is zero
          if (offsetSkinNum != 0) {
            --offsetSkinNum;
            continue;
          }
          
          //Otherwise, we will match this skin
          inputIndex = i;
          matchFound = true;
          break;
        }
      }
      
      //Print error if no matches found
      if (!matchFound) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "No Skin Match Found", skinSearch);
        return Plugin_Handled;
      }
    }
    
    //Check if quickWear String (FN, MW..etc) provided as wear index
    if (isStringNumeric(idWearSeed[wearIndex])) {
      if (argNum >= wearIndex) //Otherwise it should be a number
        inputWear = StringToFloat(idWearSeed[wearIndex]);
    }
    else {
      //Must be a quick wear code
      if (StrEqual("FN", idWearSeed[wearIndex], false))
        inputWear = DEFAULT_WEAR;
      else if (StrEqual("MW", idWearSeed[wearIndex], false))
        inputWear = 0.25;
      else if (StrEqual("FT", idWearSeed[wearIndex], false))
        inputWear = 0.55;
      else if (StrEqual("WW", idWearSeed[wearIndex], false))
        inputWear = 0.75;
      else if (StrEqual("BS", idWearSeed[wearIndex], false))
        inputWear = 0.95;
      else {
        //FIXME: This error is never printed
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Wear Not Recognized");
        return Plugin_Handled;
      }
    }
    
    //Get seed if provided
    if (argNum >= seedIndex)
      inputSeed = StringToInt(idWearSeed[seedIndex]);
    
    //Set parameter values
    if (argNum < 0) {
      LogError("Failed to explode command string correctly.");
      return Plugin_Handled; //error occured
    }
    else if (argNum == preWearBlocks + ((preWearBlocks == 0) ? 4 : 3)) {
      //too many total strings, too many arguments were provided
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Too Many Args");
      return Plugin_Handled;
    }
    
    //Get VIP status
    int isVIP = CheckCommandAccess(client, "", FlagToBit(wsFlag));
    
    //Only VIPS can use this plugin unless you are setting the default skin
    if (!isVIP) {
      if (!(argNum == 1 && inputIndex == 0)) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Must be VIP");
        return Plugin_Handled;
      }
    }
    
    // Check input wears
    if (argNum >= 2) {
      //Check range
      if (inputWear < 0.0 || inputWear > 1.0) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Wear Value Wrong");
        return Plugin_Handled;
      }
      
      //Limit length of floating point string
      if (strlen(idWearSeed[2]) > MAX_DIGITS_WEAR) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Wear Too Long");
        return Plugin_Handled;
      }
    }
    
    //Show menu
    if (argNum == 0) {
      ShowMenu(client, 0);

      if (saytimer != null || g_saytimer == -1)
        return Plugin_Handled;

      saytimer = CreateTimer(1.0 * g_saytimer, Tsaytimer);

      return Plugin_Handled;
    }
    else {
      //Call WSkin_Selecter
      WSkin_Selecter(TYPE_QUICK, client, inputIndex, inputWear, inputSeed);
    }
    
    return Plugin_Handled;
  }
  else if(StrEqual(command, "!ss", false) || StrEqual(command, "!showskin", false))
  {
    ShowSkin(client);
    
    if (saytimer != null || g_saytimer == -1)
      return Plugin_Handled;
    
    saytimer = CreateTimer(1.0 * g_saytimer, Tsaytimer);
    
    return Plugin_Continue;
  }

  return Plugin_Continue;
}

//Helper function that tells you if a string is numeric (int or floating point)
bool isStringNumeric(char[] s) {
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

//Checks and begins connection to database
void CheckDB(bool reconnect = false, char dbName[16] = "wpaints")
{
  if (db != null) {
    if(reconnect) {
      CloseHandle(db);
      db = null;
    }
    else
      return;
  }

  //Check if databases.cfg entry exist
  if (!SQL_CheckConfig( dbName )) {
    LogMessage("wpaints database does not exist.");
    return;
  }
  
  SQL_TConnect(OnDBConnect, dbName);
}

public void OnDBConnect(Handle owner, Handle hndl, const char[] error, any data)
{
  if (hndl == null) {
    LogToFileEx(g_sCmdLogPath, "Database failure: %s", error);
    SetFailState("Database connection failed.");
  }
  else {
    db = hndl;
    char buffer[3096];
    
    SQL_GetDriverIdent(SQL_ReadDriver(db), buffer, sizeof(buffer));

    //Non sqlite databases not supported
    if (!StrEqual(buffer, "sqlite", false)) {
      SetFailState("Non sqlite databases are not supported.");
      return;
    }
  
    //Create temp array with weapon names
    char temp[NUM_CSGO_WEAPONS][CSGO_MAX_WEAPON_NAME_LENGTH];
    
    for (int i = 0; i < GetArraySize(csgo_weapons); ++i) {
      GetArrayString(csgo_weapons, i, temp[i], sizeof(temp[]));
    }
  
    //Create SQL Database if it doesn't exist
    Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS wpaints ( steamid varchar(32) NOT NULL, %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', %s varchar(32) NOT NULL DEFAULT '0;0.00001;0', PRIMARY KEY (steamid))", temp[0],temp[1],temp[2],temp[3],temp[4],temp[5],temp[6],temp[7],temp[8],temp[9],temp[10],temp[11],temp[12],temp[13],temp[14],temp[15],temp[16],temp[17],temp[18],temp[19],temp[20],temp[21],temp[22],temp[23],temp[24],temp[25],temp[26],temp[27],temp[28],temp[29],temp[30],temp[31],temp[32],temp[33],temp[34],temp[35],temp[36],temp[37],temp[38],temp[39],temp[40],temp[41],temp[42], temp[43]);
  
    LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
    SQL_TQuery(db, initDBConn_callback, buffer);
  }
}

//Initial database callback
public void initDBConn_callback(Handle owner, Handle hndl, const char[] error, any data)
{
  if (hndl == null) {
    LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
    return;
  }
  
  //Log success
  LogToFileEx(g_sCmdLogPath, "Initial database connection successful.");
  
  for (int client = 1; client <= MaxClients; ++client) {
    if (IsClientInGame(client)) {
      OnClientPostAdminCheck(client);
    }
  }
}

//Check steamID once client is authorized 
public void OnClientPostAdminCheck(int client)
{
  if (!IsFakeClient(client))
    CheckSteamID(client);
}

//Check users steam ID in database
void CheckSteamID(int client)
{
  char query[100], steamid[32];
  GetClientAuthId(client, AuthId_Steam2,  steamid, sizeof(steamid) );
  
  Format(query, sizeof(query), "SELECT * FROM wpaints WHERE steamid = '%s'", steamid);
  LogToFileEx(g_sCmdLogPath, "Query %s", query);
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
    CheckDB();
    return;
  }
  
  //If no results, this is a new user, add them to database
  if (!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) {
    AddNewClientDB(client);
    return;
  }
  
  //Get entries for this returning client
  tree[client] = CreateTrie();

  char Classname[CSGO_MAX_WEAPON_NAME_LENGTH];
  char temp[CSGO_MAX_WEAPON_NAME_LENGTH];
  
  int counter = 1; //initial offset so we skip non weapon rows at top of database
  
  for (int i = 0; i < GetArraySize(csgo_weapons); ++i) {
    GetArrayString(csgo_weapons, i, Classname, sizeof(Classname));
    SQL_FetchString(hndl, counter, temp, sizeof(temp));
    
    //temp is in format:  id;wear;seed  , break it apart
    //After this idWearSeed[0] contains id, idWearSeed[1] contains wear level, idWearSeed[2] contains seed
    char idWearSeed[3][IDWEARSEED_COMPONENT_LENGTH];
    ExplodeString(temp, ";", idWearSeed, sizeof(idWearSeed), sizeof(idWearSeed[]));
    
    //Set ID value in tree
    setID(client, Classname, StringToInt(idWearSeed[0]));
    
    //Set wear value in tree
    setWear(client, Classname, StringToFloat(idWearSeed[1]));
    
    //Set seed value in tree
    setSeed(client, Classname, StringToInt(idWearSeed[2]));
    
    ++counter;
  }
  
  isChecked[client] = true;
}

//Adds a new client to the database
void AddNewClientDB(int client)
{
  //Get SteamID
  char query[100], steamid[32];
  GetClientAuthId(client, AuthId_Steam2,  steamid, sizeof(steamid) );
  int userid = GetClientUserId(client);
  
  Format(query, sizeof(query), "INSERT INTO wpaints(steamid) VALUES('%s');", steamid);
  LogToFileEx(g_sCmdLogPath, "Query %s", query);
  SQL_TQuery(db, AddNewClientDB_callback, query, userid);
}

//AddNewClientDB callback
public void AddNewClientDB_callback(Handle owner, Handle hndl, const char[] error, any data)
{
  if (hndl == null) {
    LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
    CheckDB();
  }
  
  int client = GetClientOfUserId(data);
 
  // Make sure the client didn't disconnect while the thread was running 
  if (client == 0)
    return;
  
 
  tree[client] = CreateTrie();
  char Classname[CSGO_MAX_WEAPON_NAME_LENGTH];
  
  for (int i = 0; i < GetArraySize(csgo_weapons); ++i) {
    //Set ID value in tree
    GetArrayString(csgo_weapons, i, Classname, sizeof(Classname));
    setID(client, Classname, DEFAULT_ID);
    
    //Set wear value in tree
    setWear(client, Classname, DEFAULT_WEAR);
    
    //Set seed value in tree
    setSeed(client, Classname, DEFAULT_SEED);
  }
  
  //Set client as checked
  isChecked[client] = true;
}

//General database callback, check for any errors
public void DBGeneral_callback(Handle owner, Handle hndl, const char[] error, any data)
{
  if (hndl == null) {
    LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
  }
  
  int client = GetClientOfUserId(data);
 
  // Make sure the client didn't disconnect while the thread was running
  if (client == 0)
    return;

  isChecked[client] = true;
}


//Clean up when client disconnects
public void OnClientDisconnect(int client)
{ 
  isChecked[client] = false;

  if(tree[client] != null) {
    ClearTrie(tree[client]);
    CloseHandle(tree[client]);
    tree[client] = null;
  }
}

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

//Reload skins from config
public Action ReloadSkins(int client, int args)
{  
  ReadPaints();
  ReplyToCommand(client, " \x04[WS]\x01 %t", "Weapon paints reloaded", client);
  return Plugin_Handled;
}

//Show weaponskins menu
void ShowMenu(int client, int item)
{
  SetMenuTitle(menuw, "%t", "Menu title", client);
  
  RemoveMenuItem(menuw, 1);
  RemoveMenuItem(menuw, 0);
  
  char tdisplay[64];
  
  Format(tdisplay, sizeof(tdisplay), "%t", "Random paint", client);
  InsertMenuItem(menuw, 0, "-1", tdisplay);
  Format(tdisplay, sizeof(tdisplay), "%t", "Default paint", client);
  InsertMenuItem(menuw, 1, "0", tdisplay);
  
  DisplayMenuAtItem(menuw, client, item, 0);
}


//Tell everybody what their current skin is
void ShowSkin(int client)
{
  //Ensure  client is alive, and not root
  if (client == 0) {
    PrintToConsole(client, "Can't use this command from server input.");
    return;
  }
  else if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "You cant use this when you are dead", client);
    return;
  }
    
  int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  
  //Ensure entity is okay
  if (weapon < 1 || !IsValidEdict(weapon) || !IsValidEntity(weapon)) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Paint not found", client);
    return;
  }
  
  //Find paintkit used
  int search = GetEntProp(weapon, Prop_Send, "m_nFallbackPaintKit");
  
  for (int i = 1; i < g_paintCount; ++i) {
    if (search == g_paints[i][paintNum]) {
      
      //Get client name who used command
      char clientName[MAX_NAME_LENGTH+1];
      GetClientName(client, clientName, sizeof(clientName));
      
      //Get the proper classname
      char Classname[CSGO_MAX_WEAPON_NAME_LENGTH];
      int weaponindex = getProperClassname(client, weapon, Classname);
        
      //Check to see if classname is allowed
      if (weaponindex == -1) {
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "You cant use a paint in this weapon");
        return;
      }
      
      //Get stored id
      int storedID = getStoredID(client, Classname);
      
      if (storedID == DEFAULT_ID) { //No skin stored for this gun, default skin
        CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Paint Is Default", Classname);
        return;
      }
    
      //Get stored wear value
      float storedWear = getStoredWear(client, Classname);
      
      //Get stored seed value
      int storedSeed = getStoredSeed(client, Classname);
      
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "Paint found", clientName, g_paints[i][listName], Classname, i, storedWear, storedSeed);
      
      return;
    }
  }
  
  //Print not found message if we failed to find paint
  CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Paint not found", client);
}

public Action Tsaytimer(Handle timer)
{
  saytimer = null;
}

public Action roundStart(Handle event, const char[] name, bool dontBroadcast) 
{
  if (g_rtimer == -1)
    return;
  
  if (rtimer != null) {
    KillTimer(rtimer);
    rtimer = null;
  }
  
  rtimer = CreateTimer(1.0 * g_rtimer, Rtimer);
}

public Action Rtimer(Handle timer)
{
  rtimer = null;
}

public int DIDMenuHandler(Menu menu, MenuAction action, int client, int itemNum) 
{
  if (action == MenuAction_Select) {
    //Itemnum starts at 0 so we have to subtract 1 so it matches the menu options
    WSkin_Selecter(TYPE_MENU, client, itemNum - 1, DEFAULT_WEAR, DEFAULT_SEED);
  }
}

void WSkin_Selecter(int type, int client, int inputID, float inputWear, int inputSeed) 
{
  //Ensure client has been checked
  if (!isChecked[client])
    return;
  
  //Antiflood checks
  if (g_antiflood) {
    if (!g_canUseWS[client]) {
      //Using ws too quickly
      CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Anti Flood Message");
      LogAction(client, -1, "\"%L\" is using !ws too quickly. Possible flood attempt.", client);
      if (type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition()); //keep menu up if using menu
      return;
    }
  }
  
  //rtimer checks
  if (rtimer == null && g_rtimer != -1) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "You can use this command only the first seconds", client, g_rtimer);
    if (type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }
  
  //Ensure player is still in game
  if(!IsClientInGame(client))
    return;
  
  //Ensure player is alive
  if(!IsPlayerAlive(client)) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "You cant use this when you are dead");
    if (type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }
  
  //Hosties
  if(g_hosties && IsClientInLastRequest(client)) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "You cant use this when you are in a lastrequest");
    if (type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }

  //Ensure we don't request paint outside of range
  if (inputID < -1 || inputID >= g_paintCount) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Index out of Range", g_paintCount - 1);
    return;
  }

  int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

  //Ensure weapon entity is okay
  if (weapon < 1 || !IsValidEdict(weapon) || !IsValidEntity(weapon)) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "You cant use a paint in this weapon");
    if (type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }
    
  //Get the proper classname
  char Classname[CSGO_MAX_WEAPON_NAME_LENGTH];
  int weaponindex = getProperClassname(client, weapon, Classname);
    
  //Check to see if classname is allowed
  if (weaponindex == -1) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "You cant use a paint in this weapon");
    if (type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }
  
  //Save indexID in trie for client
  setID(client, Classname, inputID);
  
  //Save wear
  setWear(client, Classname, inputWear);
  
  //Save seed
  setSeed(client, Classname, inputSeed);
  
  //Call paint change plugin with these parameters
  ChangePaint(client, weapon, Classname, weaponindex, inputID, inputWear, inputSeed);
  FakeClientCommand(client, "use %s", Classname);
  
  //Print weapon skin changed message based on type of change
  if (inputID == 0)
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX,"You have choose your default paint for your", Classname);
  else if (inputID == -1)
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX,"You have choose a random paint for your", Classname);
  else
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "You have choose a weapon", g_paints[inputID][listName], Classname);
  
  //Set anti flood timer
  if (g_antiflood) {
    g_canUseWS[client] = false;
    CreateTimer(WS_ANTI_FLOOD_TIME, Timer_ReEnable_WS, client);
  }
  
  if (type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
}

//Re-enable ws for particular client
public Action Timer_ReEnable_WS(Handle timer, int client)
{
  g_canUseWS[client] = true;
}

//Read paint (skin codes/quality/wear etc) information from config file
void ReadPaints()
{
  BuildPath(Path_SM, path_paints, sizeof(path_paints), "configs/csgo_wpaints.cfg");
  
  Handle kv;
  g_paintCount = 1;

  kv = CreateKeyValues("Paints");
  FileToKeyValues(kv, path_paints);

  if (!KvGotoFirstSubKey(kv)) {
    SetFailState("CFG File not found: %s", path_paints);
    CloseHandle(kv);
  }
  
  do {
    KvGetSectionName(kv, g_paints[g_paintCount][listName], 64); //size hardcoded here due to olddecl enums
    g_paints[g_paintCount][paintNum] = KvGetNum(kv, "paint", 0);
    g_paints[g_paintCount][wear] = KvGetFloat(kv, "wear", -1.0);
    g_paints[g_paintCount][stattrak] = KvGetNum(kv, "stattrak", -2);
    g_paints[g_paintCount][quality] = KvGetNum(kv, "quality", -2);

    g_paintCount++;
  } while (KvGotoNextKey(kv));
  CloseHandle(kv);
  
  //Create (or update) the menu
  if (menuw != null) {
    CloseHandle(menuw);
    menuw = null;
  }
  
  menuw = CreateMenu(DIDMenuHandler);
  
  AddMenuItem(menuw, "-1", "Random paint");
  AddMenuItem(menuw, "0", "Default paint");
  
  char item[4];
    
  for (int i = 1; i < g_paintCount; ++i) {
    Format(item, sizeof(item), "%i", i);
    AddMenuItem(menuw, item, g_paints[i][listName]);
  }
  
  SetMenuExitButton(menuw, true);
}

stock int GetReserveAmmo(int client, int weapon)
{
  int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
  if (ammotype == -1) return -1;
  
  return GetEntProp(client, Prop_Send, "m_iAmmo", _, ammotype);
}

stock void SetReserveAmmo(int client, int weapon, int weaponEntity, int ammo, int primaryReserve)
{
  int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
  if (ammotype == -1) return;
  
  SetEntProp(weaponEntity, Prop_Send, "m_iPrimaryReserveAmmoCount", primaryReserve); 
  SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammotype);
} 

//Function that perfoms actual paint change for weapon entity
void ChangePaint(int client, int windex, char[] Classname, int weaponindex, int inputID, float inputWear, int inputSeed)
{
  //Detect knives
  bool knife = false;
  
  if (StrContains(Classname, "weapon_knife", false) == 0 || StrContains(Classname, "weapon_bayonet", false) == 0)
    knife = true;
  
  int ammo, clip, primaryReserve;
  
  if (!knife) {
    ammo = GetReserveAmmo(client, windex);
    clip = GetEntProp(windex, Prop_Send, "m_iClip1");
    primaryReserve = GetEntProp(windex, Prop_Send, "m_iPrimaryReserveAmmoCount");
  }
  
  RemovePlayerItem(client, windex);
  AcceptEntityInput(windex, "Kill");
  
  int entity = GivePlayerItem(client, Classname);
  
  if(knife) {
    //Equip knife
    if (weaponindex != 42 && weaponindex != 59) 
      EquipPlayerWeapon(client, entity);
  }
  else {
    //Set ammo to correct ammount
    SetReserveAmmo(client, windex, entity, ammo, primaryReserve);
    SetEntProp(entity, Prop_Send, "m_iClip1", clip);
  }
  
  //Check inputID
  //If ID is zero then we don't need to skin this weapon (use default skin)
  if (inputID == 0) {
    //Save preferences to DB
    updateSkinPrefsDB(client, Classname, DEFAULT_ID, DEFAULT_WEAR, DEFAULT_SEED);
    return;
  }

  if(inputID == -1)  //randomised index
    inputID = GetRandomInt(1, g_paintCount-1);
  
  //Preserve m_iItemIDHigh and m_iItemIDLow
  int m_iItemIDHigh = GetEntProp(entity, Prop_Send, "m_iItemIDHigh");
  int m_iItemIDLow = GetEntProp(entity, Prop_Send, "m_iItemIDLow");
  
  SetEntProp(entity,Prop_Send,"m_iItemIDLow", 2048);
  SetEntProp(entity,Prop_Send,"m_iItemIDHigh", 0);

  //Set skin
  SetEntProp(entity,Prop_Send, "m_nFallbackPaintKit", g_paints[inputID][paintNum]);
  
  //Set wear
  SetEntPropFloat(entity, Prop_Send, "m_flFallbackWear", inputWear);
  
  //Set seed
  SetEntProp(entity, Prop_Send, "m_nFallbackSeed", inputSeed);
  
  //Stattrak
  if(g_paints[inputID][stattrak] != -2)
    SetEntProp(entity,Prop_Send, "m_nFallbackStatTrak", g_paints[inputID][stattrak]);
  
  //Quality
  if(g_paints[inputID][quality] != -2)
    SetEntProp(entity,Prop_Send, "m_iEntityQuality", g_paints[inputID][quality]);
  
  //Auto star knives
  if (knife)
    SetEntProp(entity, Prop_Send, "m_iEntityQuality", 3); //3 is for the star
  
  //Save changes to datebase
  updateSkinPrefsDB(client, Classname, inputID, inputWear, inputSeed);
  
  //Restore the previous itemID
  Handle pack;
  CreateDataTimer(0.2, RestoreItemID, pack);
  WritePackCell(pack, EntIndexToEntRef(entity));
  WritePackCell(pack, m_iItemIDHigh);
  WritePackCell(pack, m_iItemIDLow);
}

//Updates database with skin preferences after a skin change
void updateSkinPrefsDB(int client, char[] Classname, int inputID, float inputWear, int inputSeed)
{
  //Save changes to datebase (via UPDATE query)
  char steamid[32];
  GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
  
  char buffer[200];
  Format(buffer, sizeof(buffer), "UPDATE wpaints SET %s = '%d;%f;%d' WHERE steamid = '%s';", Classname, inputID, inputWear, inputSeed, steamid); 
  LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
  SQL_TQuery(db, DBGeneral_callback, buffer, GetClientUserId(client));
}

//Restore itemID's
public Action RestoreItemID(Handle timer, Handle pack)
{
  int entity;
  int m_iItemIDHigh;
  int m_iItemIDLow;
  
  ResetPack(pack);
  entity = EntRefToEntIndex(ReadPackCell(pack));
  m_iItemIDHigh = ReadPackCell(pack);
  m_iItemIDLow = ReadPackCell(pack);
  
  if (entity != INVALID_ENT_REFERENCE) {
    SetEntProp(entity, Prop_Send, "m_iItemIDHigh" ,m_iItemIDHigh);
    SetEntProp(entity, Prop_Send, "m_iItemIDLow", m_iItemIDLow);
  }
}

//SDKhook when clients connect to server
public void OnClientPutInServer(int client)
{
  if (!IsFakeClient(client))
    SDKHook(client, SDKHook_WeaponEquipPost, OnPostWeaponEquip);
  
  if (g_antiflood) g_canUseWS[client] = true; //anti-flood
}

//Skin weapons that we pick up
public Action OnPostWeaponEquip(int client, int weapon)
{
  Handle pack;
  CreateDataTimer(0.0, WeaponPickUpSkin, pack);
  WritePackCell(pack, EntIndexToEntRef(weapon));
  WritePackCell(pack, client);
}

//Apply skin to weapon that was equiped
public Action WeaponPickUpSkin(Handle timer, Handle pack)
{
  int weapon;
  int client
    
  ResetPack(pack);
  weapon = EntRefToEntIndex(ReadPackCell(pack));
  client = ReadPackCell(pack);
  
  //Check client
  if (!IsClientInGame(client) || !IsPlayerAlive(client) || (g_hosties && IsClientInLastRequest(client)))
    return; 
  
  //Check if VIP
  int isVIP = CheckCommandAccess(client, "", FlagToBit(wsFlag));
  
  if (!isVIP)
    return;
  
  //Check weapon
  if(weapon == INVALID_ENT_REFERENCE || weapon < 1 || !IsValidEdict(weapon) || !IsValidEntity(weapon))
    return;
  
  //Check previous owner and item id's
  if ( GetEntProp(weapon, Prop_Send, "m_hPrevOwner") > 0 || (GetEntProp(weapon, Prop_Send, "m_iItemIDHigh") == 0 && GetEntProp(weapon, Prop_Send, "m_iItemIDLow") == 2048))
    return;

  //Get the proper classname
  char Classname[CSGO_MAX_WEAPON_NAME_LENGTH];
  int weaponindex = getProperClassname(client, weapon, Classname);

  //Check to see if classname is allowed
  if (weaponindex == -1)
    return;
    
  //Get the skin ID
  int storedID = getStoredID(client, Classname);
  if (storedID == DEFAULT_ID) //No skin stored for this gun
    return;
  
  //Get stored wear value
  float storedWear = getStoredWear(client, Classname);
  
  //Get stored seed value
  int storedSeed = getStoredSeed(client, Classname);
  
  //Change paint to proper skin with proper wear
  ChangePaint(client, weapon, Classname, weaponindex, storedID, storedWear, storedSeed);
}

//Get stored ID value from tree
int getStoredID(int client, char Classname[CSGO_MAX_WEAPON_NAME_LENGTH])
{
  int storedID = DEFAULT_ID;
  
  //Ensure tree[client] exists and handle is valid as it may not be valid yet
  if (tree[client] != null)
    GetTrieValue(tree[client], Classname, storedID);
  
  return storedID;
}

//Get stored wear value from tree
float getStoredWear(int client, char Classname[CSGO_MAX_WEAPON_NAME_LENGTH])
{
  float storedWear = DEFAULT_WEAR;
  char Classname_wearname[CSGO_MAX_WEAPON_NAME_LENGTH + 5];
  Format(Classname_wearname, sizeof(Classname_wearname), "%s%s", Classname, "_wear");
  GetTrieValue(tree[client], Classname_wearname, storedWear);
  return storedWear;
}

//Get stored seed value from tree
int getStoredSeed(int client, char Classname[CSGO_MAX_WEAPON_NAME_LENGTH])
{
  int storedSeed = DEFAULT_SEED;
  char Classname_seed[CSGO_MAX_WEAPON_NAME_LENGTH + 5];
  Format(Classname_seed, sizeof(Classname_seed), "%s%s", Classname, "_seed");
  GetTrieValue(tree[client], Classname_seed, storedSeed);
  return storedSeed;
}

//Set ID value in tree
void setID(int client, char Classname[CSGO_MAX_WEAPON_NAME_LENGTH], int id)
{
  SetTrieValue(tree[client], Classname, id);
}

//Set wear value in tree
void setWear(int client, char Classname[CSGO_MAX_WEAPON_NAME_LENGTH], float wearValue)
{
  char Classname_wearname[CSGO_MAX_WEAPON_NAME_LENGTH + 5];
  Format(Classname_wearname, sizeof(Classname_wearname), "%s%s", Classname, "_wear");
  
  SetTrieValue(tree[client], Classname_wearname, wearValue);
}

//Set seed value in tree
void setSeed(int client, char Classname[CSGO_MAX_WEAPON_NAME_LENGTH], int seed)
{
  char Classname_seed[CSGO_MAX_WEAPON_NAME_LENGTH + 5];
  Format(Classname_seed, sizeof(Classname_seed), "%s%s", Classname, "_seed");
  
  SetTrieValue(tree[client], Classname_seed, seed);
}

//Functions returns the proper completed classname for a given classname
//Disallowed weapons or weapon slots will return -1
//Otherwise, the weaponindex is returned on success and the Classname is altered
int getProperClassname(int client, int weapon, char Classname[CSGO_MAX_WEAPON_NAME_LENGTH])
{
  if (!GetEdictClassname(weapon, Classname, sizeof(Classname)))
    return -1;
  
  //Ignore tasers
  if(StrEqual(Classname, "weapon_taser"))
    return -1;
  
  int weaponindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
  
  //Ignore these weapon indexes
  if(weaponindex == 42 || weaponindex == 59)
    return -1;
  
  if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == weapon || GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) == weapon || GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == weapon || (g_c4 && GetPlayerWeaponSlot(client, CS_SLOT_C4) == weapon))
  {
    switch (weaponindex) {
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
    
    return weaponindex;
  }
  else
    return -1;
}
