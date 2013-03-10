require 'consoleplusplus'
path = require 'path'

# print to stdout
module.exports.print = (error, stdout, stderr) ->
    console.info stdout if stdout
    console.info stderr if stderr
    console.error error if error isnt null

# get user home to read project config file
module.exports.getUserHome = () ->
    name = if process.platform is 'win32' then 'USERPROFILE' else 'HOME'
    process.env[name]

# expand home dir shortcut to real directory
module.exports.expandHomeDir = (globname) ->
    if /^~\//.test globname
       globname = path.normalize(module.exports.getUserHome() + globname.slice(1))

    globname

