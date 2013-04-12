#### Cube's nodejs configuration
# Basic configuration options for the nodejs server.

module.exports = (app, express) ->

    app.configure ->

        # Stylus and CoffeeScript files are in assets/{css,js}
        ConnectAssets = (require "connect-assets") build: yes, minifyBuilds: no

        app.set "views", app.viewsDir
        app.set "view engine", "jade"
        app.set "view options", { layout: false }

        app.use express.static "./public", maxAge: 0
        app.use(express.bodyParser({uploadDir:"./"}))
        app.use ConnectAssets

    app.configure "development", ->

        app.use express.errorHandler dumpExceptions: true, showStack: true
