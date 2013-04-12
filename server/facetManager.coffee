###
# EntityManager.coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###
async = require 'async'
_     = require 'underscore'

SolrManager = require './solrManager.coffee'

class FacetManager
    module.exports = FacetManager

    constructor: () ->

    distincts: (name, cb) =>
        d = {}
        async.forEach @getFacetsFromSchema(name), (f, cb) =>
            @fields name, f.id, (data) ->
                d[f.id] = data
                cb()
        , (err) =>
            throw err if err
            cb d

    # Return all fields for each facet (i.e. teams: interactive, catalog..)
    fields: (name, field, cb) =>
        solrManager = new SolrManager name
        client = solrManager.createClient()

        query = client.createQuery()
            .q('*:*')
            .start(0)
            .rows(0)
            .facet on: yes, field: solrManager.addSuffix(name, field)

        fields = []
        client.search query, (err, result) =>
            throw err if err
            ff = result?.facet_counts?.facet_fields
            _.each ff[solrManager.addSuffix(name, field)], (f) ->
                fields.push(f) if typeof f is "string"
            cb fields

    # Parse schema and return all facet fields
    getFacetsFromSchema: (name) =>
        schema = require "../extensions/#{name}/schema.json"
        a = []
        _.each schema, (o) =>
            a.push o if o.type is 'facet'
        a

