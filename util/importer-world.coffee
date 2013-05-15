#!/usr/bin/env coffee

require "coffee-script"

request = require "request"
solr = require "solr-client"

schema = require '../entities/world/schema.json'

SolrManager = require '../server/solrManager'
solrManager = new SolrManager

fs = require "fs"
async = require "async"
_ = require "underscore"

verbose = false
log = (arg...) ->
    console.log(arg...) if verbose

# Config. Please set the next variables to suit your needs.
url = 'http://ws.geonames.org/countryInfoCSV'
dbSettings =
    host: "solr2-zalandoapp.rhcloud.com"
    port: "80"
    core: ""
    path: "/solr"
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
        log 'Fetching countries info'

        request url, (err, res, body) ->
            throw err if err
            data = csv2json body
            log 'Fetched ', data.length, 'countries'

            console.log 'Adding entries...'
            i = 0
            async.eachSeries data,
                (srcItem, cb) ->

                    return cb() unless srcItem.name and srcItem["iso alpha2"]

                    item = newItem srcItem

                    solrClient.add [ item ], (err, result) ->
                        throw err if err
                        i++
                        cb()
                , (err) ->
                    throw err if err
                    log 'Added ', i, ' entries.'
                    solrClient.commit () ->
                        date = new Date()
                        console.log date.toString(), "- World Solr restored."

newItem = (srcItem) ->
    item = {}
    _.each schema, (field) ->
        item[field.id] = srcItem[field.id] if srcItem[field.id]
        if field.id is 'languages'
            item[field.id] = []
            _.each srcItem[field.id].split(','), (l) ->
                item[field.id].push l if l
    item = solrManager.addObjSuffix 'world', item
    item.id = srcItem['iso alpha2']
    item

csv2json = (csvdata) ->
    lines = csvdata.split '\n'
    header = lines[0].split '\t'
    lines = lines.slice(1)
    arr = []
    _.each lines, (line) ->
        item = {}
        _.each line.split('\t'), (field, index) ->
            item[header[index]] = field
        arr.push item
    arr


