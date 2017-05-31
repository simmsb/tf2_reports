/*

TF2 reports pusher, written by nitros: [https://github.com/nitros12]

*/

#pragma semicolon 1

#include <sourcemod>
#include <SteamWorks>
#include <smjansson>

#define PLUGIN_VERSION "0.0.1"
#define MAX_MESSAGE_LEN 256

#define REPORT_MESSAGE "@here %L has reported players: %s with reason %s\n"
#define REPORT_MESSAGE_LEN 52

#define MAX_REQUEST_LENGTH 16384

ConVar g_Webook_URL;

public Plugin myinfo = {
  name = "TF2Discord reports",
  author = "Nitros",
  description = "Pushes tf2 reports to discord",
  version = PLUGIN_VERSION,
  url = "ben@bensimms.moe"
}

public void OnPluginStart() {
  LoadTranslations("common.phrases");
  RegConsoleCmd("report", ReportCmd, "Report a player with a message");

  g_Webook_URL = CreateConVar("sm_report_webhook", "", "Webhook to send reports to", FCVAR_PROTECTED,
               false, _, false, _);

  AutoExecConfig(true, "discord_reports");
}

public Action ReportCmd(int client, int argc) {
  if (argc < 2) {
    ReplyToCommand(client, "[SM] Usage: report <#userid|name> <message>");
    return Plugin_Handled;
  }

  char player[MAX_NAME_LENGTH],
      message[MAX_MESSAGE_LEN];
  GetCmdArg(1, player, sizeof(player));
  GetCmdArgString(message, sizeof(message));

  char target_name[MAX_TARGET_LENGTH];
  int target_list[MAXPLAYERS], target_count;
  bool single_player;

  target_count = ProcessTargetString(
    player,
    client,
    target_list,
    MAXPLAYERS,
    (COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_BOTS),
    target_name,
    sizeof(target_name),
    single_player
  );

  int id_strings_size = target_count * 256 + 20;
  char[] id_strings = new char[id_strings_size];
  for (int i=0; i<target_count; i++) {
    Format(id_strings, id_strings_size, "%s, %L", id_strings, target_list[i]);
  } // loop through turning into a string of comma seperated ids.

  int report_message_size = target_count * 256 + MAX_TARGET_LENGTH + REPORT_MESSAGE_LEN + 40;
  char[] report_message = new char[report_message_size];
  Format(report_message, report_message_size, REPORT_MESSAGE, client, id_strings, message);
  // Create format message

  send_report(report_message);
  return Plugin_Handled;
}

void send_report(const char[] message) {
  char url[500];
  char json_dump_data[MAX_REQUEST_LENGTH];
  json_dump_data[0] = '\0';
  GetConVarString(g_Webook_URL, url, sizeof(url));

  Handle json = json_object();
  if (json == INVALID_HANDLE) {
    LogToGame("Error could not create JSON object");
    return;
  }
  json_object_set_new(json, "content", json_string(message));

  json_dump(json, json_dump_data, MAX_REQUEST_LENGTH, 0, true);

  Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
  if (request == INVALID_HANDLE) {
    LogToGame("Error: Could not create http request");
    return;
  }
  SteamWorks_SetHTTPRequestRawPostBody(request, "application/json; charset=UTF-8", json_dump_data, strlen(json_dump_data));
  SteamWorks_SendHTTPRequest(request);

  delete json;
  delete request;
}
