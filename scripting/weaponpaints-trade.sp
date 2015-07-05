#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <clientprefs>
#include <multicolors>

#undef REQUIRE_PLUGIN
#include <lastrequest>

#define MAX_PAINTS 800
#define TYPE_MENU 0
#define TYPE_QUICK 1
#define INVALID_WEAR -1.0

enum Listing
{
  String:listName[64],
  index,
  Float:wear,
  stattrak,
  quality
}

new Handle:h_cookie_SkinWear1 = INVALID_HANDLE;
new Handle:h_cookie_SkinWear2 = INVALID_HANDLE;
new Handle:h_cookie_SkinWear3 = INVALID_HANDLE;
new Handle:h_cookie_SkinWear4 = INVALID_HANDLE;
new Handle:h_cookie_SkinWear5 = INVALID_HANDLE;
new Handle:h_cookie_SkinWear6 = INVALID_HANDLE;
new Handle:h_cookie_SkinWear7 = INVALID_HANDLE;

new Handle:menuw = INVALID_HANDLE;
new g_paints[MAX_PAINTS][Listing];
new g_paintCount = 0;
new String:path_paints[PLATFORM_MAX_PATH];

new bool:g_hosties = false;

new bool:g_c4;
new Handle:cvar_c4;

#define VERSION "2.01 (Trade Lounge)"

new Handle:tree[MAXPLAYERS+1];

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
  name = "CS:GO Weapon Skins (!ws) Reloaded",
  author = "Originally by Franc1sco franug, rewritten and updated by Invex | Byte",
  description = "Allows you to apply skin textures to CSGO guns.",
  version = VERSION,
  url = "http://www.invexgaming.com.au"
};

