
_ = require 'underscore'

class Schema
    module.exports = Schema

    constructor: (@name) ->
        @fields = require "../extensions/#{@name}/schema.json"

    getFieldById: (id) =>
        field = {}
        _.each @fields, (f) =>
            field = f if f.id is id
        field

    getFieldsWithProperty: (property) =>
        fields = []
        _.each @fields, (f) =>
            fields.push f if f[property]
        fields

    getSearchables: () =>
        @getFieldsWithProperty 'search'
