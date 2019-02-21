import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:kamino/view/settings/page_extensions.dart';
import 'package:package_info/package_info.dart';

import 'package:kamino/main.dart';
import 'package:kamino/ui/uielements.dart';
import 'package:kamino/animation/transition.dart';
import 'package:kamino/view/settings/utils/ota.dart' as OTA;

import 'package:kamino/view/settings/page_launchpad.dart';
import 'package:kamino/view/settings/page_appearance.dart';
import 'package:kamino/view/settings/page_other.dart';

class SettingsView extends StatefulWidget {

  @override
  _SettingsViewState createState() => _SettingsViewState();

  static final buildTypes = [
    "Pre-Release",
    "Beta",
    "Release Candidate",
    "Stable"
  ];

}

class _SettingsViewState extends State<SettingsView> {

  int _tapCount;
  List<String> _contributors;
  
  PackageInfo _packageInfo = new PackageInfo(
      appName: 'Unknown',
      packageName: 'Unknown',
      version: 'Unknown',
      buildNumber: 'Unknown'
  );

  @override
  void initState() {
    _fetchPackageInfo();
    _fetchContributors();

    _tapCount = 0;

    super.initState();
  }

  Future<Null> _fetchPackageInfo() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<Null> _fetchContributors() async {
    String content = await rootBundle.loadString("assets/contributors.txt");
    List<String> contributors = new List();

    for(String entry in content.split("\n")){
      if(entry != "") {
        contributors.add(entry);
      }
    }

    setState(() {
      _contributors = contributors;
    });
  }

  int versionTapCount = 0;

  @override
  Widget build(BuildContext context) {

    KaminoAppState appState = context.ancestorStateOfType(const TypeMatcher<KaminoAppState>());

    return Scaffold(
        appBar: AppBar(
          title: TitleText("Settings"),

          backgroundColor: Theme.of(context).backgroundColor,

          // Center title
          centerTitle: true,
        ),
        body: new Builder(builder: (BuildContext context) {
          return new Container(
            color: Theme.of(context).backgroundColor,
            child: new ListView(

                // It's recommended that you give at maximum three examples per setting category.

                children: <Widget>[

                  Padding(padding: EdgeInsets.symmetric(vertical: 5)),

                  Material(
                    color: Theme.of(context).backgroundColor,
                    child: ListTile(
                      title: TitleText("Launchpad"),
                      subtitle: Text("Modify your $appName launchpad."),
                      leading: new Icon(const IconData(0xe90B, fontFamily: 'apollotv-icons')),
                      onTap: (){
                        Navigator.push(context, FadeRoute(
                            builder: (context) => LaunchpadSettingsPage()
                        ));
                      },
                    ),
                  ),

                  Material(
                    color: Theme.of(context).backgroundColor,
                    child: ListTile(
                      title: TitleText("Appearance"),
                      subtitle: Text("Choose the app theme."),
                      leading: new Icon(Icons.palette),
                      enabled: true,
                      onTap: (){
                        Navigator.push(context, FadeRoute(
                            builder: (context) => AppearanceSettingsPage()
                        ));
                      },
                    ),
                  ),

                  Material(
                    color: Theme.of(context).backgroundColor,
                    child: ListTile(
                      title: TitleText("Extensions"),
                      subtitle: Text("Manage third party integrations."),
                      leading: new Icon(Icons.extension),
                      enabled: true,
                      onTap: (){
                        Navigator.push(context, FadeRoute(
                            builder: (context) => ExtensionsSettingsPage()
                        ));
                      },
                    ),
                  ),

                  Material(
                    color: Theme.of(context).backgroundColor,
                    child: ListTile(
                      title: TitleText("Sources"),
                      subtitle: Text("Manage content sources."),
                      leading: new Icon(Icons.dns),
                      enabled: true,
                      onTap: (){
                        Navigator.push(context, FadeRoute(
                            builder: (context) => OtherSettingsPage()
                        ));
                      },
                    ),
                  ),

                  Material(
                    color: Theme.of(context).backgroundColor,
                    child: ListTile(
                      title: TitleText("Other"),
                      subtitle: Text("Search preferences, Change language, Choose player, ..."),
                      leading: new Icon(Icons.settings),
                      enabled: true,
                      onTap: (){
                        Navigator.push(context, FadeRoute(
                            builder: (context) => OtherSettingsPage()
                        ));
                      },
                    ),
                  ),

                  Divider(),

                  Material(
                    color: Theme.of(context).backgroundColor,
                    child: ListTile(
                      title: TitleText("About $appName"),
                      leading: new Image.asset("assets/images/logo.png", width: 36, height: 36),
                      enabled: true,
                      subtitle: Text("v${_packageInfo.version} (Build ${_packageInfo.buildNumber}) \u2022 ${appState.getVendorConfigs()[0].getName()} ${_getBuildType()} Build"),
                      onTap: (){
                        _tapCount++;

                        if(_tapCount == 10){
                          Scaffold.of(context).showSnackBar(SnackBar(
                            //content: Text('"Every pair of jeans are skinny jeans if you\'re thicc enough" - Gagnef 12,016HE')
                            content: Text("\xE2\x9D\xA4 E.D.")
                          ));

                          _tapCount = 0;
                        }
                      }
                    ),
                  ),

                  Platform.isAndroid ? Material(
                    color: Theme.of(context).backgroundColor,
                    child: ListTile(
                      title: TitleText("Check for Updates"),
                      subtitle: Text("Checks for updates and downloads any that are found..."),
                      leading: new Icon(Icons.system_update_alt),
                      enabled: true,
                      onTap: () async {
                        OTA.updateApp(context, false);
                      },
                    ),
                  ) : Container(),

                  // It's okay to remove this, but we'd appreciate it if you
                  // keep it. <3
                  __buildContributorCard()
                ]
            )
          );
        }));
  }

