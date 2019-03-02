import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';


final String _baseUrl = "https://kickasstorrents.cr/search/";
final String _seperator = "%20";
String _search_url = "";

Future<List<Map>> getTVTorrents(Map payload, bool hd_only) async{

  List<Map> torrents = [];

  String _season =
  payload["season"].toString().length < 2 ?
  "0"+payload["season"].toString() : payload["season"].toString();

  String _episode =
  payload["episode"].toString().length < 2 ?
  "0"+payload["episode"].toString() : payload["episode"].toString();

  String search_param =
      payload["show"].toString().replaceAll(" ",_seperator)+_seperator+
          payload["tv_year"].toString()+_seperator+"S"+_season +"E"+_episode;

  _search_url = _baseUrl+search_param+"/category/tv/";

  //table made up of odd and even columns
  List<String> columns = ["even", "odd"];

  for(int i = 0; i < columns.length; i++){

    //HTTP GET request to pull the webpage
    http.Response res = await http.get(_search_url);

    //response body converted to Document object so it can be parsed
    Document document = parser.parse(res.body);

    document.getElementsByClassName(columns[i]).forEach((Element element){

      Map _torrent = {
        "name": null,
        "size": null,
        "url": null,
        "magnet": null
      };

      _torrent["size"] = element.querySelector("td.nobr.center").text;

      element.querySelector("div.torrentname").children.forEach((Element element){
        if (element.className == "torType filmType"){
          _torrent["url"] = "https://kickasstorrents.cr/"+element.attributes["href"];
        }
      });

      _torrent["name"] = element.querySelector("a.cellMainLink").text;
      torrents.add(_torrent);

    });

  }

  //get the magnet for each link
  for(int i = 0; i < torrents.length; i++){

    http.Response res = await http.get(torrents[i]["url"]);
    Document document = parser.parse(res.body);

    document.getElementsByClassName("kaGiantButton ").forEach((Element element){
      if(element.className == "kaGiantButton "){
        torrents[i]["magnet"] = element.attributes["href"];
        //break;
      }
    });
  }

  return torrents;
}

Future<List<Map>> getMovieTorrents(Map payload, bool hd_only) async{

  List<Map> torrents = [];

  String _movie = payload["movie"].toString().replaceAll(" ", _seperator);
  String _year = payload["movie_year"].toString();
  String search_param = _movie+_seperator + _year;

  _search_url = _baseUrl+search_param+"/category/movies/";

  //table made up of odd and even columns
  List<String> columns = ["even", "odd"];

  for(int i = 0; i < columns.length; i++){

    //HTTP GET request to pull the webpage
    http.Response res = await http.get(_search_url);

    //response body converted to Document object so it can be parsed
    Document document = parser.parse(res.body);

    document.getElementsByClassName(columns[i]).forEach((Element element){

      Map _torrent = {
        "name": null,
        "size": null,
        "url": null,
        "magnet": null
      };

      _torrent["size"] = element.querySelector("td.nobr.center").text;

      element.querySelector("div.torrentname").children.forEach((Element element){
        if (element.className == "torType filmType"){
          _torrent["url"] = "https://kickasstorrents.cr/"+element.attributes["href"];
        }
      });

      _torrent["name"] = element.querySelector("a.cellMainLink").text;
      torrents.add(_torrent);

    });

  }

  //get the magnet for each link
  for(int i = 0; i < torrents.length; i++){

    http.Response res = await http.get(torrents[i]["url"]);
    Document document = parser.parse(res.body);

    document.getElementsByClassName("kaGiantButton ").forEach((Element element){
      if(element.className == "kaGiantButton "){
        torrents[i]["magnet"] = element.attributes["href"];
        //break;
      }
    });
  }

  return torrents;
}