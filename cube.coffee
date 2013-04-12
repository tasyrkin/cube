#!/usr/bin/env coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
#
# @date: 11/2012

# Cube's nodejs server init

# Requirements
require "coffee-script"
express  = require "express"

# Main server configuration file. Please edit to your needs!
settings = require "./server.settings.coffee"

# Create express app
app = module.exports.app = express()

# The nodejs process will be called:
process.title = "cube"

# App directories
app.viewsDir  = settings.Paths.viewsDir
app.publicDir = settings.Paths.publicDir
app.coffeeDir = settings.Paths.coffeeDir

# Config file has express settings
require("./server.config.coffee")(app, express)

# Main routes file for express
require("./server.routes.coffee")(app, express)

# Listen usually on port 3000
app.listen settings.Web.defaultPort
