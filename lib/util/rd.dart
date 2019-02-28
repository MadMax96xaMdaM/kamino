import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kamino/ui/uielements.dart';
import 'package:kamino/view/settings/settings_prefs.dart' as settingsPref;
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

const client_id = "X245A4XAIBGVM";

/*
* IMPORTANT RD INFO - DO NOT DELETE
* 0 - Access Code
* 1 - Refresh Token
* 2 - Expires in
*/

class RealDebrid extends StatefulWidget {

  final Map oauth_data;

  RealDebrid({ this.oauth_data });

  @override
  _RealDebridState createState() => new _RealDebridState();
}

class _RealDebridState extends State<RealDebrid>{

  // Instance of WebView plugin
  final flutterWebviewPlugin = new FlutterWebviewPlugin();

  @override
  void initState() {

    flutterWebviewPlugin.close();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return WillPopScope(
      onWillPop: () async{
        Navigator.pop(
            this.context,
            await getToken(widget.oauth_data["device_code"]));

        return true;
      },
      child: WebviewScaffold(
        url: widget.oauth_data["verification_url"],
        userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36",
        clearCache: true,
        clearCookies: true,
        appBar: AppBar(
          title: TitleText("Auth Code: ${widget.oauth_data["user_code"]}"),
          centerTitle: true,
          elevation: 8.0,
          backgroundColor: Theme.of(context).cardColor,
        ),
      ),
    );
  }

  @override
  void dispose() {

    flutterWebviewPlugin.dispose();
    super.dispose();
  }
}

Future<Map> getOAuthInfo() async{

  String url = "https://api.real-debrid.com/oauth/v2/device"
      "/code?client_id=$client_id&new_credentials=yes";

  http.Response res = await http.get(url);

  print("OAuth api response: ${res.body}..... code ${res.statusCode}");
  return json.decode(res.body);
}

Future<Map> _getSecret(String device_code) async{

  String url = "https://api.real-debrid.com/oauth/v2/device"
      "/credentials?client_id=$client_id&code=$device_code";

  http.Response res = await http.get(url);
  print("secret api response: ${res.body}..... code ${res.statusCode}");

  Map data = json.decode(res.body);

  await settingsPref.saveListPref(
      "rdClientInfo",
      [data["client_id"], data["client_secret"]]
  );

  return data;
}

Future<Map> getToken(String device_code) async{

  Map data = await _getSecret(device_code);

  if (data["client_id"] != null || data["client_secret"] != null){

    //get the token using the client id and client secret
    String url = "https://api.real-debrid.com/oauth/v2/token";

    Map body = {
      "client_id": data["client_id"],
      "client_secret": data["client_secret"],
      "code": device_code,
      "grant_type": "http://oauth.net/grant_type/device/1.0"
    };

    http.Response res = await http.post(url, body: body);

    print("api response code: ${res.statusCode}");

    if (res.statusCode == 200){
      return json.decode(res.body);
    }
  }

  return {"access_token": null};
}

Future<Null> addMagent(String magnet) async{

  //check that the token is valid
  List<String> _rdCred = await settingsPref.getListPref("rdCredentials");

  if (_rdCred.length == 3){
    int tokenCheck = DateTime.now().compareTo(DateTime.parse(_rdCred[2]));

    if (!tokenCheck.isNegative){

      //refresh the token
      bool refreshSuccess = await _refreshToken();

      if (refreshSuccess == true){

        //send magnet to RD
      }

    }
  }

}

Future<bool> _refreshToken() async{

  String url = "https://api.real-debrid.com/oauth/v2/token";
  List<String> _rdCred = await settingsPref.getListPref("rdCredentials");

  List<String> _rdIDSecret = await settingsPref.getListPref("rdClientInfo");

  Map body = {
    "client_id": _rdIDSecret[0],
    "grant_type": "http://oauth.net/grant_type/device/1.0",
    "client_secret": _rdIDSecret[1],
    "refresh_token": _rdCred[1]
  };

  http.Response res = await http.post(url, body: body);

  if (res.statusCode == 200){

    Map result = json.decode(res.body);
    print("refreshing token data with ${res.body}");

    List<String> _cred = [result["access_token"],
    result["refresh_token"],
    DateTime.now().add(new Duration(seconds: result["expires_in"])).toString()];

    await settingsPref.saveListPref("rdCredentials", _cred);

    return true;
  }

  return false;
}