This is Taginator, the last tags generator you need.

# Install

Install [jsctags](https://github.com/mozilla/doctorjs) first, if you want to generate
tags for JavaScript.

* `npm install -g coffee-script`

# Development

Use nodemon to automatically restart the app:

    nodemon -e .coffee,.js,.json -w /home/YOURHOMEDIR/.taginator.json -w .  --exec coffee taginator.coffee
