import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'dart:io';
import 'package:kamino/api/tmdb.dart' as tmdb;
import 'package:http/http.dart' as http;
import 'package:kamino/main.dart';
import 'package:kamino/ui/uielements.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:kamino/view/settings/settings_prefs.dart' as settingsPref;
import 'package:kamino/util/databaseHelper.dart' as databaseHelper;

class TraktAuth extends StatefulWidget {

  final BuildContext context;

  TraktAuth({ this.context });

  @override
  _TraktAuthState createState() => new _TraktAuthState();

}

class _TraktAuthState extends State<TraktAuth> {
  // Instance of WebView plugin
  final flutterWebviewPlugin = new FlutterWebviewPlugin();

  // On urlChanged stream
  StreamSubscription<String> _onUrlChanged;

  @override
  void initState() {
    flutterWebviewPlugin.close();

    // Add a listener to on url changed
    _onUrlChanged = flutterWebviewPlugin.onUrlChanged.listen((String url) {
      if (mounted && url.contains("native?code=")) {
        _onUrlChanged.cancel();
        String authCode = url.split("code=")[1].replaceAll("#", "");
        Navigator.of(this.context).pop(authCode);
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    KaminoAppState appState = context.ancestorStateOfType(const TypeMatcher<KaminoAppState>());

    String _url = "https://trakt.tv/oauth/authorize?response_type=code&"
        "client_id=${appState.getVendorConfigs()[0].traktCredentials.id}&"
        "redirect_uri=urn:ietf:wg:oauth:2.0:oob";

    return WebviewScaffold(
      url: _url,
      userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36",
      clearCache: true,
      clearCookies: true,
      appBar: AppBar(
        title: TitleText("Trakt Authenticator"),
        centerTitle: true,
        elevation: 8.0,
        backgroundColor: Theme.of(context).cardColor,
      ),
    );
  }

  @override
  void dispose() {
    flutterWebviewPlugin.dispose();
    super.dispose();
  }
}

void renewToken(BuildContext context) async {
  KaminoAppState appState = context.ancestorStateOfType(const TypeMatcher<KaminoAppState>());

  //get trakt credentials
  List<String> _traktCred = [];

  settingsPref.getListPref("traktCredentials").then((data) {
    _traktCred = data;
  });

  //check if the array is empty or not
  if (_traktCred.length == 3) {
    //get the token expiry date
    DateTime temp = DateTime.parse(_traktCred[2]).toUtc();
    DateTime expiry = DateTime.utc(temp.year, temp.month, temp.day);

    //get todays date
    DateTime today = DateTime.now().toUtc();
    DateTime todaysDate = DateTime.utc(today.year, today.month, today.day);

    //check if the date has passed
    if (todaysDate.compareTo(expiry) == 0 || expiry.isBefore(todaysDate)) {
      String url = 'https://api.trakt.tv/oauth/token';

      Map body = {
        'refresh_token': _traktCred[1],
        'client_id': appState.getVendorConfigs()[0].traktCredentials.id,
        'client_secret': appState.getVendorConfigs()[0].traktCredentials.secret,
        'redirect_uri': 'urn:ietf:wg:oauth:2.0:oob',
        'grant_type': 'refresh_token'
      };

      http.Response res = await http.post(url, body: body);

      if (res.statusCode == 200) {
        Map data = jsonDecode(res.body);

        List<String> newCredentials = [
          data["access_token"],
          data["refresh_token"],

          //new expiry date
          DateTime.now().add(new Duration(days: 84)).toString()
        ];

        settingsPref.saveListPref("traktCredentials", newCredentials);

        Scaffold.of(context).showSnackBar(new SnackBar(
          content: Text(
            "Trakt Token Refreshed",
            style: TextStyle(
                color: Colors.white,
                fontFamily: "GlacialIndifference",
                fontSize: 17.0),
          ),
          backgroundColor: Colors.green,
          duration: new Duration(milliseconds: 600),
        ));
      } else {
        showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) {
              return AlertDialog(
                title: TitleText("Trakt Authentication Failure"),
                content: Text(
                  "Failed to renew Trakt token. Please check your "
                      "internet connection and try again. If the problem"
                      " presists, please sign out of Trakt and sign in again",
                  style: TextStyle(
                      fontSize: 18.0,
                      fontFamily: "GlacialIndifference",
                      color: Theme.of(context).primaryColor),
                ),
                actions: <Widget>[
                  Center(
                    child: FlatButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Okay",
                        style: TextStyle(
                            fontSize: 18.0,
                            fontFamily: "GlacialIndifference",
                            color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  Center(
                    child: FlatButton(
                      onPressed: () {
                        Navigator.pop(context);
                        renewToken(context);
                      },
                      child: Text(
                        "Try again",
                        style: TextStyle(
                            fontSize: 18.0,
                            fontFamily: "GlacialIndifference",
                            color: Theme.of(context).primaryColor),
                      ),
                    ),
                  )
                ],
                //backgroundColor: Theme.of(context).cardColor,
              );
            });
      }
    }
  }
}

Future<Null> getCollection(List<String> traktCred, BuildContext context) async {
  KaminoAppState appState = context.ancestorStateOfType(const TypeMatcher<KaminoAppState>());

  List<String> _traktMediaTypes = ["movies", "shows"];

  Map payload = {
    "movies": {"tmdb": [], "imdb": []},
    "shows": {"tmdb": [], "imdb": []},
  };

  //get the latest collection from trakt
  for (int x = 0; x < _traktMediaTypes.length; x++) {
    String element = _traktMediaTypes[x];

    String url = 'https://api.trakt.tv/sync/collection/$element';

    final res = await http.get(
      url,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${traktCred[0]}',
        HttpHeaders.contentTypeHeader: 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': appState.getVendorConfigs()[0].traktCredentials.id
      },
    );

    if (res.statusCode == 200) {
      var _data = jsonDecode(res.body);

      //get all the tmdb ids from trakt
      _data.forEach((var traktObject) {
        String mediaType = "";
        if (element == "movies") {
          mediaType = "movie";
        } else if (element == "shows") {
          mediaType = "show";
        }

        if (traktObject[mediaType]["ids"]["tmdb"] == null) {
          payload[element]["imdb"].add(traktObject[mediaType]["ids"]["imdb"]);
        } else {
          payload[element]["tmdb"].add(traktObject[mediaType]["ids"]["tmdb"]);
        }
      });
    } else {
      print("Error: ${jsonDecode(res.body)}");
    }
  }

  String status = await updateDatabase(payload);
}

Future<List<int>> addFavToTrakt(List<String> traktCred, BuildContext context) async {

  KaminoAppState appState = context.ancestorStateOfType(const TypeMatcher<KaminoAppState>());

  //get all favorites from the database
  Map _favs = await databaseHelper.getAllFaves();

  //media sent in batches to avoid timeout
  List<String> mediaTypes = ["shows","movies"];
  List<int> status_codes = [];

  for (int t = 0; t < mediaTypes.length; t++){

    String header = mediaTypes[t];

    var body = {
      header: []
    };

    String dbSelector = header == "shows" ? "tv" : "movie";

    //parsing the data from the database
    if (_favs[dbSelector].length > 0) {
      for (int i = 0; i < _favs[dbSelector].length; i++) {

        body[header].add({
          'collected_at': _favs[dbSelector][i]["saved_on"],
          'title': _favs[dbSelector][i]["name"],
          'year': _favs[dbSelector][i]["year"],
          'ids': {
            'tmdb': _favs[dbSelector][i]["tmdbID"]
          }
        });
      }

      String url = 'https://api.trakt.tv/sync/collection';

      final res = await http.post(url,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer ${traktCred[0]}',
            'Content-Type': 'application/json',
            'trakt-api-version': '2',
            'trakt-api-key': appState.getVendorConfigs()[0].traktCredentials.id
          },
          body: json.encode(body)
      );

      status_codes.add(res.statusCode);
    }
  }

  return status_codes;
}

Future<String> updateDatabase(Map payload) async {

  List<int> _favIDs = await databaseHelper.getAllFavIDs();
  List<Map> collections = [];

  //check to see if the item is already in the database
  //if not get info from tmdb and write to the database

  var callTime = DateTime.now();

  //processing the tv shows
  for (int i = 0; i < payload["shows"]["tmdb"].length; i++) {
    if (!_favIDs.contains(payload["shows"]["tmdb"][i])) {

      //300ms delay ensures we do not hit tmdb api limit
      await Future.delayed(new Duration(milliseconds: 300));

      //get the info from tmdb
      String url =
          "${tmdb.root_url}/tv/${payload["shows"]["tmdb"][i]}${tmdb.defaultArguments}";

      var res = await http.get(url);

      if (res.statusCode == 200) {
        Map _data = jsonDecode(res.body);

        _favIDs.add(_data["id"]);

        collections.add({
          "name": _data["name"],
          "docType": "favorites",
          "contentType": "tv",
          "tmdbID": _data["id"],
          "imageUrl": _data["poster_path"],
          "year": _data["first_air_date"],
          "saved_on": DateTime.now().toUtc().toString()
        });
      }
    }
  }

  //processing movie ids
  for (int i = 0; i < payload["movies"]["tmdb"].length; i++) {
    if (!_favIDs.contains(payload["movies"]["tmdb"][i])) {

      //300ms delay ensures we do not hit tmdb api limit
      await Future.delayed(new Duration(milliseconds: 300));

      //get the info from tmdb
      String url =
          "${tmdb.root_url}/movie/${payload["movies"]["tmdb"][i]}${tmdb.defaultArguments}";
      var res = await http.get(url);

      if (res.statusCode == 200) {

        Map _data = jsonDecode(res.body);
        _favIDs.add(_data["id"]);

        collections.add({
          "name":  _data["title"],
          "docType": "favorites",
          "contentType": "movie",
          "tmdbID": _data["id"],
          "imageUrl": _data["poster_path"],
          "year": _data["release_date"],
          "saved_on": DateTime.now().toUtc().toString()
        });
      }
    }
  }

  //handling imdb ids
  //movies

  for (int i = 0; i < payload["movies"]["imdb"].length; i++) {

    //300ms delay ensures we do not hit tmdb api limit
    await Future.delayed(new Duration(milliseconds: 300));

    String url = "${tmdb.root_url}/find/${payload["movies"]["imdb"][i]}"
        "${tmdb.defaultArguments}&external_source=imdb_id";

    var res = await http.get(url);

    if (res.statusCode == 200) {
      Map _data = jsonDecode(res.body);

      //check that the data returned is not empty
      if (_data["movie_results"].length > 0) {

        if(!_favIDs.contains(_data["movie_results"][0]["id"])){

          _favIDs.add(_data["movie_results"][0]["id"]);

          collections.add({
          "name":  _data["movie_results"][0]["title"],
          "docType": "favorites",
          "contentType": "movie",
          "tmdbID": _data["movie_results"][0]["id"],
          "imageUrl": _data["movie_results"][0]["poster_path"],
          "year": _data["movie_results"][0]["release_date"],
          "saved_on": DateTime.now().toUtc().toString()
          });
        }
      }
    }
  }

  //tv shows
  for (int i = 0; i < payload["shows"]["imdb"].length; i++) {

    //300ms delay ensures we do not hit tmdb api limit
    await Future.delayed(new Duration(milliseconds: 300));

    String url = "${tmdb.root_url}/find/${payload["shows"]["imdb"][i]}"
        "${tmdb.defaultArguments}&external_source=imdb_id";

    var res = await http.get(url);

    if (res.statusCode == 200) {
      Map _data = jsonDecode(res.body);

      //check that the data returned is not empty
      if (_data["tv_results"].length > 0) {

        if (!_favIDs.contains(_data["tv_results"][0]["id"])) {

          _favIDs.add(_data["tv_results"][0]["id"]);

          collections.add({
            "name":  _data["tv_results"][0]["name"],
            "docType": "favorites",
            "contentType": "tv",
            "tmdbID": _data["tv_results"][0]["id"],
            "imageUrl": _data["tv_results"][0]["poster_path"],
            "year": _data["tv_results"][0]["first_air_date"],
            "saved_on": DateTime.now().toUtc().toString()
          });
        }
      }
    }
  }

  print("api calls took: "+callTime.difference(DateTime.now()).inSeconds.toString());

  if (collections.length > 0) {
    print("writing ${collections.length} items to the database");
    var startTime = DateTime.now();
    print(startTime);
    print("items being written"+collections.toString());
    String writeStatus = await databaseHelper.bulkSaveFavorites(collections);
    await Future.delayed(new Duration(seconds: 2));

    var difference = startTime.difference(DateTime.now()).inSeconds;
    print("writing took: ${difference}");
  }

  return "Done";
}

//use this method when sending a single item to trakt
Future<Null> sendNewMedia(BuildContext context, String mediaType, String title, String year, int id) async {

  KaminoAppState appState = context.ancestorStateOfType(const TypeMatcher<KaminoAppState>());

  String header = mediaType == "movie" ? "movies" : "shows";
  List<String> traktCred = await settingsPref.getListPref("traktCredentials");

  Map body = {
    header: []
  };

  body[header].add({
    'collected_at': DateTime.now().toUtc().toString(),
    'title': title,
    'year': year,
    'ids': {
      'tmdb': id
    }
  });

  String url = 'https://api.trakt.tv/sync/collection';

  final res = await http.post(url,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${traktCred[0]}',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': appState.getVendorConfigs()[0].traktCredentials.id
      },
      body: json.encode(body)
  );
}

