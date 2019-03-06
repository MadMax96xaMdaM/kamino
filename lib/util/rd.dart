import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:kamino/models/content.dart';
import 'package:http/http.dart' as http;
import 'package:kamino/ui/uielements.dart';
import 'package:kamino/scrapers/torrent/KickAss.dart' as torrentScraper;
import 'package:kamino/view/settings/settings_prefs.dart' as settingsPref;
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

const _client_id = "X245A4XAIBGVM";
const url = "https://api.real-debrid.com/rest/1.0/";

/*
* IMPORTANT RD INFO - DO NOT DELETE
* 0 - Access Code
* 1 - Refresh Token
* 2 - Expires in
*/

class RealDebrid extends StatefulWidget {
  final Map oauth_data;

  RealDebrid({this.oauth_data});

  @override
  _RealDebridState createState() => new _RealDebridState();
}

class _RealDebridState extends State<RealDebrid> {
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
      onWillPop: () async {
        Navigator.pop(
            this.context, await getToken(widget.oauth_data["device_code"]));

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

Future<Map> getOAuthInfo() async {
  String url = "https://api.real-debrid.com/oauth/v2/device"
      "/code?client_id=$_client_id&new_credentials=yes";

  http.Response res = await http.get(url);

  print("OAuth api response: ${res.body}..... code ${res.statusCode}");
  return json.decode(res.body);
}

Future<Map> _getSecret(String device_code) async {
  String url = "https://api.real-debrid.com/oauth/v2/device"
      "/credentials?client_id=$_client_id&code=$device_code";

  http.Response res = await http.get(url);
  print("secret api response: ${res.body}..... code ${res.statusCode}");

  Map data = json.decode(res.body);

  await settingsPref
      .saveListPref("rdClientInfo", [data["client_id"], data["client_secret"]]);

  return data;
}

Future<Map> getToken(String device_code) async {
  Map data = await _getSecret(device_code);

  if (data["client_id"] != null || data["client_secret"] != null) {
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

    if (res.statusCode == 200) {
      return json.decode(res.body);
    }
  }

  return {"access_token": null};
}

Future<Map> getMagnet(String magnet) async {
  //check that the token is valid
  List<String> _rdCred = await settingsPref.getListPref("rdCredentials");
  Map _magnet = {};

  if (_rdCred.length == 3) {
    bool tokenCheck = DateTime.now().isBefore(DateTime.parse(_rdCred[2]));

    print("token check is:  $tokenCheck");

    if (!tokenCheck) {

      //refresh the token
      bool refreshSuccess = await _refreshToken();
      print("refreshing token: $refreshSuccess");

      if (refreshSuccess == true) {
        //send magnet to RD
        print("sending magnet to RD....top");
        _magnet = await _sendMagnet(magnet);
      }

    } else{

      //send magnet to RD
      print("sending magnet to RD....bottom");
      _magnet = await _sendMagnet(magnet);
    }
  }

  return _magnet;
}

Future<Map> _sendMagnet(String magnet) async {
  List<String> videoExtensions = [".mkv", ".mp4", ".m4v", ".avi", ".mov"];
  List<String> _rdCred = await settingsPref.getListPref("rdCredentials");
  print("sending torent to RD........");

  Map torrent = new Map();
  Map<String, String> userHeader = {'Authorization': 'Bearer ' + _rdCred[0]};

  print("sending torrents to RD");

  //send the magnet to the RD
  http.Response res = await http.post(url + "torrents/addMagnet",
      body: {"magnet": magnet}, headers: userHeader);

  print("first api: ${res.statusCode}  ${res.body}");

  //start the download of the magnet
  if (res.statusCode == 201) {
    Map data = json.decode(res.body);

    http.Response _res = await http.get(url + "torrents/info/${data["id"]}",
        headers: userHeader);

    if (_res.statusCode == 200) {
      Map data = json.decode(_res.body);
      print(json.decode(_res.body));

      //file selection to download from torrent
      List<String> _fileSelection = [];
      print(data["files"]);

      //if file is a video add to selection array
      for (int f = 0; f < data["files"].length; f++) {
        for (int i = 0; i < videoExtensions.length; i++) {
          if (data["files"][f]["path"].contains(videoExtensions[i])) {
            if(!data["files"][f]["path"].toString().toLowerCase().contains("sample")){
              //prevent sample videos from being added
              _fileSelection.add(data["files"][f]["id"].toString());
            }
          }
        }
      }

      //send file selection to RD to start download
      http.Response _SelectionRes = await http.post(
          url + "torrents/selectFiles/${data["id"]}",
          headers: userHeader,
          body: {
            "files": _fileSelection.length > 1
                ? _fileSelection.join(",")
                : _fileSelection[0]
          });

      print("selected files api:"
          " ${_SelectionRes.statusCode}  ${_SelectionRes.body}");

      //get File link from api
      http.Response _restrictedLinkRes = await http.get(
        url + "torrents/info/${data["id"]}",
        headers: userHeader,
      );

      print("restricted Link api:"
          " ${_restrictedLinkRes.statusCode}  ${_restrictedLinkRes.body}");

      if (_restrictedLinkRes.statusCode == 200) {
        //get derestricted link
        Map restrictData = json.decode(_restrictedLinkRes.body);

        http.Response _StreamLinkRes = await http.post(url + "unrestrict/link",
            headers: userHeader, body: {"link": restrictData["links"][0]});

        print("_StreamLinkRes Link api:"
            " ${_StreamLinkRes.statusCode}  ${_StreamLinkRes.body}");

        if (_StreamLinkRes.statusCode == 200) {

          //get the derestricted stream link
          return {
            "id": json.decode(_StreamLinkRes.body)["id"],
            "name": json.decode(_StreamLinkRes.body)["filename"],
            "download": json.decode(_StreamLinkRes.body)["download"]
          };
        }
      }
    }
  }

  // no stream link found
  return {};
}

Future<bool> _refreshToken() async {
  String url = "https://api.real-debrid.com/oauth/v2/token";
  List<String> _rdCred = await settingsPref.getListPref("rdCredentials");

  List<String> _rdIDSecret = await settingsPref.getListPref("rdClientInfo");

  Map body = {
    "client_id": _rdIDSecret[0],
    "grant_type": "http://oauth.net/grant_type/device/1.0",
    "client_secret": _rdIDSecret[1],
    "code": _rdCred[1]
  };

  http.Response res = await http.post(url, body: body);

  if (res.statusCode == 200) {
    Map result = json.decode(res.body);
    print("refreshing token data with ${res.body}");

    List<String> _cred = [
      result["access_token"],
      result["refresh_token"],
      DateTime.now().add(new Duration(seconds: result["expires_in"])).toString()
    ];

    await settingsPref.saveListPref("rdCredentials", _cred);

    return true;
  } else {
    print("refresh token api response: ${res.statusCode}\n${res.body}");
  }

  return false;
}

Future<Null> removeTorrent(List<Map> torrents) async {

  //remove torrent from RD
  List<String> _rdCred = await settingsPref.getListPref("rdCredentials");
  Map<String, String> userHeader = {'Authorization': 'Bearer ' + _rdCred[0]};

  if (_rdCred.length == 3) {
    bool tokenCheck = DateTime.now().isBefore(DateTime.parse(_rdCred[2]));
    print("token check is:  $tokenCheck");

    if (!tokenCheck) {
      //refresh the token
      bool refreshSuccess = await _refreshToken();
      print("refreshing token: $refreshSuccess");

      if (refreshSuccess == true) {
        //remove torrent
        _requestDeletion(torrents, userHeader);
      }
    } else{
      //remove torrent
      _requestDeletion(torrents, userHeader);
    }
  }
}

Future<Null> _requestDeletion(List<Map> torrents, Map<String, String> userHeader) async{

  torrents.forEach((Map torrent) async{
    print("removing torrent ${torrent["name"]} for RD");

    //send the magnet to the RD
    http.Response res = await http.delete(
        url + "torrents/delete/${torrent["id"]}",
        headers: userHeader
    );
    print("torrent removal api: ${res.statusCode}  ${res.body}");
  });
}

Future<String> unrestrictLink(String link) async{

  List<String> _rdCred = await settingsPref.getListPref("rdCredentials");
  Map<String, String> userHeader = {'Authorization': 'Bearer ' + _rdCred[0]};

  http.Response _StreamLinkRes = await http.post(
      url + "unrestrict/link",
      headers: userHeader,
      body: {"link": link}
      );

  print("_StreamLink resolve api:"
      " ${_StreamLinkRes.statusCode}  ${_StreamLinkRes.body}");

  if (_StreamLinkRes.statusCode == 200) {
    //get the derestricted stream link
    return json.decode(_StreamLinkRes.body)["download"];
  }

  return null;
}
