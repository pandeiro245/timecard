var data = require("fs").readFileSync("./public/partials/issue.html", "utf8");
var issue = "var views_issue = " + JSON.stringify(data);


function fileSaveContents( filename , str ){
  var fs = require("fs");
  var fileContent = "";

  var fd = fs.openSync(filename, "w");
  fs.writeSync(fd, str, 0, "ascii");
  fs.closeSync(fd);

  return fileContent;
};
console.log( fileSaveContents( './public/js_views/sample.js' , issue ) );