Future<Null> removeMedia(BuildContext context, String mediaType, int id) async {

  KaminoAppState appState = context.ancestorStateOfType(const TypeMatcher<KaminoAppState>());

  String header = mediaType == "movie" ? "movies" : "shows";
  List<String> traktCred = await settingsPref.getListPref("traktCredentials");

  Map body = {
    header: []
  };

  body[header].add({
    'ids': {
      'tmdb': id
    }
  });

  String url = 'https://api.trakt.tv/sync/collection/remove';

  final res = await http.post(url,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${traktCred[0]}',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': appState.getVendorConfigs()[0].traktCredentials.id
      },
      body: json.encode(body)
  );
}

Future<String> getWatchHistories(BuildContext context) async {

  List<String> traktMediaType = ["movies", "shows"];
  List<Map> documents = [];

  for(int i = 0; i < traktMediaType.length; i++){

    //get the history from trakt
    String header = traktMediaType[i];

    String url = "https://api.trakt.tv/sync/watched/"+header;
    http.Response res = await http.get(url);

    if (res.statusCode == 200){

      if (header == "movies") {

        List _data = json.decode(res.body);


        _data.forEach((item){
          documents.add({
            "name": item["movie"]["title"],
            "docType": "watched",
            "contentType": header == "movies" ? "movie" : "tv",
            "tmdbID": item["movie"]["ids"]["tmdb"],
            "last_watched_at": item["last_watched_at"],
            "last_updated_at": item["last_updated_at"],
            "year": item["movie"]["year"]
          });
        });

        //delay buys enough time to tidy up database and close the connection
        await Future.delayed(new Duration(milliseconds: 300));

      }else if (header == "shows"){

        List _data = json.decode(res.body);

        _data.forEach((item){

          documents.add({
            "name": item["show"]["title"],
            "docType": "watched",
            "tmdbID": item["show"]["ids"]["tmdb"],
            "contentType": header == "movies" ? "movie" : "tv",
            "last_watched_at": item["last_watched_at"],
            "last_updated_at": item["last_updated_at"],
            "seasons": item["seasons"]
          });
        });

        //delay buys enough time to tidy up database and close the connection
        await Future.delayed(new Duration(milliseconds: 300));
      }
    }
  }

  if (documents.length > 0){
    //write the watched history to the database
    String status = await databaseHelper.bulkSaveFavorites(documents);
  }


  return "done";
}

