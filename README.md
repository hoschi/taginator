# Taginator, the last tags generator you need

[![NPM](https://nodei.co/npm-dl/taginator.png)](https://nodei.co/npm-dl/taginator/)

[![NPM version](https://badge.fury.io/js/taginator.png)](http://badge.fury.io/js/taginator)

Start Taginator at your system startup or user login and it generates fresh tags files
for each of your projects. After that it watches your project for file changes and
updates the tags file if you change a file. If you change more files, e.g. with a
git rebase/checkout, Taginator waits till there are no change notifications any more
and generates the complete tags file again.

# Install

* run `npm install -g coffee-script` to make sure coffee-script is globally installed
* install this by hand
    * `git clone http://github.com/hoschi/taginator`
    * `cd taginator`
    * `npm install`
    * `bin/taginator`
* or with npm
    * `npm install -g taginator`

## Tags generation for JavaScript

Install [jsctags](https://github.com/mozilla/doctorjs) first, if you want to generate
tags for JavaScript. After that put [my ctags script](https://github.com/hoschi/scripts/blob/master/ctags) into your `~/bin/` directory
so it calls ctags or jsctags automatically.

# Configuration

Create the file `/.taginator.json` and put your project configurations in an array.
Here is an example configuration:

    [
        {
            "name":"test",
            "cwd":"~/vimtest/",
            "output":"~/vimtest/tags",
            "extensions":[
                "js"
            ],
            "ctagArgs":[
                "--language-force=javascript"
            ],
            "inputDirs":[
                "a/",
                "b/"
            ],
            "globs":[
                "~/vimtest/.git/**/*",
                "~/vimtest/a/**/*.js",
                "~/vimtest/b/**/*.js"
            ]
        }
    ]

Run taginator with your config or the example config and browse to
http://localhost:3000/ to see an explanation of your configuration.

Properties:

* `name` the name of the project
* `cwd` the current working directory of your project and base path for `inputDirs`
* `output` file path for the tags file
* `extensions` valid file extensions to generate tags for
* `ctagArgs` static arguments for the ctags command passed on every call for this project
* `inputDirs` for the ctags command
* `globs` which select the files should be watched

## Important notes

This project uses the library `node-glob`, so Windows users also must use forward
slashes instead of back slashes. Please read the note at the end of
[this site](https://github.com/isaacs/node-glob).

Using `~/` as a shortcut for your home dir is ok at all OSs.

The `cwd` property must have a trailing slash so it can be removed safely from
found files to make them relative paths. This config property is not optional!

# Usage

Start Taginator and let it update your tags files automatically :)
In vim I had to set the tags file in my `~/.vimrc` the following way
to enable jumping between tags:

    set tags=tags

# Development

Use nodemon to automatically restart the app:

    nodemon -e .coffee,.js,.json -w /home/YOURHOMEDIR/.taginator.json -w .  --exec coffee taginator.coffee


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/hoschi/taginator/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

