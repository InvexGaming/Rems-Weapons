#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <clientprefs>
#include <multicolors>

#undef REQUIRE_PLUGIN
#include <lastrequest>

#define VERSION "2.04"

#define MAX_PAINTS 800
#define TYPE_MENU 0
#define TYPE_QUICK 1

#define DEFAULT_ID 0
#define INVALID_WEAR -1.0
#define DEFAULT_WEAR -1.0
#define DEFAULT_SEED 0

enum Listing
{
  String:listName[64],
  index,
  Float:wear,
  stattrak,
  quality
}

new Handle:menuw = INVALID_HANDLE;

new Handle:csgo_weapons;
new g_paints[MAX_PAINTS][Listing];
new g_paintCount = 0;
new String:path_paints[PLATFORM_MAX_PATH];


new bool:g_hosties = false;
new bool:g_c4;
new Handle:cvar_c4;


new Handle:db = INVALID_HANDLE;
new String:g_sCmdLogPath[256];

new Handle:tree[MAXPLAYERS+1] = INVALID_HANDLE;
new bool:isChecked[MAXPLAYERS+1];

new Handle:saytimer;
new Handle:cvar_saytimer;
new g_saytimer;

new Handle:rtimer;
new Handle:cvar_rtimer;
new g_rtimer;

new Handle:cvar_rmenu;
new g_rmenu;

public Plugin:myinfo =
{
  name = "CS:GO VIP Plugin",
  author = "Invex | Byte",
  description = "Special actions for VIP players.",
  version = VERSION,
  url = "http://www.invexgaming.com.au"
};

public OnPluginStart()
{
  LoadTranslations ("weaponpaints.phrases");

  //Create log file
  for(new i = 0;; i++) {
    BuildPath(Path_SM, g_sCmdLogPath, sizeof(g_sCmdLogPath), "logs/wpaints_%d.log", i);
    if ( !FileExists(g_sCmdLogPath) )
      break;
  }
  
  CreateConVar("sm_vipspecial_version", VERSION, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);

  //Commands
  RegAdminCmd("sm_reload_vipspecial", ReloadSkins, ADMFLAG_ROOT);

  //Convars
  cvar_c4 = CreateConVar("sm_vipspecial_c4", "1", "No description provided (see source). 1 = enabled, 0 = disabled");
  cvar_saytimer = CreateConVar("sm_vipspecial_saytimer", "10", "No description provided (see source). -1.0 = never show the commands in chat");
  cvar_rtimer = CreateConVar("sm_vipspecial_roundtimer", "-1.0", "No description provided (see source). -1.0 = always can use the command");
  cvar_rmenu = CreateConVar("sm_vipspecial_rmenu", "1", "No description provided (see source). 1 = enabled, 0 = disabled.");
  
  g_c4 = GetConVarBool(cvar_c4);
  g_saytimer = GetConVarInt(cvar_saytimer);
  g_rtimer = GetConVarInt(cvar_rtimer);
  g_rmenu = GetConVarBool(cvar_rmenu);
  
  //Hooks
  HookEvent("round_start", roundStart);
  HookConVarChange(cvar_c4, OnConVarChanged);
  HookConVarChange(cvar_saytimer, OnConVarChanged);
  HookConVarChange(cvar_rtimer, OnConVarChanged);
  HookConVarChange(cvar_rmenu, OnConVarChanged);
  
  //Read paints from config file
  ReadPaints();
  
  //Populate csgo_weapons array
  if(csgo_weapons != INVALID_HANDLE)
    CloseHandle(csgo_weapons);
  
  csgo_weapons = CreateArray(128);
  
  new String:weapon[64];
  
  Format(weapon, 64, "weapon_negev");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_m249");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_bizon");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_p90");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_scar20");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_g3sg1");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_m4a1");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_m4a1_silencer");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_ak47");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_aug");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_galilar");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_awp");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_sg556");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_ump45");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_mp7");
  PushArrayString(csgo_weapons, weapon);

  Format(weapon, 64, "weapon_famas");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_mp9");
  PushArrayString(csgo_weapons, weapon);

  Format(weapon, 64, "weapon_mac10");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_ssg08");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_nova");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_xm1014");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_sawedoff");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_mag7");
  PushArrayString(csgo_weapons, weapon);
  
  // Secondary weapons
  Format(weapon, 64, "weapon_elite");
  PushArrayString(csgo_weapons, weapon);

  Format(weapon, 64, "weapon_deagle");
  PushArrayString(csgo_weapons, weapon);

  Format(weapon, 64, "weapon_revolver");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_tec9"); 
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_fiveseven");
  PushArrayString(csgo_weapons, weapon);

  Format(weapon, 64, "weapon_cz75a");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_glock");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_usp_silencer");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_p250");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_hkp2000");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_bayonet");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_knife_gut");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_knife_flip");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_knife_m9_bayonet");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_knife_karambit");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_knife_tactical");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_knife_butterfly");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_c4");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_knife_falchion");
  PushArrayString(csgo_weapons, weapon);
  
  Format(weapon, 64, "weapon_knife_push");
  PushArrayString(csgo_weapons, weapon);

  //Process players and set them up
  for (new client = 1; client <= MaxClients; client++)
  {
    if (!IsClientInGame(client))
      continue;
      
    OnClientPutInServer(client);
  }
  
  //Check the database
  CheckDB(true);
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
  if (convar == cvar_c4)
  {
    g_c4 = bool:StringToInt(newValue);
  }
  else if (convar == cvar_saytimer)
  {
    g_saytimer = StringToInt(newValue);
  }
  else if (convar == cvar_rtimer)
  {
    g_rtimer = StringToInt(newValue);
  }
  else if (convar == cvar_rmenu)
  {
    g_rmenu = bool:StringToInt(newValue);
  }
}