Future<int> addToWatchHistory(List<String> traktCred, BuildContext context,
    String mediaType, String title, String year, int id, [int seasonNumber, int episodeNumber]) async{

  KaminoAppState appState = context.ancestorStateOfType(const TypeMatcher<KaminoAppState>());
  //List<String> traktMediaType = ["movies", "shows"];
  String url = "https://api.trakt.tv/sync/history";

  Map body = mediaType != "tv" ? {
    "movies": [
      {
        "watched_at": DateTime.now().toUtc().toString(),
        "title": title,
        "year": year,
        "ids": {
          "tmdb": id
        }
      }
    ]
  } : {
    "shows": [
      {
        "watched_at": DateTime.now().toUtc().toString(),
        "title": title,
        "year": year,
        "ids": {
          "tmdb": id
        },
        "seasons": [
          {
            "number": seasonNumber,
            "episodes": [
              {
                "watched_at": DateTime.now().toUtc().toString(),
                "number": episodeNumber
              }
            ],
          }
        ]
      }
    ]
  };

  final res = await http.post(url,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${traktCred[0]}',
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': appState.getVendorConfigs()[0].traktCredentials.id
      },
      body: json.encode(body)
  );

  print("received code: ${res.statusCode}");

  print("message: ${res.body}");

  return res.statusCode;

}

