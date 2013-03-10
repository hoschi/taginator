# dependencies
express = require 'express'
fs = require 'fs'
path = require 'path'
exec = require('child_process').exec
optimist = require 'optimist'
_ = require 'lodash'
helper = require './lib/helper'
Project = require './lib/Project'
require 'consoleplusplus'

# vars
projects = null
configs = null
configFile = '/.taginator.json'
github = 'http://github.com/hoschi/taginator'
errors = []
warnings = []

# setup options
argv = optimist
    .usage( "This app creates vim 'tags' files for your projects in the background.\n
Read the readme file at #{github} for more information.")
    .default('domain', 'localhost')
    .describe('domain', "Set the domain this app should list to.")
    .default('port', 3000)
    .argv

console.log optimist.help()
console.info "Starting application, open http://#{argv.domain}:#{argv.port}/ in your browser."

# configure express
app = express()

app.configure ->
    app.set 'view', __dirname + '/views'
    app.set 'view engine', 'jade'
    app.use express.bodyParser()
    app.use express.methodOverride()
    app.use app.router
    app.use '/public', express.static(__dirname + '/public')

##################################################################
# process configured projects
##################################################################

# load configs from
try
    configs = JSON.parse(
        fs.readFileSync(
            path.normalize(helper.getUserHome() + configFile), 'utf8'))
catch error
    errors.push error.toString()

if !_.isArray configs
    errors.push "Parsed config files don't contain an array!"

# create notifies for dirs in projects
if errors.length
    console.error errors
else
    projects = (new Project(config).setUp(errors, warnings) for config in configs)

# define routes
app.get '/', (req, res) ->
    res.render 'index',
        title: 'Taginator'
        configFile: configFile
        projects: projects
        errors: errors
        warnings: warnings
        github: github

# start server
app.listen argv.port, argv.domain