public OnPluginEnd()
{
  for(new client = 1; client <= MaxClients; client++)
  {
    if(IsClientInGame(client))
    {
      OnClientDisconnect(client);
    }
  }
}

public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
  //Check if command starts with following strings
  if( strncmp(sArgs, "!ws", 3, false) == 0 || 
      strncmp(sArgs, "!wskin", 6, false) == 0 || 
      strncmp(sArgs, "!wskins", 7, false) == 0 || 
      strncmp(sArgs, "!pk", 3, false) == 0 || 
      strncmp(sArgs, "!paints", 7, false) == 0 || 
      strncmp(sArgs, "!pkits", 6, false) == 0 || 
      strncmp(sArgs, "!rvip", 5, false) == 0
    )
  {
    //Get arguments
    decl String:idWearSeed[5][14];
    new returnNum = ExplodeString(sArgs, " ", idWearSeed, sizeof(idWearSeed), sizeof(idWearSeed[]), true);
    
    //Parameters
    new inputIndex = DEFAULT_ID;
    new Float:inputWear = DEFAULT_WEAR;
    new inputSeed = DEFAULT_SEED;
    
    //Set parameter values
    if (returnNum == 0)
      return Plugin_Handled; //error
    else if (returnNum == 1) {
      //do nothing here
    }
    else if (returnNum == 2) {
      inputIndex = StringToInt(idWearSeed[1]);
    }
    else if (returnNum == 3) {
      inputIndex = StringToInt(idWearSeed[1]);
      inputWear = StringToFloat(idWearSeed[2]);
    }
    else if (returnNum == 4) {
      inputIndex = StringToInt(idWearSeed[1]);
      inputWear = StringToFloat(idWearSeed[2]);
      inputSeed = StringToInt(idWearSeed[3]);
    }
    else {
      //5 strings retrieved, too many arguments were provided
      CPrintToChat(client, " {green}[WS]{default} %t", "Too Many Args");
      return Plugin_Handled;
    }
    
    //Get VIP status
    new isVIP = CheckCommandAccess(client, "", ADMFLAG_CUSTOM3);
    
    //Only VIPS can use this plugin unless you are setting the default skin
    if (!isVIP) {
      if (!(returnNum == 2 && inputIndex == 0)) {
        CPrintToChat(client, " {green}[WS]{default} %t", "Must be VIP");
        return Plugin_Handled;
      }
    }
    
    // Check input wears
    if (returnNum >= 3 && inputWear < 0.0 || inputWear > 1.0) { //check for valid wear
      CPrintToChat(client, " {green}[WS]{default} %t", "Wear Value Wrong");
      return Plugin_Handled;
    }
    
    //Show menu
    if (returnNum == 1) {
      ShowMenu(client, 0);

      if (saytimer != INVALID_HANDLE || g_saytimer == -1)
        return Plugin_Handled;

      saytimer = CreateTimer(1.0 * g_saytimer, Tsaytimer);

      return Plugin_Handled;
    }
    else {
      //Call WSkin_Selecter
      WSkin_Selecter(TYPE_QUICK, INVALID_HANDLE, client, 0, inputIndex, inputWear, inputSeed);
    }
    
    return Plugin_Continue;
  }
  else if(StrEqual(sArgs, "!ss", false) || StrEqual(sArgs, "!showskin", false))
  {
    ShowSkin(client);
    
    if (saytimer != INVALID_HANDLE || g_saytimer == -1)
      return Plugin_Handled;
    
    saytimer = CreateTimer(1.0 * g_saytimer, Tsaytimer);
    
    return Plugin_Continue;
  }

  return Plugin_Continue;
}