public OnPluginStart()
{
  LoadTranslations ("weaponpaints-trade.phrases.txt");

  h_cookie_SkinWear1 = RegClientCookie("WS_Paints_part_1", "WS_Paints_part_1", CookieAccess_Private);
  h_cookie_SkinWear2 = RegClientCookie("WS_Paints_part_2", "WS_Paints_part_2", CookieAccess_Private);
  h_cookie_SkinWear3 = RegClientCookie("WS_Paints_part_3", "WS_Paints_part_3", CookieAccess_Private);
  h_cookie_SkinWear4 = RegClientCookie("WS_Paints_part_4", "WS_Paints_part_4", CookieAccess_Private);
  h_cookie_SkinWear5 = RegClientCookie("WS_Paints_part_5", "WS_Paints_part_5", CookieAccess_Private);
  h_cookie_SkinWear6 = RegClientCookie("WS_Paints_part_6", "WS_Paints_part_6", CookieAccess_Private);
  h_cookie_SkinWear7 = RegClientCookie("WS_Paints_part_7", "WS_Paints_part_7", CookieAccess_Private);
  
  CreateConVar("sm_ws_version", VERSION, "", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);
  
  HookEvent("round_start", roundStart);

  //RegConsoleCmd("buyammo1", GetSkins); 

  //Commands and command aliases
  RegConsoleCmd("ws", Command_QuickSelect_WSkin);
  RegConsoleCmd("wskin", Command_QuickSelect_WSkin);
  RegConsoleCmd("wskins", Command_QuickSelect_WSkin);
  RegConsoleCmd("pk", Command_QuickSelect_WSkin);
  RegConsoleCmd("paints", Command_QuickSelect_WSkin);
  
  RegAdminCmd("sm_reloadws", ReloadSkins, ADMFLAG_ROOT);

  for (new client = 1; client <= MaxClients; client++)
  {
    if (!IsClientInGame(client))
      continue;
      
    OnClientPutInServer(client);
    
    if(!AreClientCookiesCached(client))
      continue;
      
    OnClientCookiesCached(client);
  }
  
  cvar_c4 = CreateConVar("sm_ws_c4", "1", "Enable or disable that people can apply paints to the C4. 1 = enabled, 0 = disabled");
  cvar_saytimer = CreateConVar("sm_ws_saytimer", "10", "Time in seconds for block that show the plugin commands in chat when someone type a command. -1.0 = never show the commands in chat");
  cvar_rtimer = CreateConVar("sm_ws_roundtimer", "-1.0", "Time in seconds roundstart for can use the commands for change the paints. -1.0 = always can use the command");
  cvar_rmenu = CreateConVar("sm_ws_rmenu", "1", "Re-open the menu when you select a option. 1 = enabled, 0 = disabled.");
  
  g_c4 = GetConVarBool(cvar_c4);
  g_saytimer = GetConVarInt(cvar_saytimer);
  g_rtimer = GetConVarInt(cvar_rtimer);
  g_rmenu = GetConVarBool(cvar_rmenu);
  
  HookConVarChange(cvar_c4, OnConVarChanged);
  HookConVarChange(cvar_saytimer, OnConVarChanged);
  HookConVarChange(cvar_rtimer, OnConVarChanged);
  HookConVarChange(cvar_rmenu, OnConVarChanged);
  
  ReadPaints();
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

public OnClientCookiesCached(client)
{
  //Make all the cookies strings we need
  decl String:cookie1[100], String:cookie2[100],String:cookie3[100], String:cookie4[100],
       String:cookie5[100], String:cookie6[100],String:cookie7[100];
  
  //Now lets get the cookies!
  GetClientCookie(client, h_cookie_SkinWear1, cookie1, sizeof(cookie1));
  GetClientCookie(client, h_cookie_SkinWear2, cookie2, sizeof(cookie2));
  GetClientCookie(client, h_cookie_SkinWear3, cookie3, sizeof(cookie3));
  GetClientCookie(client, h_cookie_SkinWear4, cookie4, sizeof(cookie4));
  GetClientCookie(client, h_cookie_SkinWear5, cookie5, sizeof(cookie5));
  GetClientCookie(client, h_cookie_SkinWear6, cookie6, sizeof(cookie6));
  GetClientCookie(client, h_cookie_SkinWear7, cookie7, sizeof(cookie7));
  
  //If we got no cookies, lets set up some initial cookies
  //Our cookies are in form X|Y where X is a 4 chars and represents a number, Y is upto 9 chars and represents a float
  if(strlen(cookie1) < 14) Format(cookie1, sizeof(cookie1), "0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;");
  if(strlen(cookie2) < 14) Format(cookie2, sizeof(cookie2), "0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;");
  if(strlen(cookie3) < 14) Format(cookie3, sizeof(cookie3), "0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;");
  if(strlen(cookie4) < 14) Format(cookie4, sizeof(cookie4), "0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;");
  if(strlen(cookie5) < 14) Format(cookie5, sizeof(cookie5), "0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;");
  if(strlen(cookie6) < 14) Format(cookie6, sizeof(cookie6), "0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;");
  if(strlen(cookie7) < 14) Format(cookie7, sizeof(cookie7), "0|-1.0;0|-1.0;0|-1.0;0|-1.0;0|-1.0;"); //1 less value
  
  CreateTree(client, cookie1, cookie2, cookie3, cookie4, cookie5, cookie6, cookie7);
}

public OnClientDisconnect(client)
{  
  if(AreClientCookiesCached(client))
  {
    SaveCookies(client);
  }
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
  SetMenuTitle(menuw, "%T","Menu title", client);
  
  RemoveMenuItem(menuw, 1);
  RemoveMenuItem(menuw, 0);
  decl String:tdisplay[64];
  Format(tdisplay, sizeof(tdisplay), "%T", "Random paint", client);
  InsertMenuItem(menuw, 0, "-1", tdisplay);
  Format(tdisplay, sizeof(tdisplay), "%T", "Default paint", client);
  InsertMenuItem(menuw, 1, "0", tdisplay);
  
  DisplayMenuAtItem(menuw, client, item, 0);
}

public Action:GetSkins(client, args)
{  
  ShowMenu(client, 0);
  
  return Plugin_Handled;
}

public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
  if(StrEqual(sArgs, "!ss", false) || StrEqual(sArgs, "!showskin", false))
  {
    ShowSkin(client);
    
    if(saytimer != INVALID_HANDLE || g_saytimer == -1) return Plugin_Handled;
    saytimer = CreateTimer(1.0*g_saytimer, Tsaytimer);
    return Plugin_Continue;
  }

  return Plugin_Continue;
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

/*
 * This command will delegate to other commands based on arguments provided.
 * So it will call function to show menu if no commands etc. 
*/
public Action:Command_QuickSelect_WSkin(client, args) 
{

  //Get quickNumber
  new String:indexStr[6];
  GetCmdArgString(indexStr, sizeof(indexStr));
  new quickNumber = StringToInt(indexStr);

  //Show menu if no args, otherwise perform quick select
  new Float:inputWear = INVALID_WEAR;
  
  //Show menu
  if (args == 0) {
    ShowMenu(client, 0);

    if(saytimer != INVALID_HANDLE || g_saytimer == -1) return Plugin_Handled;
    saytimer = CreateTimer(1.0*g_saytimer, Tsaytimer);
    return Plugin_Handled;
  }
  else if (args == 2) { //Wear provided
    new String:buffer[6];
    GetCmdArg(2, buffer, sizeof(buffer));
    inputWear = StringToFloat(buffer);
    
    if (inputWear < 0.0 || inputWear > 1.0) { //check for valid wear
      CPrintToChat(client, " {green}[WS]{default} %t", "Wear Value Wrong");
      return Plugin_Handled;
    }
  }
  else if (args > 2){
    return Plugin_Handled;
  }

  WSkin_Selecter(TYPE_QUICK, INVALID_HANDLE, client, 0, quickNumber, inputWear);
  
  return Plugin_Handled;
}


public DIDMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{
  if ( action == MenuAction_Select ) 
  {
    WSkin_Selecter(TYPE_MENU, menu, client, itemNum, 0, INVALID_WEAR);
  }
}


WSkin_Selecter(type, Handle:menu, client, itemNum, quickNumber, Float:inputWear) 
{
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
    }
    
    SetTrieValue(tree[client], Classname, theindex); //save index in trie for client
    
    decl String:Classname_wearname[64]; //save wear in trie for client
    Format(Classname_wearname, sizeof(Classname_wearname), "%s%s", Classname, "_wear");
    SetTrieValue(tree[client], Classname_wearname, inputWear);
    
    ChangePaint(client, windex, Classname, weaponindex, inputWear);
    FakeClientCommand(client, "use %s", Classname);
    if(theindex == 0) CPrintToChat(client, " {green}[WS]{default} %t","You have choose your default paint for your", Classname);
    else if(theindex == -1) CPrintToChat(client, " {green}[WS]{default} %t","You have choose a random paint for your", Classname);
    else CPrintToChat(client, " {green}[WS]{default} %t", "You have choose a weapon", g_paints[theindex][listName], Classname);
  }
  else CPrintToChat(client, " {green}[WS]{default} %t", "You cant use a paint in this weapon");
  
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
  
  // TROLLING
  SetMenuTitle(menuw, "( ͡° ͜ʖ ͡°)");
  decl String:item[4];
  AddMenuItem(menuw, "-1", "Random paint");
  AddMenuItem(menuw, "0", "Default paint"); 
  // FORGET THIS
  
  for (new i=1; i<g_paintCount; ++i) {
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

ChangePaint(client, windex, String:Classname[64], weaponindex, Float:inputWear)
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

  SetEntProp(entity,Prop_Send,"m_nFallbackPaintKit",g_paints[theindex][index]); //set paint texture
  
  if (inputWear != INVALID_WEAR)
    SetEntPropFloat(entity,Prop_Send,"m_flFallbackWear", inputWear);
  else if (g_paints[theindex][wear] >= 0.0)
    SetEntPropFloat(entity,Prop_Send,"m_flFallbackWear",g_paints[theindex][wear]);
  
  if(g_paints[theindex][stattrak] != -2) SetEntProp(entity,Prop_Send,"m_nFallbackStatTrak",g_paints[theindex][stattrak]);
  if(g_paints[theindex][quality] != -2) SetEntProp(entity,Prop_Send,"m_iEntityQuality",g_paints[theindex][quality]);
  
  //If knife, add star
  if (knife)
    SetEntProp(entity, Prop_Send, "m_iEntityQuality", 3); //3 is for the star
  

  CreateDataTimer(0.2, RestoreItemID, pack);
  WritePackCell(pack,EntIndexToEntRef(entity));
  WritePackCell(pack,m_iItemIDHigh);
  WritePackCell(pack,m_iItemIDLow);
}

