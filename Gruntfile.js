module.exports = function(grunt){
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    coffee: {
        compile: {
            files: {
                'public/js/coffee.js': ['coffee/*.coffee'],
            }
        },
    },
    watch: {
        files: ['coffee/*.coffee'],
        tasks: 'coffee'
    }
  });
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.registerTask('default', 'coffee'); 
}