CheckDB(bool:reconnect = false, String:yourdb[64] = "wpaints")
{
  if(reconnect)
  {
    if (db != INVALID_HANDLE)
    {
      CloseHandle(db);
      db = INVALID_HANDLE;
    }
  }
  else if (db != INVALID_HANDLE)
  {
    return;
  }

  //Check if databases.cfg entry exist
  if (!SQL_CheckConfig( yourdb ))
  {
    LogMessage("wpaints database does not exist.");
    return;
  }
  
  SQL_TConnect(OnSqlConnect, yourdb);
}

public OnSqlConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
  if (hndl == INVALID_HANDLE)
  {
    LogToFileEx(g_sCmdLogPath, "Database failure: %s", error);
    SetFailState("Database connection failed.");
  }
  else
  {
    db = hndl;
    decl String:buffer[3096];
    
    SQL_GetDriverIdent(SQL_ReadDriver(db), buffer, sizeof(buffer));

    //Non sqlite databases not supported
    if (!StrEqual(buffer, "sqlite", false))
      return;
  
    //Create temp array with weapon names
    new String:temp[64][41];
    
    for (new i = 0; i < GetArraySize(csgo_weapons); ++i) {
      GetArrayString(csgo_weapons, i, temp[i], 64);
    }
  
    //Create SQL Database if it doesn't exist
    Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS wpaints ( steamid varchar(32) NOT NULL, %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', %s varchar(64) NOT NULL DEFAULT '0;-1.0;0', PRIMARY KEY (steamid))", temp[0],temp[1],temp[2],temp[3],temp[4],temp[5],temp[6],temp[7],temp[8],temp[9],temp[10],temp[11],temp[12],temp[13],temp[14],temp[15],temp[16],temp[17],temp[18],temp[19],temp[20],temp[21],temp[22],temp[23],temp[24],temp[25],temp[26],temp[27],temp[28],temp[29],temp[30],temp[31],temp[32],temp[33],temp[34],temp[35],temp[36],temp[37],temp[38],temp[39],temp[40],temp[41],temp[42]);
  
    LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
    SQL_TQuery(db, initDBConn_callback, buffer);
  }
}

public initDBConn_callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
  if (hndl == INVALID_HANDLE) {
    LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
    return;
  }
  
  //Log success
  LogToFileEx(g_sCmdLogPath, "Database connection successful.");
  
  for (new client = 1; client <= MaxClients; ++client) {
    if (IsClientInGame(client)) {
      OnClientPostAdminCheck(client);
    }
  }
}

//Check steamID once client is authorized 
public OnClientPostAdminCheck(client)
{
  if (!IsFakeClient(client))
    CheckSteamID(client);
}


CheckSteamID(client)
{
  decl String:query[255], String:steamid[32];
  GetClientAuthId(client, AuthId_Steam2,  steamid, sizeof(steamid) );
  
  Format(query, sizeof(query), "SELECT * FROM wpaints WHERE steamid = '%s'", steamid);
  LogToFileEx(g_sCmdLogPath, "Query %s", query);
  SQL_TQuery(db, CheckSteamID_callback, query, GetClientUserId(client));
}
 
