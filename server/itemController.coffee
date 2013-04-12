###
# ItemController.coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

fs    = require 'fs'
_     = require 'underscore'
async = require 'async'
im    = require "imagemagick"
mime  = require "mime-magic"

settings = require "#{__dirname}/../server.settings.coffee"

SolrManager = require './solrManager.coffee'

class ItemController
    module.exports = ItemController

    constructor: (app) ->
        app.get     "/:entity/collection/:id",  (a...)  => @get     a...
        app.post    "/:entity/collection",      (a...)  => @post    a...
        app.put     "/:entity/collection/:id",  (a...)  => @put     a...
        app.delete  "/:entity/collection/:id",  (a...)  => @delete  a...

    get: (req, res) =>
        name = req.params.entity
        id = req.params.id.split('|')

        # Return just 1 item
        if id.length is 1 then return @getItemById name, id[0], (docs) ->
            res.send docs

        # Return an array of items
        docs = []
        async.forEach id, (id, cb) =>
            @getItemById name, id, (item) ->
                docs.push item[0]
                cb()
        , (err) ->
            throw err if err
            return res.send docs

    post: (req, res) =>
        name = req.params.entity
        solrManager = new SolrManager name
        db = solrManager.createClient()

        # Create and ID for the new item
        id = @generateId()

        # Get the id of the picture field
        picKey = @getPictureFields(name)[0]?.id

        # Create a new item with the id
        item = _.extend {id: id}, solrManager.addObjSuffix name, req.body

        # Send the formed item with id unless there is a picture
        if !req.body[picKey]
            return @addItem res, solrManager, item, (_item) =>
                res.send solrManager.removeSuffix _item

        # Get pic url
        tmp_pic = "#{__dirname}/../public/#{req.body[picKey]}"
        target_file = "#{id}.jpg"
        target_path = "#{__dirname}/../public/images/#{name}/#{target_file}"

        # Move the picture to its final place and send item object back
        fs.rename tmp_pic, target_path, (err) =>
            throw err if err
            key = solrManager.addSuffix(name, picKey)
            item[key] = "/images/#{name}/#{target_file}" unless err
            @addItem res, solrManager, item, (_item) =>
                res.send solrManager.removeSuffix _item

    put: (req, res) ->
        name = req.params.entity
        solrManager = new SolrManager name
        db = solrManager.createClient()
        picKey = solrManager.addSuffix name, @getPictureFields(name)[0]?.id

        @getItemById name, req.params.id, (result) =>
            item = solrManager.addObjSuffix(name, result[0])
            req.body = solrManager.addObjSuffix(name, req.body)

            if req.query.admin isnt 'yes'
                protectedFields = @getFieldsWithProperty name, 'admin'
                _.each protectedFields, (f) =>
                    f = solrManager.addSuffix(name, f)
                    req.body[f.key] = item[f.key]
                    if f.multivalue
                        multivalueField = item[f.key].sort().join(" ")
                        req.body["sort_#{f.key}-s"] = multivalueField

            if !req.body[picKey] or req.body[picKey] is item[picKey]
                return @addItem res, solrManager, req.body, (_item) =>
                    res.send solrManager.removeSuffix _item

            @updatePic item.id, name, req.body[picKey], item[picKey], (path) =>
                req.body[picKey] = path
                @addItem res, solrManager, req.body, (_item) =>
                    res.send solrManager.removeSuffix _item

    updatePic: (id, name, bodyPic, itemPic, cb) =>
        tmp_pic = "#{__dirname}/../public/#{bodyPic}"
        rnd = bodyPic.slice(21, 24)
        target_file = "/images/#{name}/#{id}_#{rnd}.jpg"
        target_path = "#{__dirname}/../public/#{target_file}"

        fs.stat tmp_pic, (err, stat) ->
            if err then console.log "ERROR[uid=#{id}]: No uploaded picture"
            fs.unlink "#{__dirname}/../public/#{itemPic}", (err) ->
                fs.rename tmp_pic, target_path, (err) ->
                    throw err if err
                    cb target_file

    delete: (req, res) =>
        name = req.params.entity
        id = req.params.id
        solrManager = new SolrManager name
        db = solrManager.createClient()
        picKey = @getPictureFields(name)[0]?.id

        @getItemById name, id, (docs) =>
            _.each docs, (item) ->
                solrManager.client.deleteByID id, (err, result) ->
                    throw err if err
                    res.send result
                return unless picKey
                imgPath = "#{__dirname}/../public/#{item[picKey]}"
                fs.unlink imgPath, (err) ->
                    console.log "Failed to remove pic for user #{id}" if err


    getItemById: (name, id, cb) ->
        solrManager = new SolrManager name
        db = solrManager.createClient()

        query = db.createQuery()
            .q("id:#{id}")
            .start(0)
            .rows(1000)

        db.search query, (err, result) ->
            throw err if err
            docs = []
            _.each result.response?.docs, (doc) ->
                docs.push solrManager.removeSuffix doc
            cb docs

    getPictureFields: (name) ->
        schema = require "#{__dirname}/../extensions/#{name}/schema.json"
        arr = []
        _.each schema, (o) =>
            arr.push o if o.type is "img"
        arr

    addItem: (res, solrManager, item, cb) =>
        _item = _.extend {}, item
        solrManager.client.add [item], (err, result) ->
            throw err if err
            cb _item

    # Get all schema fields that cointain a property\
    # TODO Get from schema class
    getFieldsWithProperty: (name, p) ->
        schema = require "#{__dirname}/../extensions/#{name}/schema.json"
        arr = []
        _.each schema, (o) =>
            arr.push o if o[p]
        arr

    getFieldsByType: (name, t) ->
        schema = require "#{__dirname}/../extensions/#{name}/schema.json"
        arr = []
        _.each schema, (o) =>
            arr.push o if o.type is t
        arr

    # Generate an ID for the item on the db
    generateId: () ->
        chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        today = new Date()
        result = today.valueOf().toString 16
        result += chars.substr Math.floor(Math.random() * chars.length), 1
        result += chars.substr Math.floor(Math.random() * chars.length), 1
        result
