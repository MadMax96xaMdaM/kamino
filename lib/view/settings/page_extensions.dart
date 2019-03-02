import 'package:flutter/material.dart';
import 'package:kamino/animation/transition.dart';
import 'package:kamino/ui/uielements.dart';
import 'package:kamino/util/trakt.dart' as trakt;
import 'package:kamino/view/settings/page.dart';
import 'package:kamino/models/content.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kamino/util/rd.dart' as rd;

import 'package:kamino/view/settings/settings_prefs.dart' as settingsPref;

class ExtensionsSettingsPage extends SettingsPage {
  ExtensionsSettingsPage() : super(
      title: "Extensions",
      pageState: ExtensionsSettingsPageState()
  );
}

class ExtensionsSettingsPageState extends SettingsPageState {

  List<String> _traktCred;
  List<String> _rdCred;

  @override
  void initState(){
    settingsPref.getListPref("traktCredentials").then((data){
      setState(() {
        if (data == null || data == []){
          _traktCred = [];
        } else {
          _traktCred = data;
        }
      });
    });

    settingsPref.getListPref("rdCredentials").then((data){
      setState(() {
        if (data == null || data == []){
          _rdCred = [];
        } else {
          _rdCred = data;
        }
      });
    });

    super.initState();
  }

  @override
  Widget buildPage(BuildContext context) {
    bool traktConnected = _traktCred != null && _traktCred.length == 3;

    return ListView(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      children: <Widget>[

        Card(
          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          elevation: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                isThreeLine: true,
                leading: SvgPicture.asset("assets/icons/trakt.svg", height: 36, width: 36, color: const Color(0xFFED1C24)),
                title: Text('Trakt.tv'),
                subtitle: Text("Automatically track what you're watching, synchronise playlists across devices and more..."),
              ),
              ButtonTheme.bar( // make buttons use the appropriate styles for cards
                child: ButtonBar(
                  children: <Widget>[
                    FlatButton(
                      textColor: Theme.of(context).primaryTextTheme.body1.color,
                      child: TitleText('Sync'),
                      onPressed: (traktConnected) ? (){
                        trakt.synchronize(context, _traktCred);
                      } : null,
                    ),
                    !traktConnected ?
                      // Trakt account is not linked: show connect option
                      FlatButton(
                        textColor: Theme.of(context).primaryTextTheme.body1.color,
                        child: TitleText('Connect'),
                        onPressed: () {
                          Navigator.push(context, SlideRightRoute(
                              builder: (_ctx) => trakt.TraktAuth(context: _ctx)
                          )).then((var authCode) {
                            trakt.authUser(context, _traktCred, authCode).then((_traktCred) async {
                              setState(() {
                                this._traktCred = _traktCred;
                              });
                            });
                          });
                        },
                      ) :
                    // Trakt account is linked: show disconnect option
                    FlatButton(
                      textColor: Theme.of(context).primaryTextTheme.body1.color,
                      child: TitleText('Disconnect'),
                      onPressed: () async {
                        // TODO: Show disconnecting dialog
                        if(await trakt.deauthUser(context, _traktCred)){
                          setState(() {
                            _traktCred = [];
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        InkWell(
          child: Card(
            margin: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
            elevation: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  isThreeLine: true,
                  leading: SvgPicture.asset("assets/icons/realdebrid.svg", height: 36, width: 36, color: const Color(0xFF78BB6F)),
                  title: Text('Real-Debrid'),
                  subtitle: Text("Real-Debrid is an unrestricted downloader that allows you to quickly download files hosted on the Internet."),
                ),
                ButtonTheme.bar( // make buttons use the appropriate styles for cards
                  child: ButtonBar(
                    children: <Widget>[
                       _rdCred != null && _rdCred.length != 3 ? FlatButton(
                        textColor: Theme.of(context).primaryTextTheme.body1.color,
                        child: TitleText('Connect'),
                        onPressed: () async{
                          await _signinToRD();
                        },
                      ) : FlatButton(
                         textColor: Theme.of(context).primaryTextTheme.body1.color,
                         child: TitleText('Disconnect'),
                         onPressed: () {
                           _clearRDCredentials();
                         },
                       ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          onTap: () async{

            //await rd.getMagnet;

            Map queryModel = {
              "mediaType": "tv",
              "show": "the flash",
              "season": 05,
              "tv_year": 2014,
              "movie": "aquaman",
              "movie_year": 2018
            };

            print( await rd.getMagnet(ContentType.MOVIE));
          },
        )
      ],
    );
  }

  void _signinToRD() async{

    Map data = await rd.getOAuthInfo();

    if (data["user_code"] != null){

      //open registration webview

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => new rd.RealDebrid(oauth_data: data),
        ),);

      print("rd response $result");

      //saving the token info, for future use

      if (result["access_token"] != null ){

        /*
        * IMPORTANT RD INFO - DO NOT DELETE
        * 0 - Access Code
        * 1 - Refresh Token
        * 2 - Expires in
        * */

        List<String> _cred = [result["access_token"],
        result["refresh_token"],
        DateTime.now().add(new Duration(seconds: result["expires_in"])).toString()];

        await settingsPref.saveListPref("rdCredentials", _cred);

        setState(() {
          _rdCred = _cred;
        });
      }


    } else {

      showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_){
            return AlertDialog(
              title: TitleText("Real Debrid authentication failed!"),
              content: Text("Unable to connect to Real Debrid. Try again later.",
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
  }

  void _clearRDCredentials() {

    //Ask user for confirmation
    showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_){
          return AlertDialog(
            title: TitleText("Disconnect from Real-Debrid"),
            content: Text("Are you sure ?",
              style: TextStyle(
                  color: Colors.white
              ),
            ),
            actions: <Widget>[
              Center(
                child: FlatButton(
                  child: TitleText("Yes", textColor: Colors.white),
                  onPressed: (){

                    //clear rd credentials
                    setState(() {
                      _rdCred = [];
                      settingsPref.saveListPref("rdCredentials", []);
                    });

                    Navigator.pop(context);
                  },
                )
              )
            ],
            //backgroundColor: Theme.of(context).cardColor,
          );
        }
    );
  }

}