public CheckSteamID_callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
  new client = GetClientOfUserId(data);
 
  // Make sure the client didn't disconnect while the thread was running
  if (client == 0)
    return;
  
  //Check to see if database connection is up
  if (hndl == INVALID_HANDLE) {
    CheckDB();
    return;
  }
  
  //If no results, this is a new user, add them to database
  if (!SQL_GetRowCount(hndl) || !SQL_FetchRow(hndl)) {
    AddNewClientDB(client);
    return;
  }
  
  //Get entries for this client
  tree[client] = CreateTrie();

  new String:Classname[64];
  new String:temp[64];
  new counter = 1;
  
  for (new i = 0; i < GetArraySize(csgo_weapons); ++i)
  {
    GetArrayString(csgo_weapons, i, Classname, 64);
    SQL_FetchString(hndl, counter, temp, 64);
    
    //temp is in format:  id;wear;seed  , break it apart
    //After this idWearSeed[0] contains id, idWearSeed[1] contains wear level, idWearSeed[2] contains seed
    decl String:idWearSeed[3][14];
    ExplodeString(temp, ";", idWearSeed, sizeof(idWearSeed), sizeof(idWearSeed[]));
    
    //Set ID value in tree
    SetTrieValue(tree[client], Classname, StringToInt(idWearSeed[0]));
    
    //Set wear value in tree
    decl String:Classname_wearname[64];
    Format(Classname_wearname, sizeof(Classname_wearname), "%s%s", Classname, "_wear");
    
    SetTrieValue(tree[client], Classname_wearname, StringToFloat(idWearSeed[1]));
    
    //Set seed value in tree
    decl String:Classname_seed[64];
    Format(Classname_seed, sizeof(Classname_seed), "%s%s", Classname, "_seed");
    
    SetTrieValue(tree[client], Classname_seed, StringToInt(idWearSeed[2]));
    
    ++counter;
  }
  
  isChecked[client] = true;
}

//Adds a new client to the database
AddNewClientDB(client)
{
  //Get SteamID
  decl String:query[255], String:steamid[32];
  GetClientAuthId(client, AuthId_Steam2,  steamid, sizeof(steamid) );
  new userid = GetClientUserId(client);
  
  Format(query, sizeof(query), "INSERT INTO wpaints(steamid) VALUES('%s');", steamid);
  LogToFileEx(g_sCmdLogPath, "Query %s", query);
  SQL_TQuery(db, AddNewClientDB_callback, query, userid);
}

public AddNewClientDB_callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
  if (hndl == INVALID_HANDLE) {
    LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
    CheckDB();
  }
  
  new client = GetClientOfUserId(data);
 
  // Make sure the client didn't disconnect while the thread was running 
  if (client == 0)
    return;
  
  tree[client] = CreateTrie();

  new String:Classname[64];
  
  for (new i = 0; i < GetArraySize(csgo_weapons); ++i) {
    //Set ID value in tree
    GetArrayString(csgo_weapons, i, Classname, 64);
    SetTrieValue(tree[client], Classname, DEFAULT_ID);
    
    //Set wear value in tree
    decl String:Classname_wearname[64];
    Format(Classname_wearname, sizeof(Classname_wearname), "%s%s", Classname, "_wear");
    
    SetTrieValue(tree[client], Classname_wearname, DEFAULT_WEAR);
    
    //Set seed value in tree
    decl String:Classname_seed[64];
    Format(Classname_seed, sizeof(Classname_seed), "%s%s", Classname, "_seed");
    
    SetTrieValue(tree[client], Classname_seed, DEFAULT_SEED);
  }
  
  //Set client as checked
  isChecked[client] = true;
}

public DBGeneral_callback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
  if (hndl == INVALID_HANDLE) {
    LogToFileEx(g_sCmdLogPath, "Query failure: %s", error);
  }
  
  new client = GetClientOfUserId(data);
 
  // Make sure the client didn't disconnect while the thread was running
  if (client == 0)
    return;

  isChecked[client] = true;
}


//Clean up when client disconnects
public OnClientDisconnect(client)
{ 
  isChecked[client] = false;

  if(tree[client] != INVALID_HANDLE)
  {
    ClearTrie(tree[client]);
    CloseHandle(tree[client]);
    tree[client] = INVALID_HANDLE;
  }
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
  MarkNativeAsOptional("IsClientInLastRequest");
  return APLRes_Success;
}

public OnLibraryAdded(const String:name[])
{
  if (StrEqual(name, "hosties"))
  {
    g_hosties = true;
  }
}

