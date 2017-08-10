/*

TF2 reports pusher, written by nitros: [https://github.com/nitros12]

*/
#include <sourcemod>
#include <SteamWorks>
#include <smjansson>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "0.2.0"

#define MAX_REQUEST_LENGTH 4096
#define MAX_MESSAGE_LEN 512

ConVar Webhook_Url;
ConVar Echo_Chat;

public Plugin myinfo = {
  name = "TF2Discord reports",
  author = "Nitros",
  description = "Pushes tf2 reports to discord",
  version = PLUGIN_VERSION,
  url = "ben@bensimms.moe"
};

public void OnPluginStart() {
  LoadTranslations("common.phrases");
  RegConsoleCmd("report", ReportCmd, "Send a report message.");
  RegAdminCmd("echo_chat_on", EchoChatOn, ADMFLAG_KICK, "Turn on chat echo.");
  RegAdminCmd("echo_chat_off", EchoChatOff, ADMFLAG_KICK, "Turn off chat echo.");
  Webhook_Url = CreateConVar("sm_report_webhook", "", "Webhook to send reports to", FCVAR_PROTECTED,
               false, _, false, _);
  Echo_Chat = CreateConVar("sm_report_echo", "0", "Enable chat echo", FCVAR_PROTECTED,
                           true, 0.0, true, 1.0);
  AutoExecConfig(true, "discord_reports");
  AddCommandListener(EchoChat, "say");
}

public Action EchoChatOn(int client, int argc) {
  SetConVarBool(Echo_Chat, true, false);
  PrintToChat(client, "Enabled chat echo!");
  return Plugin_Handled;
}

public Action EchoChatOff(int client, int argc) {
  SetConVarBool(Echo_Chat, false);
  PrintToChat(client, "Disabled chat echo!");
  return Plugin_Handled;
}

public Action EchoChat(int client, const char[] command, int argc) {
  if (!GetConVarBool(Echo_Chat)) return Plugin_Continue;
  char message[MAX_MESSAGE_LEN];
  char formatted_message[MAX_MESSAGE_LEN];

  GetCmdArgString(message, sizeof(message));
  Format(formatted_message, sizeof(formatted_message), "CHAT: %L: %s\n", client, message);

  send_report(formatted_message);
  return Plugin_Continue;
}

public Action ReportCmd(int client, int argc) {
  if (argc < 1) {
    ReplyToCommand(client, "[SM] Usage: report <message>");
    return Plugin_Handled;
  }

  char message[MAX_MESSAGE_LEN];
  char report_message[MAX_REQUEST_LENGTH];
  GetCmdArgString(message, sizeof(message));

  Format(report_message, sizeof(report_message), "@here %L has issued a report with reason %s\n", client, message);
  // Create format message

  if (send_report(report_message)) PrintToChat(client, "Thanks for your report, we will get to it soon");
  return Plugin_Handled;
}


int send_report(const char[] message) {
  char url[500];
  char json_dump_data[MAX_REQUEST_LENGTH];
  url[0] = '\0';
  GetConVarString(Webhook_Url, url, sizeof(url));
  if (url[0] == '\0') {
    LogToGame("<Discord Reports> Error: Webhook url not set");
  }

  Handle json = json_object();
  if (json == INVALID_HANDLE) {
    LogToGame("<Discord Reports> Error could not create JSON object");
    return false;
  }

  json_object_set_new(json, "content", json_string(message));
  json_dump(json, json_dump_data, MAX_REQUEST_LENGTH, 0, true);
  delete json;

  return send_webhoook(url, json_dump_data);
}


int send_webhoook(const char[] url, const char[] json) {
  Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
  if (request == INVALID_HANDLE) {
    LogToGame("<Discord Reports> Error: Could not create http request");
    return false;
  }

  SteamWorks_SetHTTPRequestRawPostBody(request, "application/json; charset=UTF-8", json, strlen(json));
  SteamWorks_SendHTTPRequest(request);

  delete request; 
  return true;
}
