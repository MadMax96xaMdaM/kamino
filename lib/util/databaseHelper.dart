import 'dart:io';

import 'package:objectdb/objectdb.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

//do not change value or remove until further notice
// backup - "<ApolloQuery>"
const querySplitter = "<ApolloQuery>";

Future saveFavorites(String name, String contentType, int tmdbid, String url, String year) async{

  ObjectDB db = ObjectDB(await _getDBPath());

  //open connection to the database
  db.open();

  Map dataEntry = {
    "name": name,
    "docType": "favorites",
    "contentType": contentType,
    "tmdbID": tmdbid,
    "imageUrl": url,
    "year": year,
    "saved_on": DateTime.now().toUtc().toString()
  };

  await db.insert(dataEntry);
  print("wrote $dataEntry to the database");

  // 'tidy up' the db file
  db.tidy();

  await db.close();
}

Future<List<int>> getAllFavIDs() async {

  List<int> _results = [];

  //get the path of the database file
  ObjectDB db = ObjectDB(await _getDBPath());

  //open connection to the database
  db.open();

  List<Map> _data = await db.find({"docType": "favorites"});

  for (int x=0; x < _data.length ; x++){

    _results.add(_data[x]["tmdbID"]);
  }

  await db.close();

  return _results;
}

Future<bool> isFavorite(int tmdbid) async{

  //get the path of the database file
  ObjectDB db = ObjectDB(await _getDBPath());

  //open connection to the database
  db.open();

  var results = await db.find({
        "docType": "favorites",
        "tmdbID":tmdbid
      });

  db.close();

  //return true if the show is a known favorite, else return false
  return results.length == 1 ? true : false;
}

Future removeFavorite(int tmdbid) async {

  //get the path of the database file
  ObjectDB db = ObjectDB(await _getDBPath());

  //open connection to the database
  db.open();
  
  //remove the item from the database
  db.remove({"docType": "favorites", "tmdbID":tmdbid});

  // 'tidy up' the db file
  db.tidy();

  db.close();
}

Future<List<String>> getSearchHistory() async {

  //get the path of the database file
  ObjectDB db = ObjectDB(await _getDBPath());

  db.open();

  Map _data = {
    "results": await db.find({ "docType": "searchHistory"}),
  };

  //db.tidy();

  await db.close();

  print("I found these search histories: $_data");

  //[0]["queries"] == null ? [] : _data[0]["queries"].split(querySplitter)

  if (_data["results"].length == 0){
    return [];
  }

  return _data["results"].split(querySplitter);
}

Future saveSearchHistory(String newHistory) async {

  if (newHistory.isEmpty != true){
    //get the path of the database file
    ObjectDB db = ObjectDB(await _getDBPath());

    db.open();

    //get the current query values
    List<Map> _currentHistory = await db.find({
      "docType": "searchHistory"
    });

    // add the new value to the end
    String _finalHistory;

    if (_currentHistory[0]["queries"] == null){
      _finalHistory = newHistory;
    } else {
      _finalHistory = _currentHistory[0]["queries"]+querySplitter+newHistory;
    }

    await db.update({
      "docType": "searchHistory"
    },{
      "queries": _finalHistory
    });

    db.tidy();

    await db.close();
  }
}

Future<List<Map>> getFavMovies() async {

  //get the path of the database file
  ObjectDB db = ObjectDB(await _getDBPath());

  db.open();

  var _result = await db.find({
    "docType": "favorites",
    "contentType": "movie"
  });

  print("get movies returned ${_result.length}");

  db.close();

  return _result.length == 0 ? [] : _result;
}

Future<List<Map>> getFavTVShows() async {

  //get the path of the database file
  ObjectDB db = ObjectDB(await _getDBPath());

  db.open();

  List<Map> _result = await db.find({
    "docType": "favorites",
    "contentType": "tv"
  });

  print("get tv returned ${_result.length} items");
  print("get tv returned these $_result");

  db.tidy();

  await db.close();

  return _result.length == 0 ? [] : _result;
}


Future<String> _getDBPath() async {

  //get the path of the database file
  String path = "";

  final DBdir = new Directory(
      (await getExternalStorageDirectory()).path + "/.apollo/db");

  if(!DBdir.existsSync()){
    await DBdir.create();
    final dbFile = new File("${DBdir.path}/apolloDB.db");
    print("creating a new database file, did not find an existing db file");
    path = dbFile.path;

  }else{
    print("found an existing db file");
    path = DBdir.path + "/apolloDB.db";
  }

  return path;
}

Future<Map> getAllFaves() async {

  ObjectDB db = ObjectDB(await _getDBPath());
  db.open();

  Map _result = {
    "tv": await db.find({"docType": "favorites", "contentType": "tv"}),
    "movie": await db.find({"docType": "favorites", "contentType": "movie"}),
  };

  await db.close();

  print(_result);
  return _result;
}

Future<String> bulkSaveFavorites(List<Map> documents) async {

  //get the path of the database file
  final directory = await getApplicationDocumentsDirectory();
  final path =  directory.path  + "/apolloDB.db";
  var db = ObjectDB(path);

  //open connection to the database
  db.open();

  await db.insertMany(documents);
  print("wrote ${documents.length} favorites to the database");

  // 'tidy up' the db file
  db.tidy();
  await db.close();

  return "done";
}