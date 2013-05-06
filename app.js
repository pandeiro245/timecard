var JSRel = require('jsrel');
var express = require('express');
var app = express();  

app.get('*', function(req, res){
  if(req.url == "/node_dev"){
    node_dev(req, res);
  }else if(req.url.match("api")){
    api(req, res);
  }else{
    res.sendfile(__dirname + "/public" + req.url);
  }
});

var node_dev = function(req, res){
  body = "<a href=\"/\">back</a>";
  body += "<hr />";
  for(var i in req){
    body += i + ' is ' + req[i];
    body += "<br />";
  }
  body += "<hr />";
  body += "<a href=\"/\">back</a>";
  res.setHeader('Content-Type', 'text/html');
  res.setHeader('Content-Length', body.length);
  res.end(body);
};

var api = function(req, res){
  body = "{id: 1}";
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Content-Length', body.length);
  res.end(body);
}

app.listen(3000);
