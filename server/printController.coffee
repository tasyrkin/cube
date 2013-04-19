###
# PrintController.coffee
#
# Renders the print view
#
# @author: Emanuel Lauria <emanuel.lauria@zalando.de>
###

class PrintController

    module.exports = PrintController


    # Print route
    constructor: (app) ->

        app.get "/:entity/print", (a...) => @print a...


    # Render print view
    print: (req, res) ->

        res.render 'printIndex', entity: req.params.entity
