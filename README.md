This is Taginator, the last tags generator you need.

# Install

Install [jsctags](https://github.com/mozilla/doctorjs) first, if you want to generate
tags for JavaScript.

* `npm install -g coffee-script`

# Usage

# Configuration

This project uses the library `node-glob`, so Windows users also must use forward
slashes instead of back slashes. Please read the note at the end of
[this site](https://github.com/isaacs/node-glob)

Using `~/` as a shortcut for your home dir is ok at OSs.

# Development

Use nodemon to automatically restart the app:

    nodemon -e .coffee,.js,.json -w /home/YOURHOMEDIR/.taginator.json -w .  --exec coffee taginator.coffee
