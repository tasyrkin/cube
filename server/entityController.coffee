###
# EntityController.coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

# Requirements

fs      = require 'fs'
async   = require 'async'
js2xml  = require "data2xml"
_       = require 'underscore'
im      = require "imagemagick"

# Facet Manager. distincts() gets a list of unique facet values.
FacetManager = require './facetManager.coffee'
facetManager = new FacetManager

# Solr Manager handles property suffixes (i.e. adding -s for string fields).
SolrManager = require './solrManager.coffee'
solrManager = new SolrManager

# Schema class provides methos to handle schemas easily.
Schema = require './schema'

# Server and default entity settings
settings = require "#{__dirname}/../server.settings.coffee"

# List of available entities
entities = require "#{__dirname}/../entities.json"


class EntityController

    module.exports = EntityController

    # Entity routes
    constructor: (app) ->
        app.get   '/:entity/schema',          (a...) => @schema     a...
        app.get   '/:entity/settings',        (a...) => @settings   a...
        app.get   '/:entity/collection',      (a...) => @collection a...
        app.get   '/:entity/pane.json',       (a...) => @pane       a...
        app.get   '/:entity/etiquettes.json', (a...) => @etiquettes a...
        app.get   '/:entity/ufacets',         (a...) => @ufacets    a...
        app.post  '/:entity/picture',         (a...) => @picture    a...
        app.get   '/:entity/template',        (a...) => @template   a...

    # Return appropriate schema for each entity
    schema: (req, res) ->
        name = req.params.entity
        return res.send 404 if entities.indexOf(name) is -1
        schema = require "#{__dirname}/../entities/#{name}/schema.json"
        res.send schema

    # Return appropriate settings for each entity
    settings: (req, res) =>
        name = req.params.entity
        return res.send 404 if entities.indexOf(name) is -1
        @getSettings name, (settings) =>
            @getEntities () ->
                settings.entities = entities
                res.send settings

    # Return a collection based on the filter parameters.
    collection: (req, res) =>
        name = req.params.entity
        return res.send 404 unless @isEntity(name)
        @createQuery req, (query, db) =>
            query = @setFilters req, query
            @getCollection db, query, (result) =>
                res.send @setCollectionResponse req, res, result

    # Returns pane.json, containing extra data for custom panes.
    pane: (req, res) ->
        file = "#{__dirname}/../entities/#{req.params.entity}/pane.json"
        res.setHeader 'Content-Type', 'application/json'
        fs.readFile file, "utf8", (err, data) =>
            return res.send {} if err
            res.send data


    # Returns an array of etiquettes available. Each etiquette defines an ID,
    # a Label, Bacgrkound color, Text color and a background image.
    etiquettes: (req, res) ->
        file = "#{__dirname}/../entities/#{req.params.entity}/etiquettes.json"
        res.setHeader 'Content-Type', 'application/json'
        fs.readFile file, "utf8", (err, data) =>
            return res.send {} if err
            res.send data

    # Get unique values from all the facet fields. Useful for autocomplete.
    ufacets: (req, res) =>
        facetManager.distincts req.params.entity, (d) =>
            res.send d

    # Picture uploader. Save picture on tmp location, convert, manipulate and
    # move to storage location. Respond with an array of properties from the
    # uploaded image. Useful for backbone.
    picture: (req, res) =>
        name = req.params.entity
        upload_id = req.files.picture.path
        target_filename = upload_id + '.jpg'
        target_path= "public/images/#{name}/archive/"
        target_file = target_path + target_filename
        tmp_file = 'public/images/tmp/' + target_filename
        url_file = "/images/tmp/" + target_filename
        response = [ name: target_filename, url: url_file, type: "image/jpeg" ]
        im_params =  [
            "#{target_file}", '-thumbnail', '300x300^', '-gravity', 'center',
            '-extent', '300x300', 'public/images/tmp/' + target_filename
        ]

        fs.rename upload_id, target_file, (err) ->
            throw err if err
            im.convert im_params, (err, stdout, stderr) ->
                throw err if err
                fs.stat tmp_file, (err, stats) ->
                    throw err if err
                    response.push size: stats.size
                    res.send response

    # Return templates from an entity
    template: (req, res) ->

        res.render "../entities/#{req.params.entity}/templates"

    # Run query and return either CSV, JSON or XML
    getCollection: (db, query, cb) =>
        db.search query, (err, result) =>
            docs = []
            return cb(docs) unless result and result.response
            _.each result.response?.docs, (doc) ->
                docs.push solrManager.removeSuffix doc
            result.response?.docs = docs
            cb result

    # Return all available entities with its settings
    getEntities: (cb) =>
        es = {}
        fs.readFile "#{__dirname}/../entities.json", (err, e) =>
            throw err if err
            entities = JSON.parse e
            async.forEach entities, (name, cb) =>
                @getSettings name, (s) =>
                    es[name] = s
                    cb()
            , (err) ->
                throw err if err
                return cb es

    # Read settings file from extension and return it as JSON object
    getSettings: (entity, cb) =>
        settingsFile = "#{__dirname}/../entities/#{entity}/settings.json"
        fs.readFile settingsFile, (err, s) =>
            throw err if err
            cb(JSON.parse(s))

    # Get the sort parameter. If its not specified on QS, the default value
    # is specified in the settings file.
    getSort: (req, cb) =>

        name = req.params.entity

        schema = new Schema name

        @getSettings name, (settings) =>
            sort = if req.query.sort then req.query.sort else settings.sort
            [ id, order ] = sort.split ':'
            if sort.split(':').length is 3
                [id1, id2, order] = sort.split ':'
                id = "#{id1}:#{id2}"
            field = schema.getFieldById id

            # Solr can't sort multivalue fields. There is a stringified copy
            # of each mv field with the suffix -sort appended to its id.
            if @isMultivalue field then id = "#{id}-sort"
            else id = solrManager.addSuffix name, id

            sort = {}
            sort[id] = order

            cb sort

    # Returns a new a solr query object ready to perfom searches on the
    # requested entity's collection.
    createQuery: (req, cb) =>
        name = req.params.entity
        @getSettings name, (settings) =>
            q = if req.query.q then "#{req.query.q}*" else "*:*"
            rows =  req.query.rows or settings.rows
            start = rows*req.query.page || 0
            @getSort req, (sort) =>
                solrManager = new SolrManager name
                db = solrManager.createClient()
                query = db.createQuery()
                    .q(q)
                    .sort(sort)
                    .defType("edismax")
                    .pf(@getSearchableFields(name))
                    .qf(@getSearchableFields(name))
                    .start(start)
                    .rows(rows)
                    .facet on: yes, missing: yes, mincount: 1
                cb query, db

    # Set response of a collection request, depending on the format asked.
    setCollectionResponse: (req, res, result, cb) =>
        if req.query.csv
            res.setHeader 'Content-Type', 'text/plain; charset=utf8'
            result = @toCSV req.params.entity, result

        if req.query.xml
            res.setHeader 'Content-Type', 'text/xml'
            result = js2xml 'root', result

        if req.query.json
            res.setHeader 'Content-Type', 'application/json'
            result = result.response.docs
        result

    # Adds filter parameters to query object, like facet filters, strings, etc.
    setFilters: (req, query) =>
        name = req.params.entity
        if req.query["facet.field"]
            ff = req.query["facet.field"]
            # FIXME Incapable of handling only 1 facet.
            if typeof ff isnt typeof []
                ff = [ ff ]
            fields = []
            _.each ff, (f) ->
                fields.push solrManager.addSuffix name, f
            query.facet field: fields

        if req.query.fs
            fqFields = {}
            fq = req.query.fs

            # Handle an array of facet filters
            if typeof fq is typeof []
                _.each fq, (fq) ->
                    f = fq.split(':')
                    f[0] = solrManager.addSuffix(name, f[0])
                    # If no value, use it to exclude field
                    f = [ "-#{f[0]}", '["" TO *]'] if f[1] is ''

                    fqFields[f[0]] = [] unless fqFields[f[0]]
                    fqFields[f[0]].push f[1]
                _.each fqFields, (fields, f) ->
                    query.matchFilter true, f, fields

            # Handle just one facet filter
            if typeof fq is 'string'
                f = fq.split(':')
                f[0] = solrManager.addSuffix name, f[0]
                f = [ "-#{f[0]}", '["" TO *]'] if f[1] is ''

                query.matchFilter true, f[0], [f[1]]
        query

    # Return all fields specified as "searchable" (search: true) on the schema.
    getSearchableFields: (name) =>
        schema = new Schema name
        searchables = schema.getSearchables()
        fields = []
        _.each searchables, (f) =>
            return fields.push "#{f.id}-sort" if @isMultivalue f
            fields.push solrManager.addSuffix(name, f.id) if f.search
        return fields

    # Checks if the requested resource is one of the available entities
    isEntity: (name) =>
        return yes unless entities.indexOf(name) is -1
        return no

    # Checks if the requested field is multivalue. Facet and tuple fields are
    # multivalue by definition.
    isMultivalue: (field) =>
        return yes if field.multivalue
        return yes if field.type is 'facet' or field.type is 'tuple'
        return no

    # Parse an item and form a ';' separated string with its values
    toCSV: (name, res) ->
        schema = require "../entities/#{name}/schema.json"
        output = []
        fields = []
        headers = []

        _.each schema, (f) ->
            headers.push f.id
            fields.push f.id
        output.push headers.join ';'

        _.each res.response.docs, (doc) ->
            line = []
            _.each fields, (f) ->
                line.push doc[f]
            output.push line.join ';'

        return output.join '\n'
