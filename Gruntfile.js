module.exports = function(grunt){
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    coffee: {
        compile: {
            files: {
                'public/js/coffee.js': ['coffee/models/*.coffee', 'coffee/views/*.coffee', 'coffee/*.coffee', ],
                'app.js': ['app.coffee'],
            }
        },
    },
    watch: {
        files: ['coffee/*.coffee', "app.coffee", 'coffee/models/*.coffee', 'coffee/views/*.coffee'],
        tasks: 'coffee'
    }
  });
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.registerTask('default', 'coffee'); 
}