public OnLibraryRemoved(const String:name[])
{
  if (StrEqual(name, "hosties"))
  {
    g_hosties = false;
  }
}

public Action:ReloadSkins(client, args)
{  
  ReadPaints();
  ReplyToCommand(client, " \x04[WS]\x01 %T","Weapon skins plugin reloaded", client);
  
  return Plugin_Handled;
}

ShowMenu(client, item)
{
  SetMenuTitle(menuw, "%T", "Menu title", client);
  
  RemoveMenuItem(menuw, 1);
  RemoveMenuItem(menuw, 0);
  decl String:tdisplay[64];
  Format(tdisplay, sizeof(tdisplay), "%T", "Random paint", client);
  InsertMenuItem(menuw, 0, "-1", tdisplay);
  Format(tdisplay, sizeof(tdisplay), "%T", "Default paint", client);
  InsertMenuItem(menuw, 1, "0", tdisplay);
  
  DisplayMenuAtItem(menuw, client, item, 0);
}


ShowSkin(client)
{
  new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  if(weapon < 1 || !IsValidEdict(weapon) || !IsValidEntity(weapon))
  {
    CPrintToChat(client, " {green}[WS]{default} %T", "Paint not found", client);
    return;
  }
  
  new search = GetEntProp(weapon,Prop_Send,"m_nFallbackPaintKit");
  for(new i=1; i<g_paintCount;i++)
  {
    if(search == g_paints[i][index])
    {
      CPrintToChat(client, " {green}[WS]{default} %T", "Paint found", client, g_paints[i][listName]);
      return;
    }
  }
  
  CPrintToChat(client, " {green}[WS]{default} %T", "Paint not found", client);
}

public Action:Tsaytimer(Handle:timer)
{
  saytimer = INVALID_HANDLE;
}

public Action:roundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
  if(g_rtimer == -1) return;
  
  if(rtimer != INVALID_HANDLE)
  {
    KillTimer(rtimer);
    rtimer = INVALID_HANDLE;
  }
  
  rtimer = CreateTimer(1.0*g_rtimer, Rtimer);
}

public Action:Rtimer(Handle:timer)
{
  rtimer = INVALID_HANDLE;
}


public DIDMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{
  if ( action == MenuAction_Select ) 
  {
    WSkin_Selecter(TYPE_MENU, menu, client, itemNum, 0, INVALID_WEAR, DEFAULT_SEED);
  }
}


