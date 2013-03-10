# dependencies
express = require 'express'
fs = require 'fs'
byline  = require 'byline'
path = require 'path'
exec = require('child_process').exec
optimist = require 'optimist'
S = require 'string'
Gaze = require('gaze').Gaze
_ = require 'lodash'
require 'consoleplusplus'

# vars
projects = null
configFile = '/.taginator.json'
github = 'http://github.com/hoschi/taginator'
errors = []
warnings = []

# print to stdout
print = (error, stdout, stderr) ->
    console.info stdout if stdout
    console.info stderr if stderr
    console.error error if error isnt null

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

# check for user errors (users .....)
sanitize = (project) ->
    console.debug 'Start sanitazing project.'
    asString = JSON.stringify(project)
    console.debug project.name, asString

    if !_.has project, 'cwd' or !_.isString project.cwd
        errors.push "Project has no 'cwd' set! - " + asString
        return false

    if !_.has project, 'name' or !_.isString project.name
        warnings.push "Project has no 'name' set! - " + asString
        project.name = "configure name here!"

    if !_.has project, 'globs' or !_.isArray project.globs
        warnings.push "Project has no 'globs' set! - " + asString
        project.globs = []

    if !_.has project, 'output' or !_.isString project.output
        warnings.push "Project has no 'output' set! - " + asString
        project.output = '/tmp/'

    if !_.has project, 'inputDirs' or !_.isArray project.inputDirs
        warnings.push "Project has no 'inputDirs' set! - " + asString
        project.inputDirs = []

    if _.has project, 'ctagArgs' and !_.isArray project.ctagArgs
        warnings.push "Project has ctagArgs property but it isn't an array - " + asString
        project.ctagArgs = []

    if !_.has project, 'ctagArgs'
        project.ctagArgs = []

    if _.has project, 'extensions' and !_.isArray project.extensions
        warnings.push "Project has extensions property but it isn't an array - " + asString
        project.extensions = []

    if !_.has project, 'extensions'
        project.extensions = []

    true

# genereate all tags and replace current file
generateAllTags = () ->
    cmd = "ctags "
    # add static args from config
    cmd += "#{arg} " for arg in @ctagArgs
    cmd += "-f #{@output} "
    cmd += "#{inputDir} " for inputDir in @inputDirs
    console.debug "run ctags command: #{cmd}"
    exec(cmd, {cwd: @cwd}, print)

regenerateTagsForFile = (filename) ->
    if not fs.existsSync(@output)
        # generat all tags because file not exists
        console.info "generat all tags because output file not exists in project #{@name}"
        generateAllTags.call(@)
        return

    newFile = []
    # callback for tags generation after current usages removed
    appendTags = () =>
        cmd = "ctags "
        # add static args from config
        cmd += "#{arg} " for arg in @ctagArgs
        cmd += "-a "
        cmd += "-f #{@output} "
        cmd += filename
        console.debug "run ctags command: #{cmd}"
        exec(cmd, {cwd: @cwd}, print)

    # remove tags first
    relativeFileName = filename.replaceAll(@cwd, '')
    console.debug "remove tags for filename #{relativeFileName} in project #{@name}"
    #stream = byline(fs.createReadStream(@output))
    #stream.on 'data', (line) ->
        #if line.indexOf filename > -1
            #console.debug "----- found tag " + line
        #else
            #console.debug "----- line is ok " + line

# check if valid file was changed
isValidFile = (filename) ->
    filename = S(filename)
    @notifiedFiles = (filename.endsWith extension for extension in @extensions)
    if _.contains(tested, false)
        console.debug "not a valid file to generate tags for #{filename}"
        false
    else
        true


# check if generating tag action is needed and issue command
generateTags = (filename, filesChanged) ->
    console.debug "check if tags generation needed for project #{@name}"
    console.debug "items: ", filesChanged, @notifiedFiles.length

    # if more files are added to this array we should not generate tags yet
    if @notifiedFiles.length isnt filesChanged
        return

    @notifiedFiles = file for file in @notifiedFiles when isValidFile(@, file)

    # no more new changed files added, start generating tags
    if filesChanged > 2
        console.info "generate all tags and refresh notifier for project #{@name}"
        generateAllTags.call(@)

        # refresh notifies because when more files changed, this is often caused by
        # git rebase/merge or other operations which add and remove files
        @refreshNotifies()

    if filesChanged > 1
        console.info "generate tags for file for project #{@name}"
        regenerateTagsForFile.call(@, filename)

    # reset changed flies array for next round
    @notifiedFiles = []


# helper to debounce tags generating when more files changed in a short amount of time
onFileChanged = (event, filename) ->
    console.debug "changed file in project #{@name}: ", filename

    # trak how many files changed since last tags generation
    @notifiedFiles.push filename
    filesChanged = @notifiedFiles.length

    # delay task so it can check if other files are changed in the mean time
    _.delay(_.bind(generateTags, @, filename, filesChanged), 500)

# set project up to work
setUp = (project) ->
    # check config
    correct = sanitize project
    if not correct then return null

    # expand home dir string "~/"
    project.globs = (expandHomeDir dir for dir in project.globs)
    project.inputDirs = (expandHomeDir dir for dir in project.inputDirs)
    project[prop] = expandHomeDir project[prop] for prop in ['cwd', 'output']

    # init time for debouncing tags generation
    project.timeOfLastChange = 0
    project.notifiedFiles = []

    # log modified project config
    console.debug project.name, JSON.stringify project

    # set up notification function
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
            @watcher.on 'all',
                _.bind onFileChanged, @

            @watcher.on 'error', (error) ->
                # TODO put error to error array so it can be viewed in the frontend
                console.error error.toString()

        # call new method
        @refreshNotifies()

    # init notifications
    project.refreshNotifies()

# create notifies for dirs in projects
if errors.length
    console.error errors
else
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
