###
# PrintController.coffee
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

class PrintController
    module.exports = PrintController

    constructor: (app) ->
        app.get "/:entity/print", (a...) => @print a...

    print: (req, res) ->
        res.render 'printIndex', entity: req.params.entity