void _dialogGenerator(String title, String body, BuildContext context, bool dismiss){
  showDialog(
      context: context,
      barrierDismissible: dismiss,
      builder: (_){
        return AlertDialog(
          title: TitleText(title),
          content: Text(body,
            style: TextStyle(
                color: Colors.white
            ),
          ),
          actions: <Widget>[
            Center(
              child: FlatButton(
                  onPressed: () => Navigator.pop(context),
                  child: TitleText("Okay", textColor: Colors.white)
              ),
            )
          ],
          //backgroundColor: Theme.of(context).cardColor,
        );
      }
  );
}

//Trakt authentication logic
Future<List<String>> authUser(BuildContext context, List<String> _traktCred, String code) async {
  KaminoAppState appState = context.ancestorStateOfType(const TypeMatcher<KaminoAppState>());

  if (code == null){
    //Trakt auth has failed

    _dialogGenerator(
        "Authentication Unsuccessful",
        "$appName was unable to authenticate with Trakt.tv.",
        context,
        true
    );
    return [];

  } else {
    //continue with authentication process

    /*
      _dialogGenerator(
          "Processing",
          "Authenticating Trakt credentials, please wait...",
          context,
          false
      );
      */

    //exchange the code for an access token
    String url = "https://api.trakt.tv/oauth/token";

    Map _body = {
      "code": code,
      "client_id": appState.getVendorConfigs()[0].traktCredentials.id,
      "client_secret": appState.getVendorConfigs()[0].traktCredentials.secret,
      "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
      "grant_type": "authorization_code"
    };

    Response res = await post(url, body: _body);

    if (res.statusCode == 200){

      Map _data = json.decode(res.body);

      //save the response to shared pref
      /*

        key - trakt Credentials
        0 - access token
        1 - refresh token
        2 - expiry date
        */

      List<String> temp = [
        _data["access_token"],
        _data["refresh_token"],

        //date in 3 months, used to determine if token needs to be refreshed
        DateTime.now().add(new Duration(days: 84)).toString()
      ];

      settingsPref.saveListPref("traktCredentials", temp);

      _dialogGenerator("Authentication Successful", "You can now tap 'Sync' to synchronise your Trakt favorites with your ApolloTV favorites.\n\n(Trakt integration is limited as it is still in development.)", context, true);
      return temp;

    } else {

      //show error message
      _dialogGenerator(
          "Authentication Failed",
          "Error ${res.statusCode}\nPlease report this error.",
          context,
          true
      );
      return [];

    }
  }
}

