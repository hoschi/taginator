# dependencies
express = require 'express'
fs = require 'fs'
path = require 'path'
optimist = require 'optimist'

# vars
config = null
configFile = '/.taginator.json'
github = 'http://github.com/hoschi/taginator'

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
console.log "Starting application, open http://#{argv.domain}:#{argv.port}/ in your browser."

# configure express
app = express()

app.configure ->
    app.set 'view', __dirname + '/views'
    app.set 'view engine', 'jade'
    app.use express.bodyParser()
    app.use express.methodOverride()
    app.use app.router
    app.use '/public', express.static(__dirname + '/public')

# load configs from file
try
    config = JSON.parse(
        fs.readFileSync(
            path.normalize(getUserHome() + configFile), 'utf8'))
catch error
    errorMessage = error.toString()

# routes
app.get '/', (req, res) ->
    res.render('index',
        title: 'Taginator'
        configFile: configFile
        projects: config
        error: errorMessage
        github: github
    )

# start server
app.listen(argv.port, argv.domain)