public OnClientPutInServer(client)
{
  if(!IsFakeClient(client)) SDKHook(client, SDKHook_WeaponEquipPost, OnPostWeaponEquip);
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
    
    //Change paint to proper skin with proper wear
    ChangePaint(client, weapon, Classname, weaponindex, storedWear);
  }
}

CreateTree(client, String:cookie1[100],String:cookie2[100],String:cookie3[100],String:cookie4[100],String:cookie5[100],String:cookie6[100],String:cookie7[100])
{
  tree[client] = CreateTrie();

  //Here me construct the trie using values from the cookie
  //We break up each cookie and load in the values
  
  decl String:skinWearPair[2][9]; //will hold our skin code|wear float pairs.
  
  //Cookie 1
  decl String:splitcookie1[6][14];
  ExplodeString(cookie1, ";", splitcookie1, sizeof(splitcookie1), sizeof(splitcookie1[]));
  
  ExplodeString(splitcookie1[0], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_negev", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_negev_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie1[1], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_m249", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_m249_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie1[2], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_bizon", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_bizon_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie1[3], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_p90", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_p90_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie1[4], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_scar20", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_scar20_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie1[5], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_g3sg1", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_g3sg1_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  //Cookie 2
  decl String:splitcookie2[6][14];
  ExplodeString(cookie2, ";", splitcookie2, sizeof(splitcookie2), sizeof(splitcookie2[]));
  
  ExplodeString(splitcookie2[0], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_m4a1", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_m4a1_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie2[1], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_m4a1_silencer", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_m4a1_silencer_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie2[2], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_ak47", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_ak47_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie2[3], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_aug", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_aug_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie2[4], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_galilar", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_galilar_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie2[5], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_awp", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_awp_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  //Cookie 3
  decl String:splitcookie3[6][14];
  ExplodeString(cookie3, ";", splitcookie3, sizeof(splitcookie3), sizeof(splitcookie3[]));
  
  ExplodeString(splitcookie3[0], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_sg556", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_sg556_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie3[1], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_ump45", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_ump45_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie3[2], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_mp7", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_mp7_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie3[3], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_famas", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_famas_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie3[4], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_mp9", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_mp9_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie3[5], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_mac10", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_mac10_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  //Cookie 4
  decl String:splitcookie4[6][14];
  ExplodeString(cookie4, ";", splitcookie4, sizeof(splitcookie4), sizeof(splitcookie4[]));
  
  ExplodeString(splitcookie4[0], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_ssg08", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_ssg08_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie4[1], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_nova", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_nova_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie4[2], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_xm1014", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_xm1014_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie4[3], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_sawedoff", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_sawedoff_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie4[4], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_mag7", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_mag7_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie4[5], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_elite", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_elite_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  //Cookie 5
  decl String:splitcookie5[6][14];
  ExplodeString(cookie5, ";", splitcookie5, sizeof(splitcookie5), sizeof(splitcookie5[]));
  
  ExplodeString(splitcookie5[0], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_deagle", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_deagle_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie5[1], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_tec9", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_tec9_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie5[2], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_fiveseven", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_fiveseven_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie5[3], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_cz75a", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_cz75a_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie5[4], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_glock", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_glock_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie5[5], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_usp_silencer", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_usp_silencer_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  //Cookie 6
  decl String:splitcookie6[6][14];
  ExplodeString(cookie6, ";", splitcookie6, sizeof(splitcookie6), sizeof(splitcookie6[]));
  
  ExplodeString(splitcookie6[0], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_p250", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_p250_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie6[1], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_hkp2000", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_hkp2000_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie6[2], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_bayonet", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_bayonet_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie6[3], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_knife_gut", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_knife_gut_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie6[4], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_knife_flip", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_knife_flip_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie6[5], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_knife_m9_bayonet", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_knife_m9_bayonet_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  //Cookie 7
  decl String:splitcookie7[5][14]; //Short by 1 as exhausted weapons
  ExplodeString(cookie7, ";", splitcookie7, sizeof(splitcookie7), sizeof(splitcookie7[]));
  
  ExplodeString(splitcookie7[0], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_knife_karambit", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_knife_karambit_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie7[1], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_knife_tactical", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_knife_tactical_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie7[2], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_knife_falchion", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_knife_falchion_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie7[3], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_knife_butterfly", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_knife_butterfly_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
  ExplodeString(splitcookie7[4], "|", skinWearPair, sizeof(skinWearPair), sizeof(skinWearPair[]));
  SetTrieValue(tree[client], "weapon_c4", StringToInt(skinWearPair[0]));
  SetTrieValue(tree[client], "weapon_c4_wear", StringToFloat(skinWearPair[1]));
  Format(skinWearPair[0], sizeof(skinWearPair[]), "%s", "");
  Format(skinWearPair[1], sizeof(skinWearPair[]), "%s", "");
  
}

SaveCookies(client)
{
  decl String:cookie1[100],String:cookie2[100],String:cookie3[100],String:cookie4[100],String:cookie5[100],String:cookie6[100],String:cookie7[100];
  
  new value;
  new Float:floatvalue;
  
  //Cookie 1
  GetTrieValue(tree[client], "weapon_negev", value);
  GetTrieValue(tree[client], "weapon_negev_wear", floatvalue);
  Format(cookie1, sizeof(cookie1), "%i|%f", value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_m249", value);
  GetTrieValue(tree[client], "weapon_m249_wear", floatvalue);
  Format(cookie1, sizeof(cookie1), "%s;%i|%f", cookie1, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_bizon", value);
  GetTrieValue(tree[client], "weapon_bizon_wear", floatvalue);
  Format(cookie1, sizeof(cookie1), "%s;%i|%f", cookie1, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_p90", value);
  GetTrieValue(tree[client], "weapon_p90_wear", floatvalue);
  Format(cookie1, sizeof(cookie1), "%s;%i|%f", cookie1, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_scar20", value);
  GetTrieValue(tree[client], "weapon_scar20_wear", floatvalue);
  Format(cookie1, sizeof(cookie1), "%s;%i|%f", cookie1, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_g3sg1", value);
  GetTrieValue(tree[client], "weapon_g3sg1_wear", floatvalue);
  Format(cookie1, sizeof(cookie1), "%s;%i|%f", cookie1, value, floatvalue);
  
  //Cookie 2
  GetTrieValue(tree[client], "weapon_m4a1", value);
  GetTrieValue(tree[client], "weapon_m4a1_wear", floatvalue);
  Format(cookie2, sizeof(cookie2), "%i|%f", value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_m4a1_silencer", value);
  GetTrieValue(tree[client], "weapon_m4a1_silencer_wear", floatvalue);
  Format(cookie2, sizeof(cookie2), "%s;%i|%f", cookie2, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_ak47", value);
  GetTrieValue(tree[client], "weapon_ak47_wear", floatvalue);
  Format(cookie2, sizeof(cookie2), "%s;%i|%f", cookie2, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_aug", value);
  GetTrieValue(tree[client], "weapon_aug_wear", floatvalue);
  Format(cookie2, sizeof(cookie2), "%s;%i|%f", cookie2, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_galilar", value);
  GetTrieValue(tree[client], "weapon_galilar_wear", floatvalue);
  Format(cookie2, sizeof(cookie2), "%s;%i|%f", cookie2, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_awp", value);
  GetTrieValue(tree[client], "weapon_awp_wear", floatvalue);
  Format(cookie2, sizeof(cookie2), "%s;%i|%f", cookie2, value, floatvalue);
  
  //Cookie 3
  GetTrieValue(tree[client], "weapon_sg556", value);
  GetTrieValue(tree[client], "weapon_sg556_wear", floatvalue);
  Format(cookie3, sizeof(cookie3), "%i|%f", value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_ump45", value);
  GetTrieValue(tree[client], "weapon_ump45_wear", floatvalue);
  Format(cookie3, sizeof(cookie3), "%s;%i|%f", cookie3, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_mp7", value);
  GetTrieValue(tree[client], "weapon_mp7_wear", floatvalue);
  Format(cookie3, sizeof(cookie3), "%s;%i|%f", cookie3, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_famas", value);
  GetTrieValue(tree[client], "weapon_famas_wear", floatvalue);
  Format(cookie3, sizeof(cookie3), "%s;%i|%f", cookie3, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_mp9", value);
  GetTrieValue(tree[client], "weapon_mp9_wear", floatvalue);
  Format(cookie3, sizeof(cookie3), "%s;%i|%f", cookie3, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_mac10", value);
  GetTrieValue(tree[client], "weapon_mac10_wear", floatvalue);
  Format(cookie3, sizeof(cookie3), "%s;%i|%f", cookie3, value, floatvalue);
  
  //Cookie 4
  GetTrieValue(tree[client], "weapon_ssg08", value);
  GetTrieValue(tree[client], "weapon_ssg08_wear", floatvalue);
  Format(cookie4, sizeof(cookie4), "%i|%f", value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_nova", value);
  GetTrieValue(tree[client], "weapon_nova_wear", floatvalue);
  Format(cookie4, sizeof(cookie4), "%s;%i|%f", cookie4, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_xm1014", value);
  GetTrieValue(tree[client], "weapon_xm1014_wear", floatvalue);
  Format(cookie4, sizeof(cookie4), "%s;%i|%f", cookie4, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_sawedoff", value);
  GetTrieValue(tree[client], "weapon_sawedoff_wear", floatvalue);
  Format(cookie4, sizeof(cookie4), "%s;%i|%f", cookie4, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_mag7", value);
  GetTrieValue(tree[client], "weapon_mag7_wear", floatvalue);
  Format(cookie4, sizeof(cookie4), "%s;%i|%f", cookie4, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_elite", value);
  GetTrieValue(tree[client], "weapon_elite_wear", floatvalue);
  Format(cookie4, sizeof(cookie4), "%s;%i|%f", cookie4, value, floatvalue);
  
  //Cookie 5
  GetTrieValue(tree[client], "weapon_deagle", value);
  GetTrieValue(tree[client], "weapon_deagle_wear", floatvalue);
  Format(cookie5, sizeof(cookie5), "%i|%f", value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_tec9", value);
  GetTrieValue(tree[client], "weapon_tec9_wear", floatvalue);
  Format(cookie5, sizeof(cookie5), "%s;%i|%f", cookie5, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_fiveseven", value);
  GetTrieValue(tree[client], "weapon_fiveseven_wear", floatvalue);
  Format(cookie5, sizeof(cookie5), "%s;%i|%f", cookie5, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_cz75a", value);
  GetTrieValue(tree[client], "weapon_cz75a_wear", floatvalue);
  Format(cookie5, sizeof(cookie5), "%s;%i|%f", cookie5, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_glock", value);
  GetTrieValue(tree[client], "weapon_glock_wear", floatvalue);
  Format(cookie5, sizeof(cookie5), "%s;%i|%f", cookie5, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_usp_silencer", value);
  GetTrieValue(tree[client], "weapon_usp_silencer_wear", floatvalue);
  Format(cookie5, sizeof(cookie5), "%s;%i|%f", cookie5, value, floatvalue);
  
  //Cookie 6
  GetTrieValue(tree[client], "weapon_p250", value);
  GetTrieValue(tree[client], "weapon_p250_wear", floatvalue);
  Format(cookie6, sizeof(cookie6), "%i|%f", value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_hkp2000", value);
  GetTrieValue(tree[client], "weapon_hkp2000_wear", floatvalue);
  Format(cookie6, sizeof(cookie6), "%s;%i|%f", cookie6, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_bayonet", value);
  GetTrieValue(tree[client], "weapon_bayonet_wear", floatvalue);
  Format(cookie6, sizeof(cookie6), "%s;%i|%f", cookie6, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_knife_gut", value);
  GetTrieValue(tree[client], "weapon_knife_gut_wear", floatvalue);
  Format(cookie6, sizeof(cookie6), "%s;%i|%f", cookie6, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_knife_flip", value);
  GetTrieValue(tree[client], "weapon_knife_flip_wear", floatvalue);
  Format(cookie6, sizeof(cookie6), "%s;%i|%f", cookie6, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_knife_m9_bayonet", value);
  GetTrieValue(tree[client], "weapon_knife_m9_bayonet_wear", floatvalue);
  Format(cookie6, sizeof(cookie6), "%s;%i|%f", cookie6, value, floatvalue);
  
  //Cookie 7 (only has 5 entries)
  GetTrieValue(tree[client], "weapon_knife_karambit", value);
  GetTrieValue(tree[client], "weapon_knife_karambit_wear", floatvalue);
  Format(cookie7, sizeof(cookie7), "%i|%f", value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_knife_tactical", value);
  GetTrieValue(tree[client], "weapon_knife_tactical_wear", floatvalue);
  Format(cookie7, sizeof(cookie7), "%s;%i|%f", cookie7, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_knife_falchion", value);
  GetTrieValue(tree[client], "weapon_knife_falchion_wear", floatvalue);
  Format(cookie7, sizeof(cookie7), "%s;%i|%f", cookie7, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_knife_butterfly", value);
  GetTrieValue(tree[client], "weapon_knife_butterfly_wear", floatvalue);
  Format(cookie7, sizeof(cookie7), "%s;%i|%f", cookie7, value, floatvalue);
  
  GetTrieValue(tree[client], "weapon_c4", value);
  GetTrieValue(tree[client], "weapon_c4_wear", floatvalue);
  Format(cookie7, sizeof(cookie7), "%s;%i|%f", cookie7, value, floatvalue);
  
  
  //Set client cookies
  SetClientCookie(client, h_cookie_SkinWear1, cookie1);
  SetClientCookie(client, h_cookie_SkinWear2, cookie2);
  SetClientCookie(client, h_cookie_SkinWear3, cookie3);
  SetClientCookie(client, h_cookie_SkinWear4, cookie4);
  SetClientCookie(client, h_cookie_SkinWear5, cookie5);
  SetClientCookie(client, h_cookie_SkinWear6, cookie6);
  SetClientCookie(client, h_cookie_SkinWear7, cookie7);
  
}