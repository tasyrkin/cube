#!/usr/bin/env coffee

require "coffee-script"

request = require "request"
solr = require "solr-client"

url = require 'url'
exec = require('child_process').exec

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
csvurl = 'http://ws.geonames.org/countryInfoCSV'
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

        request csvurl, (err, res, body) ->
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
        if field.id is 'continent'
            item[field.id] = 'Africa' if srcItem[field.id] is 'AF'
            item[field.id] = 'Asia' if srcItem[field.id] is 'AS'
            item[field.id] = 'Europe' if srcItem[field.id] is 'EU'
            item[field.id] = 'North America' if srcItem[field.id] is 'NA'
            item[field.id] = 'South America' if srcItem[field.id] is 'SA'
            item[field.id] = 'Oceania' if srcItem[field.id] is 'OC'
            item[field.id] = 'Antartica' if srcItem[field.id] is 'AN'
        if field.id is 'populationRange'
            return unless srcItem['population']
            population = parseFloat srcItem['population']
            return item[field.id] = "< 10k" if population < 10000
            return item[field.id] = "10k - 100k" if population < 100000
            return item[field.id] = "100k - 500k" if population < 500000
            return item[field.id] = "500k - 1m" if population < 1000000
            return item[field.id] = "1m - 10m" if population < 10000000
            return item[field.id] = "10m - 50m" if population < 50000000
            return item[field.id] = "50m - 100m" if population < 100000000
            return item[field.id] = "100m - 500m" if population < 400000000
            return item[field.id] = "500m - 1b" if population < 1000000000
            item[field.id] = "> 1b"
        if field.id is 'areaRange'
            return unless srcItem['areaInSqKm']
            area = parseFloat srcItem['areaInSqKm']
            return item[field.id] = "< 1k" if area < 1000
            return item[field.id] = "1k - 10k" if area < 10000
            return item[field.id] = "10k - 100k" if area < 100000
            return item[field.id] = "100k - 1m" if area < 1000000
            return item[field.id] = "1m - 5m" if area < 5000000
            return item[field.id] = "5m - 10m" if area < 10000000
            item[field.id] = "> 10m"
        if field.id is 'flag'
            flagurl = "https://www.cia.gov/library/publications/the-world-factbook/graphics/flags/large/#{srcItem['fips code'].toLowerCase()}-lgflag.gif"

            if srcItem['iso alpha2'] is 'AQ'
                flagurl = 'http://www.crwflags.com/fotw/images/a/aq!bart.gif'
            if srcItem['iso alpha2'] is 'BQ'
                flagurl = 'http://www.rootsweb.ancestry.com/~antwgw/NEAN002.GIF'
            if srcItem['iso alpha2'] is 'CW'
                flagurl = 'http://www.newtonnewtonflags.com/shop/shopimages/sections/thumbnails/curacao_flag.gif'
            if srcItem['iso alpha2'] is 'UM'
                flagurl = 'http://www.crwflags.com/fotw/images/u/um-wake.gif'
            if srcItem['iso alpha2'] is 'PS'
                flagurl = 'http://www.crwflags.com/fotw/images/a/arabcols.gif'
            if srcItem['iso alpha2'] is 'SX'
                flagurl = 'http://www.crwflags.com/fotw/images/s/sx.gif'
            if srcItem['iso alpha2'] is 'AX'
                flagurl = 'http://0.tqn.com/d/goscandinavia/1/0/Z/4/-/-/flag-of-aland.jpg'

            #download flagurl, srcItem['iso alpha2'].toLowerCase()
            item[field.id] = "/images/world/#{srcItem['iso alpha2'].toLowerCase()}.gif"

    item = solrManager.addObjSuffix 'world', item
    item.id = srcItem['iso alpha2']
    item

download = (fileurl, code) ->

    filename = "#{code}.gif"

    wget = "wget -O ./public/images/world/#{code}.gif #{fileurl}"

    child = exec wget, (err, stdout, stderr) ->
        return console.log 'no flag saved for', code, err if err
        console.log "flag saved", code

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


