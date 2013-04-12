#### Facet View

$ ->

    # A facet view has a type name (i.e. Team) and a list of distinct values
    # (i.e. Shop, Management...) and allows to filter the items collection.
    # Appart from that, theres not much meat on the grill here.
    class window.FacetView extends Backbone.View


        tagName: 'li'


        template: _.template $('#facet-template').html()


        render: () =>

            @$el.html @template @model.toJSON()

            # Set data-name as the category (i.e. team)
            @$el.attr 'data-name',  @model.get 'name'

            # Set data-title as the id of the facet (i.e. Shop)
            @$el.attr 'data-title', 'facet'

            @
