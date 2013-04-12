###
# EntityController.coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

fs      = require 'fs'
async   = require 'async'
js2xml  = require "data2xml"
_       = require 'underscore'
im      = require "imagemagick"

FacetManager = require './facetManager.coffee'
facetManager = new FacetManager

SolrManager = require './solrManager.coffee'
solrManager = new SolrManager

Schema = require './schema'

# Server and default extension settings
settings = require "#{__dirname}/../server.settings.coffee"
# List of entities
entities = require "#{__dirname}/../entities.json"

class EntityController

    module.exports = EntityController

    constructor: (app) ->
        app.get   '/:entity/schema',          (a...) => @schema     a...
        app.get   '/:entity/settings',        (a...) => @settings   a...
        app.get   '/:entity/collection',      (a...) => @collection a...
        app.get   '/:entity/pane.json',       (a...) => @pane       a...
        app.get   '/:entity/etiquettes.json', (a...) => @etiquettes a...
        app.get   '/:entity/ufacets',         (a...) => @ufacets    a...
        app.post  '/:entity/picture',         (a...) => @picture    a...
        app.get   '/:entity/extensions',      (a...) => @extension  a...

    # Return appropriate schema for each entity
    schema: (req, res) ->
        name = req.params.entity
        return res.send 404 if entities.indexOf(name) is -1
        schema = require "#{__dirname}/../extensions/#{name}/schema.json"
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

    # Returns extension code. i.e. newbies feature on team app.
    # WARN This route is being used by third party apps!
    pane: (req, res) ->
        file = "#{__dirname}/../extensions/#{req.params.entity}/pane.json"
        res.setHeader 'Content-Type', 'application/json'
        fs.readFile file, "utf8", (err, data) =>
            return res.send {} if err
            res.send data

    etiquettes: (req, res) ->
        file = "#{__dirname}/../extensions/#{req.params.entity}/etiquettes.json"
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

    # Return templates from an extension
    extension: (req, res) ->
        res.render "extensions/#{req.params.entity}/templates"

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
        settingsFile = "#{__dirname}/../extensions/#{entity}/settings.json"
        fs.readFile settingsFile, (err, s) =>
            throw err if err
            cb(JSON.parse(s))

    # Get the sort parameter. If its not specified on QS, the default value
    # is specified in the settings file.
    getSort: (req, cb) =>
        name = req.params.entity
        @getSettings name, (settings) =>
            sort = if req.query.sort then req.query.sort else settings.sort
            [ id, order ] = sort.split ':'
            if sort.split(':').length is 3
                [id1, id2, order] = sort.split ':'
                id = "#{id1}:#{id2}"
            field = solrManager.getFieldFromSchema name, id
            if @isMultivalue field then id = "sort_#{id}-s"
            else id = solrManager.addSuffix name, id
            sort = {}
            sort[id] = order
            cb sort

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

    getSearchableFields: (name) =>
        schema = new Schema name
        searchables = schema.getSearchables()
        fields = []
        _.each searchables, (f) =>
            return fields.push "sort_#{f.id}-s" if f.multivalue
            fields.push solrManager.addSuffix(name, f.id) if f.search
        return fields

    isEntity: (name) =>
        return yes unless entities.indexOf(name) is -1
        return no

    isMultivalue: (field) =>
        return yes if field.multivalue
        return yes if field.type is 'facet' or field.type is 'tuple'
        return no

    # Parse an item and form a ';' separated string with its values
    toCSV: (name, res) ->
        schema = require "../extensions/#{name}/schema.json"
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
