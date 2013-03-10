fs = require 'fs'
os = require 'os'
byline  = require 'byline'
path = require 'path'
exec = require('child_process').exec
S = require 'string'
Gaze = require('gaze').Gaze
_ = require 'lodash'
helper = require './helper'
require 'consoleplusplus'

class Project
    constructor: (config) ->
        _.forOwn config, (value, key) =>
            @[key] = value

        @notifiedFiles = []


    # check for user errors (users ..... :p )
    sanitize: (errors, warnings) ->
        console.debug 'Start sanitazing project:'
        asString = JSON.stringify(@)
        console.debug @name, asString

        if !_.has @, 'cwd' or !_.isString @cwd
            errors.push "Project has no 'cwd' set! - " + asString
            return false

        if !_.has @, 'name' or !_.isString @name
            warnings.push "Project has no 'name' set! - " + asString
            @name = "configure name here!"

        if !_.has @, 'globs' or !_.isArray @globs
            warnings.push "Project has no 'globs' set! - " + asString
            @globs = []

        if !_.has @, 'output' or !_.isString @output
            warnings.push "Project has no 'output' set! - " + asString
            @output = '/tmp/'

        if !_.has @, 'inputDirs' or !_.isArray @inputDirs
            warnings.push "Project has no 'inputDirs' set! - " + asString
            @inputDirs = []

        if _.has @, 'ctagArgs' and !_.isArray @ctagArgs
            warnings.push "Project has ctagArgs property but it isn't an array - " + asString
            @ctagArgs = []

        if !_.has @, 'ctagArgs'
            @ctagArgs = []

        if _.has @, 'extensions' and !_.isArray @extensions
            warnings.push "@ has extensions property but it isn't an array - " + asString
            @extensions = []

        if !_.has @, 'extensions'
            @extensions = []

        true


    # genereate all tags and replace current file
    generateAllTags: () ->
        cmd = "ctags "
        # add static args from config
        cmd += "#{arg} " for arg in @ctagArgs
        cmd += "-f #{@output} "
        cmd += "#{inputDir} " for inputDir in @inputDirs
        console.debug "run ctags command: #{cmd}"
        exec(cmd, {cwd: @cwd}, helper.print)

    # delete tags in tag file for current file and append newly generated tags
    regenerateTagsForFile: () ->
        if not fs.existsSync(@output)
            # generat all tags because file not exists
            console.info "generat all tags because output file not exists in project #{@name}"
            @generateAllTags()
            return

        filename = S(@notifiedFiles[0])
        relativeFileName = filename.replaceAll(@cwd, '')
        newFile = []
        # callback for tags generation after current usages removed
        appendTags = () =>
            cmd = "ctags "
            # add static args from config
            cmd += "#{arg} " for arg in @ctagArgs
            cmd += "-a "
            cmd += "-f #{@output} "
            cmd += relativeFileName
            console.debug "run ctags command: #{cmd}"
            exec(cmd, {cwd: @cwd}, helper.print)

        # remove tags first
        console.debug "remove tags for filename #{relativeFileName} in project #{@name}"
        stream = byline(fs.createReadStream(@output))

        stream.on 'data', (line) ->
            line = S(line)
            # filter empty lines and lines containing tags for the current file
            if line.contains(relativeFileName) isnt true and line.isEmpty() isnt true
                newFile.push(line)

        stream.on 'end', () =>
            console.debug 'write tags file with removed tags'
            newFile.push(os.EOL)
            fs.writeFile @output, newFile.join(os.EOL), 'utf-8', _.bind appendTags, @

    # check if generating tag action is needed and issue command
    generateTags: (filename, filesChanged) ->
        console.debug "check if tags generation needed for project #{@name}"
        console.debug "items: ", filesChanged, @notifiedFiles.length

        # if more files are added to this array we should not generate tags yet
        if @notifiedFiles.length isnt filesChanged
            return

        # check if valid file was changed
        @notifiedFiles = @notifiedFiles.filter (filename) =>
            filename = S(filename)
            tested = (filename.endsWith extension for extension in @extensions)
            if _.contains(tested, false)
                console.debug "not a valid file to generate tags for #{filename}"
                false
            else
                true

        console.debug @notifiedFiles.length + " valid files: " + @notifiedFiles.join(', ')

        # no more new changed files added, start generating tags
        if @notifiedFiles.length >= 2
            console.info "generate all tags and refresh notifier for project #{@name}"
            @generateAllTags()

            # refresh notifies because when more files changed, this is often caused by
            # git rebase/merge or other operations which add and remove files
            @refreshNotifies()

        if @notifiedFiles.length is 1
            console.info "generate tags for file for project #{@name}"
            @regenerateTagsForFile()

        # reset changed flies array for next round
        @notifiedFiles = []


    # helper to debounce tags generating when more files changed in a short
    # amount of time
    onFileChanged: (event, filename) ->
        console.debug "changed file in project #{@name}: ", filename

        # trak how many files changed since last tags generation
        @notifiedFiles.push filename
        filesChanged = @notifiedFiles.length

        # delay task so it can check if other files are changed in the mean time
        _.delay(_.bind(@generateTags, @, filename, filesChanged), 500)

    # set project up
    setUp: (errors, warnings) ->
        # check config
        correct = @sanitize errors, warnings
        if not correct then return @

        # expand home dir string "~/"
        @globs = (helper.expandHomeDir dir for dir in @globs)
        @inputDirs = (helper.expandHomeDir dir for dir in @inputDirs)
        @[prop] = helper.expandHomeDir @[prop] for prop in ['cwd', 'output']

        # log modified project config
        console.debug "Config of project #{@name}", JSON.stringify @

        # set up notification function
        @refreshNotifies = () ->
            # mock method once, at first call there are no notifications to close
            @watcher =
                close: () ->
                    console.debug 'called mocked "close" function, this is ok'
                    return

            # create new method
            @refreshNotifies = () ->
                @watcher.close()
                @watcher = new Gaze @globs
                @watcher.on 'all', _.bind @onFileChanged, @

                @watcher.on 'error', (error) ->
                    errorString = "project #{@name} :" + error.toString()
                    console.error errorString
                    errors.push(errorString)

            # call new method
            @refreshNotifies()

        # init notifications
        @refreshNotifies()

        # generat tags first time
        @generateAllTags()

        return @

# export class
module.exports = Project