Future<bool> deauthUser(BuildContext context, _traktCred) async {
  KaminoAppState appState = context.ancestorStateOfType(const TypeMatcher<KaminoAppState>());

  Map body = {
    'token': _traktCred[0],
    'client_id': appState.getVendorConfigs()[0].traktCredentials.id,
    'client_secret': appState.getVendorConfigs()[0].traktCredentials.secret
  };

  String url = "https://api.trakt.tv/oauth/revoke";
  Response res = await post(url, body: body);

  if (res.statusCode == 200){
    settingsPref.saveListPref("traktCredentials", []);

    Scaffold.of(context).showSnackBar(
        new SnackBar(content: Text("Trakt successfully disconnected!",
          style: TextStyle(
              color: Colors.white,
              fontFamily: "GlacialIndifference",
              fontSize: 17.0
          ),),
          backgroundColor: Colors.green,
        )
    );

    return true;
  }
  return false;
}

void synchronize(BuildContext context, _traktCred) async {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_){
        return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: TitleText("Trakt Synchronization..."),
              content: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                        "Please wait while we synchronize your favorites with Trakt. " +
                            "This dialog will close automatically when synchronization is complete.",
                        style: TextStyle(color: Colors.white)
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: new AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              //backgroundColor: Theme.of(context).cardColor,
            )
        );
      }
  );

  String pullStatus = await getCollection(_traktCred, context);
  Future.delayed(new Duration(seconds: 4));
  List<int> saveStatus = await addFavToTrakt(_traktCred, context);

  Navigator.pop(context);
}