WSkin_Selecter(type, Handle:menu, client, itemNum, quickNumber, Float:inputWear, inputSeed) 
{
  //Ensure client has been checked
  if (!isChecked[client])
    return;
  
  if(rtimer == INVALID_HANDLE && g_rtimer != -1)
  {
    CPrintToChat(client, " {green}[WS]{default} %T", "You can use this command only the first seconds", client, g_rtimer);
    if(type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }
  if(!IsPlayerAlive(client))
  {
    CPrintToChat(client, " {green}[WS]{default} %t", "You cant use this when you are dead");
    if(type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }
  if(g_hosties && IsClientInLastRequest(client))
  {
    CPrintToChat(client, " {green}[WS]{default} %t", "You cant use this when you are in a lastrequest");
    if(type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }

  new theindex = -1;
  
  if (type == TYPE_MENU) {
    decl String:info[4];
    
    GetMenuItem(menu, itemNum, info, sizeof(info));
    theindex = StringToInt(info);
  }
  else if (type == TYPE_QUICK) {
    theindex = quickNumber;
    
    //Ensure we don't request paint outside of range
    if (theindex < -1 || theindex >= g_paintCount)
    {
      CPrintToChat(client, " {green}[WS]{default} %t", "Index out of Range", g_paintCount - 1);
      return;
    }
  }

  new windex = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
  if(windex < 1)
  {
    CPrintToChat(client, " {green}[WS]{default} %t", "You cant use a paint in this weapon");
    if(type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }
  
  decl String:Classname[64];
  GetEdictClassname(windex, Classname, 64);
  
  if(StrEqual(Classname, "weapon_taser"))
  {
    CPrintToChat(client, " {green}[WS]{default} %t", "You cant use a paint in this weapon");
    if(type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }
  new weaponindex = GetEntProp(windex, Prop_Send, "m_iItemDefinitionIndex");
  if(weaponindex == 42 || weaponindex == 59)
  {
    CPrintToChat(client, " {green}[WS]{default} %t", "You cant use a paint in this weapon");
    if(type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
    return;
  }
  
  if(GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == windex || GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) == windex || GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == windex || (g_c4 && GetPlayerWeaponSlot(client, CS_SLOT_C4) == windex))
  {
    switch (weaponindex)
    {
      case 60: strcopy(Classname, 64, "weapon_m4a1_silencer");
      case 61: strcopy(Classname, 64, "weapon_usp_silencer");
      case 63: strcopy(Classname, 64, "weapon_cz75a");
      case 500: strcopy(Classname, 64, "weapon_bayonet");
      case 506: strcopy(Classname, 64, "weapon_knife_gut");
      case 505: strcopy(Classname, 64, "weapon_knife_flip");
      case 508: strcopy(Classname, 64, "weapon_knife_m9_bayonet");
      case 507: strcopy(Classname, 64, "weapon_knife_karambit");
      case 509: strcopy(Classname, 64, "weapon_knife_tactical");
      case 512: strcopy(Classname, 64, "weapon_knife_falchion");
      case 515: strcopy(Classname, 64, "weapon_knife_butterfly");
      case 516: strcopy(Classname, 64, "weapon_knife_push");
    }
    
    //Save index in trie for client
    SetTrieValue(tree[client], Classname, theindex);
    
    //Save wear
    decl String:Classname_wearname[64];
    Format(Classname_wearname, sizeof(Classname_wearname), "%s%s", Classname, "_wear");
    SetTrieValue(tree[client], Classname_wearname, inputWear);
    
    //Save seed
    decl String:Classname_seed[64];
    Format(Classname_seed, sizeof(Classname_seed), "%s%s", Classname, "_seed");
    SetTrieValue(tree[client], Classname_seed, inputSeed);
    
    //Call paint change plugin with these parameters
    ChangePaint(client, windex, Classname, weaponindex, inputWear, inputSeed);
    FakeClientCommand(client, "use %s", Classname);
    
    if (theindex == 0)
      CPrintToChat(client, " {green}[WS]{default} %t","You have choose your default paint for your", Classname);
    else if (theindex == -1)
      CPrintToChat(client, " {green}[WS]{default} %t","You have choose a random paint for your", Classname);
    else
      CPrintToChat(client, " {green}[WS]{default} %t", "You have choose a weapon", g_paints[theindex][listName], Classname);
  }
  else 
    CPrintToChat(client, " {green}[WS]{default} %t", "You cant use a paint in this weapon");
  
  if(type == TYPE_MENU && g_rmenu) ShowMenu(client, GetMenuSelectionPosition());
}

public Action:RestoreItemID(Handle:timer, Handle:pack)
{
    new entity;
    new m_iItemIDHigh;
    new m_iItemIDLow;
    
    ResetPack(pack);
    entity = EntRefToEntIndex(ReadPackCell(pack));
    m_iItemIDHigh = ReadPackCell(pack);
    m_iItemIDLow = ReadPackCell(pack);
    
    if(entity != INVALID_ENT_REFERENCE)
  {
    SetEntProp(entity,Prop_Send,"m_iItemIDHigh",m_iItemIDHigh);
    SetEntProp(entity,Prop_Send,"m_iItemIDLow",m_iItemIDLow);
  }
}

ReadPaints()
{
  BuildPath(Path_SM, path_paints, sizeof(path_paints), "configs/csgo_wpaints.cfg");
  
  decl Handle:kv;
  g_paintCount = 1;

  kv = CreateKeyValues("Paints");
  FileToKeyValues(kv, path_paints);

  if (!KvGotoFirstSubKey(kv)) {

    SetFailState("CFG File not found: %s", path_paints);
    CloseHandle(kv);
  }
  do {
    KvGetSectionName(kv, g_paints[g_paintCount][listName], 64);
    g_paints[g_paintCount][index] = KvGetNum(kv, "paint", 0);
    g_paints[g_paintCount][wear] = KvGetFloat(kv, "wear", -1.0);
    g_paints[g_paintCount][stattrak] = KvGetNum(kv, "stattrak", -2);
    g_paints[g_paintCount][quality] = KvGetNum(kv, "quality", -2);

    g_paintCount++;
  } while (KvGotoNextKey(kv));
  CloseHandle(kv);
  
  if(menuw != INVALID_HANDLE) CloseHandle(menuw);
  menuw = INVALID_HANDLE;
  
  menuw = CreateMenu(DIDMenuHandler);
  
  decl String:item[4];
  AddMenuItem(menuw, "-1", "Random paint");
  AddMenuItem(menuw, "0", "Default paint");
  
  for (new i=1; i < g_paintCount; ++i) {
    Format(item, 4, "%i", i);
    AddMenuItem(menuw, item, g_paints[i][listName]);
  }
  
  SetMenuExitButton(menuw, true);
}

stock GetReserveAmmo(client, weapon)
{
    new ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if(ammotype == -1) return -1;
    
    return GetEntProp(client, Prop_Send, "m_iAmmo", _, ammotype);
}

stock SetReserveAmmo(client, weapon, weaponEntity, ammo, primaryReserve)
{
  new ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
  if(ammotype == -1) return;
  
  SetEntProp(weaponEntity, Prop_Send, "m_iPrimaryReserveAmmoCount", primaryReserve); 
  SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammotype);
} 

ChangePaint(client, windex, String:Classname[64], weaponindex, Float:inputWear, inputSeed)
{
  new bool:knife = false;
  if(StrContains(Classname, "weapon_knife", false) == 0 || StrContains(Classname, "weapon_bayonet", false) == 0) 
  {
    knife = true;
  }
  
  new ammo, clip, primaryReserve;
  if(!knife)
  {
    ammo = GetReserveAmmo(client, windex);
    clip = GetEntProp(windex, Prop_Send, "m_iClip1");
    primaryReserve = GetEntProp(windex, Prop_Send, "m_iPrimaryReserveAmmoCount");
  }
  RemovePlayerItem(client, windex);
  AcceptEntityInput(windex, "Kill");
  
  new Handle:pack;
  new entity = GivePlayerItem(client, Classname);
  
  if(knife)
  {
    if (weaponindex != 42 && weaponindex != 59) 
      EquipPlayerWeapon(client, entity);
  }
  else
  {
    SetReserveAmmo(client, windex, entity, ammo, primaryReserve);
    SetEntProp(entity, Prop_Send, "m_iClip1", clip);
  }
  
  new theindex;
  GetTrieValue(tree[client], Classname, theindex);  //Get the skin id
  if(theindex == 0) return;

  if(theindex == -1)  //randomised index
    theindex = GetRandomInt(1, g_paintCount-1);
  
  new m_iItemIDHigh = GetEntProp(entity, Prop_Send, "m_iItemIDHigh");
  new m_iItemIDLow = GetEntProp(entity, Prop_Send, "m_iItemIDLow");

  SetEntProp(entity,Prop_Send,"m_iItemIDLow",2048);
  SetEntProp(entity,Prop_Send,"m_iItemIDHigh",0);

  //Skin
  SetEntProp(entity,Prop_Send,"m_nFallbackPaintKit",g_paints[theindex][index]); //set paint texture
  
  //Get suitable value for inputWear
  if (inputWear == INVALID_WEAR) {
    if (g_paints[theindex][wear] >= 0.0)
      inputWear = g_paints[theindex][wear];
    else
      inputWear = 0.0; //default
  }
  
  //Set wear
  SetEntPropFloat(entity,Prop_Send, "m_flFallbackWear", inputWear);
  
  //Seed
  SetEntProp(entity, Prop_Send, "m_nFallbackSeed", inputSeed);
  
  //Stattrak
  if(g_paints[theindex][stattrak] != -2) SetEntProp(entity,Prop_Send,"m_nFallbackStatTrak",g_paints[theindex][stattrak]);
  
  //Quality
  if(g_paints[theindex][quality] != -2) SetEntProp(entity,Prop_Send,"m_iEntityQuality",g_paints[theindex][quality]);
  
  //If knife, auto add star
  if (knife)
    SetEntProp(entity, Prop_Send, "m_iEntityQuality", 3); //3 is for the star
  
  //Write changes to datebase (via UPDATE query)
  decl String:steamid[32];
  GetClientAuthId(client, AuthId_Steam2,  steamid, sizeof(steamid) );
  
  decl String:buffer[1024];
  Format(buffer, sizeof(buffer), "UPDATE wpaints SET %s = '%d;%f;%d' WHERE steamid = '%s';", Classname, theindex, inputWear, inputSeed, steamid); 
  LogToFileEx(g_sCmdLogPath, "Query %s", buffer);
  SQL_TQuery(db, DBGeneral_callback, buffer, GetClientUserId(client));
  
  CreateDataTimer(0.2, RestoreItemID, pack);
  WritePackCell(pack, EntIndexToEntRef(entity));
  WritePackCell(pack, m_iItemIDHigh);
  WritePackCell(pack, m_iItemIDLow);
}

public OnClientPutInServer(client)
{
  if(!IsFakeClient(client))
    SDKHook(client, SDKHook_WeaponEquipPost, OnPostWeaponEquip);
}

public Action:OnPostWeaponEquip(client, weapon)
{
  new Handle:pack;
  CreateDataTimer(0.0, Last, pack);
  WritePackCell(pack,EntIndexToEntRef(weapon));
  WritePackCell(pack, client);
}

public Action:Last(Handle:timer, Handle:pack)
{
  new weapon;
  new client
    
  ResetPack(pack);
  weapon = EntRefToEntIndex(ReadPackCell(pack));
  client = ReadPackCell(pack);
    
  if (weapon == INVALID_ENT_REFERENCE || !IsClientInGame(client) || !IsPlayerAlive(client) || (g_hosties && IsClientInLastRequest(client))) {
   return; 
  }
  
  if(weapon < 1 || !IsValidEdict(weapon) || !IsValidEntity(weapon)) {
    return;
  }
  
  if ( GetEntProp(weapon, Prop_Send, "m_hPrevOwner") > 0 || (GetEntProp(weapon, Prop_Send, "m_iItemIDHigh") == 0 && GetEntProp(weapon, Prop_Send, "m_iItemIDLow") == 2048)) {
    return;
  }
    
  decl String:Classname[64];
  GetEdictClassname(weapon, Classname, 64);
  if(StrEqual(Classname, "weapon_taser"))
  {
    return;
  }
  new weaponindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
  if(weaponindex == 42 || weaponindex == 59)
  {
    return;
  }
  if(GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) == weapon || GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) == weapon || GetPlayerWeaponSlot(client, CS_SLOT_KNIFE) == weapon || (g_c4 && GetPlayerWeaponSlot(client, CS_SLOT_C4) == weapon))
  {
    switch (weaponindex)
    {
      case 60: strcopy(Classname, 64, "weapon_m4a1_silencer");
      case 61: strcopy(Classname, 64, "weapon_usp_silencer");
      case 63: strcopy(Classname, 64, "weapon_cz75a");
      case 500: strcopy(Classname, 64, "weapon_bayonet");
      case 506: strcopy(Classname, 64, "weapon_knife_gut");
      case 505: strcopy(Classname, 64, "weapon_knife_flip");
      case 508: strcopy(Classname, 64, "weapon_knife_m9_bayonet");
      case 507: strcopy(Classname, 64, "weapon_knife_karambit");
      case 509: strcopy(Classname, 64, "weapon_knife_tactical");
      case 512: strcopy(Classname, 64, "weapon_knife_falchion");
      case 515: strcopy(Classname, 64, "weapon_knife_butterfly");
      case 516: strcopy(Classname, 64, "weapon_knife_push");
    }
    
    new value = 0;  //get the skin id
    
    GetTrieValue(tree[client], Classname, value);
    if(value == 0) //No skin for this gun
      return;
    
    //Get stored wear value
    new Float:storedWear = INVALID_WEAR;
    
    decl String:Classname_wearname[64];
    Format(Classname_wearname, sizeof(Classname_wearname), "%s%s", Classname, "_wear");
    GetTrieValue(tree[client], Classname_wearname, storedWear);
    
    //Get stored seed value
    new storedSeed = DEFAULT_SEED;
    
    decl String:Classname_seed[64];
    Format(Classname_seed, sizeof(Classname_seed), "%s%s", Classname, "_seed");
    GetTrieValue(tree[client], Classname_seed, storedSeed);
    
    //Change paint to proper skin with proper wear
    ChangePaint(client, weapon, Classname, weaponindex, storedWear, storedSeed);
  }
}