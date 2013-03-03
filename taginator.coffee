# dependencies
express = require 'express'
fs = require 'fs'
path = require 'path'
optimist = require 'optimist'
Gaze = require('gaze').Gaze
_ = require 'lodash'
require 'consoleplusplus'

# vars
projects = null
configFile = '/.taginator.json'
github = 'http://github.com/hoschi/taginator'
errors = []
warnings = []

# get user home to read project config file
getUserHome = () ->
    name = if process.platform is 'win32' then 'USERPROFILE' else 'HOME'
    process.env[name]

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

# load configs fromcreate closures file
try
    projects = JSON.parse(
        fs.readFileSync(
            path.normalize(getUserHome() + configFile), 'utf8'))
catch error
    errors.push error.toString()

if !_.isArray projects
    errors.push "Parsed config files don't contain an array!"

# helpers
expandHomeDir = (globname) ->
    if /^~\//.test globname
       globname = path.normalize(getUserHome() + globname.slice(1))

    globname

setUp = (project) ->
    asString = JSON.stringify(project)
    if !_.has project, 'name' or !_.isString project.name
        warnings.push "Project has no 'name' set! - " + asString
        project.name = "configure name here!"

    if !_.has project, 'globs' or !_.isArray project.globs
        warnings.push "Project has no 'globs' set! - " + asString
        project.globs = []

    project.globs = (expandHomeDir dir for dir in project.globs)
    console.debug project.name, JSON.stringify project.globs

    project.refreshNotifies = () ->
        # mock method once, at first call there are no notifications to close
        @watcher =
            close: () ->
                console.debug 'called mocked "close" function, this is ok'
                return

        # create new method
        @refreshNotifies = () ->
            @watcher.close()
            @watcher = new Gaze @globs
            @watcher.on 'all', (event, filename) ->
                console.debug "changed file in project #{@name}: ", filename

            @watcher.on 'error', (error) ->
                console.info 'error', error.toString()

        # call new method
        @refreshNotifies()

    # init notifications
    project.refreshNotifies()

# create notifies for dirs in projects
if errors.length <= 0
    setUp project for project in projects

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