  Widget __buildContributorCard(){
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Card(
        elevation: 10.0,
        color: Theme.of(context).cardColor,
        child: new Container(
            child: new Column(
              children: <Widget>[
                new Padding(
                    padding: EdgeInsets.only(top: 20, bottom: 10),
                    child: new Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          new Icon(Icons.accessibility),
                          new TitleText(
                            "  With thanks...",
                            fontSize: 24,
                          )
                        ]
                    )
                ),

                new Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: new Text(
                        "$appName was made possible by all of these amazing people:",
                        style: new TextStyle(
                            fontFamily: 'GlacialIndifference',
                            fontSize: 16
                        )
                    )
                ),

                new Padding(
                  padding: EdgeInsets.only(left: 20, right: 20, bottom: 40, top: 10),
                  child: new Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: (
                        _contributors != null ?
                        _contributors.map((entry) {
                          if(entry.startsWith("##")){
                            // TITLE entry.
                            return new Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  new Padding(
                                      padding: EdgeInsets.only(top: 20),
                                      child: TitleText(
                                          '${entry.replaceFirst("## ", "")}',
                                          textAlign: TextAlign.center,
                                          fontSize: 24
                                      )
                                  )
                                ]
                            );
                          }else{
                            // User entry
                            return new Row(
                                children: <Widget>[
                                  Text(
                                    entry,
                                    textAlign: TextAlign.left,
                                  )
                                ]
                            );
                          }
                        }).toList()
                            : <Widget>[
                          new CircularProgressIndicator(
                              valueColor: new AlwaysStoppedAnimation(
                                  Theme.of(context).primaryColor
                              )
                          )
                        ]
                    ),
                  ),
                )
              ],
            )
        ),
      ),
    );
  }

  String _getBuildType(){
    int buildType = int.tryParse(_packageInfo.buildNumber.split('').last);

    if(buildType != null) return SettingsView.buildTypes[buildType];
    return "Unknown";
  }

}
