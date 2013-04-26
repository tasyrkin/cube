#!/usr/bin/env coffee

require "coffee-script"

request = require "request"
solr = require "solr-client"
schema = require '../entities/team/schema.json'

SolrManager = require '../server/solrManager'
solrManager = new SolrManager

fs = require "fs"
async = require "async"
_ = require "underscore"

data = require './dump.json'

verbose = false
log = (arg...) ->
    console.log(arg...) if verbose

# Config. Please set the next variables to suit your needs.
url = 'http://deployctl.zalando.net/fortunes/json'
dbSettings =
    host: "localhost"
    port: "38730"
    core: "team"
    path: "/cube-solr"
    autoCommit: yes

if process.argv.indexOf('-q') isnt -1 then verbose = no

solrClient = solr.createClient dbSettings.host,
  dbSettings.port, dbSettings.core, dbSettings.path
solrClient.autoCommit = dbSettings.autoCommit

deleteAllData = (cb) ->

    query = solrClient.createQuery()
        .q("*:*")
        .start(0)
        .rows(1000)

    solrClient.deleteByQuery "*:*", (err, result) ->
        log 'Deleted all entries'
        cb()

deleteAllData () ->
    addAllData()

addAllData = () ->
        log 'Adding entries...'
        i = 0
        async.eachSeries data,
            (item, cb) ->
                solrClient.add [ item ], (err, result) ->
                    throw err if err
                    i++
                    cb()
            , (err) ->
                throw err if err
                log 'Added ', i, ' entries.'
                solrClient.commit () ->
                    date = new Date()
                    console.log date.toString(), "- Solr restored."

newItem = (ids, srcItem) ->
    item = {}
    _.each srcItem.split(';'), (value, i) =>
        item[ids[i]] = value if value
    item
