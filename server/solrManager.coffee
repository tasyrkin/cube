###
# SolrManager.coffee
#
# Solr Manager provides useful functions to handle solr connections
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

solr  = require 'solr-client'
_     = require 'underscore'
Schema = require './schema'


class SolrManager

    module.exports = SolrManager

    constructor: (@name) ->

    # Create a Solr instance with propper database connection
    createClient: () =>
        db = require "../extensions/#{@name}/db.json"
        @client = solr.createClient db.host, db.port, db.core, db.path
        @client.autoCommit = yes
        @client

    addSuffix: (name, p) =>
        schema = new Schema name
        return p if p is "id" or p is undefined
        f = schema.getFieldById p
        sf = "-s"
        sf = "-i" if f.type is 'integer'
        sf = "-f" if f.type is 'float'
        sf += "m" if f.multivalue or f.type is 'facet' or f.type is 'tuple'
        sf += "r" if f.mandatory
        p + sf

    addObjSuffix: (name, obj) =>
        newObj = {}
        schema = new Schema name
        _.each obj, (v, k) =>
            ks = @addSuffix name, k
            f = schema.getFieldById k
            newObj[ks] = v
            return unless f.type is 'facet' or f.type is 'tuple' or f.multivalue
            if typeof v isnt typeof [] then v = v.toString().split(',')
            newObj[ks] = []
            _.each v, (value) ->
                newObj[ks].push value
                if value.indexOf('/') isnt -1
                    parent = value.split('/')[0]
                    newObj[ks].push parent if value.indexOf(parent) is -1
            newObj["sort_#{k}-s"] = newObj[ks].sort().join(' ')
        newObj

    removeSuffix: (obj) ->
        newObj = {}
        _.each obj, (v, k) ->
            return if k.indexOf('sort_') is 0
            k = k.split('-')[0]
            newObj[k] = v
        newObj
