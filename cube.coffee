#!/usr/bin/env coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
#
# @date: 11/2012

# Cube's nodejs server init

# First things first. Coffee...Script.
require "coffee-script"

# Main server configuration file. Please edit to your needs!
settings = require "./server.settings.coffee"

# We all know express, don't we?
express  = require "express"

# Create express app
app = module.exports.app = express()

# The nodejs process will be called:
process.title = "cube"

# Jade templates usually live in views/
app.viewsDir  = settings.Paths.viewsDir

# Public static files usually live in public/
app.publicDir = settings.Paths.publicDir

# We are actually not using this
app.coffeeDir = settings.Paths.coffeeDir

# Config file has express settings
require("./server.config.coffee")(app, express)

# Main routes file for express
require("./server.routes.coffee")(app, express)

# Listen usually on port 3000
app.listen settings.Web.defaultPort

# Start cronjobs
cronJob = require('cron').CronJob
exec   = require('child_process').exec

new cronJob '00 0 0,6,12,18 * * *', () =>
    restoreData()
, null, yes

restoreData = () ->
    exec 'bash util/restore_images.sh', (err, stdout, stderr) =>
        return console.log 'error:', stderr if err
        console.log stdout
    require './util/importer-team.coffee'
    require './util/importer-geo.coffee'

restoreData()
