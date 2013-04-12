#### The Cube
#
# Zalando's management tool (devcode: Team App)
#
# Please visit our github page to know more about this app!
#
# http://zalando.github.com/cube/
#
# or better, give it a look to the annotated source code at docs/
#
# @date:  Nov/2012
#
# @autor: Emanuel Lauria <emanuel.lauria@zalando.de>

$ =>

    # Backbone collection to hold all items from our team.
    @collection = new @Collection

    # Facets collection, holding all facet fields.
    @facets = new @Facets

    # Extensions
    @extensions = if @Extensions then new @Extensions else null

    #### Main View
    # Holds a new user profile view, handles search and filtering
    # on the items collection and updates between views and collections.
    class AppView extends Backbone.View

        el: $('#app')

        events:
            "keyup #inputSearch"            : "onSearchInput"
            "click a#add.btn"               : "addNewItem"
            "click ul#facet ul li .field"   : "handleFacetClick"
            "click span#reset a"            : "resetAllFilters"
            "click span#view"               : "toggleViewMode"
            "click ul#facet li ul span.fold": "toggleFacetSubfields"
            "click ul#facet>li>span.fold"   : "toggleFacetNode"
            "click ul#facet>li>h4"          : "toggleFacetNode"
            "click span#print"              : "print"
            "click span#json"               : "toJson"
            "click #entityTitle"            : "toggleEntitiesMenu"
            "click #columnsMenu"            : "toggleColumnsMenu"
            "click #columnOptions ul li"    : "toggleColumnVisibility"
            "click #entities ul li"         : "redirectToEntity"
            "click span#pageL"              : "previousPage"
            "click span#pageR"              : "nextPage"
            "click span#jumpToFirst"        : "jumpToFirst"
            "click span#jumpToLast"         : "jumpToLast"
            "click #footer li"              : "jumpToPage"
            "click table .th-inner"         : "sortTable"
            "mouseenter #columnsMenu"       : "overColumnsMenu"
            "mouseenter .th-inner"          : "showColumnsBtn"
            "mouseleave .th-inner"          : "hideColumnsBtn"
            "click"                         : "documentClick"

        #### Initialize App
        initialize: () =>

            # Create router object
            @router = new window.Routes

            # Set application settings from settings.json
            @setAppSettings()

            # Set collection settings like sort criteria or amount of rows
            @setColSettings()

            # Set the schema ffor the entity
            @createSchema()

            #TODO Avoid async getExtensions by passing it as param on render
            @getExtensions () =>
                @start()

            #### Collections bindings
            # * Add an item view if a new item is added to the col.
            # * Redraw all facet views if a new item is added to the col.
            # * Redraw all item views if the collection is fetched.
            # * Redraw all facet views if the facets col is fetched.
            window.collection.bind  'add',      @addOne,        @
            window.collection.bind  'add',      @updateFacets,  @
            window.collection.bind  'reset',    @reset,         @
            window.facets.bind      'reset',    @addAllFacets,  @

        start: =>

            # Set the application's title (extension name on top left)
            @setAppTitle()

            # Set view icon's state to show current view mode (top right).
            # If no pictures on the schema, thumbnail view mode is disabled
            @setViewMode()

            # Hide the index pane or resize it to appropriate size
            @setAppFacetsState()

            #Set Schema indexes from localStorage
            @setColumnSelection()

            # Create the columns menu
            @generateColumnsMenu()

            # Create the entities menu
            @generateEntitiesMenu()

            # Start loading animation timer (1second timeout)
            @showLoadingAnimation()

            # Fetch facets and start backbone history right after. This will
            # route to window.Settings.Separator which in turn will fetch
            # items and draw app.
            @initFacets()

            # Start app with search input text focused
            $('#inputSearch').focus() unless @isTablet()

            # Hide Add item button unless admin key is present
            @setAdminState()

            # Profile additional info open/close state. Default is closed.
            @setProfileState()

            # Listen for arrow keys to move between items
            @setMoveKeybindings()

        # Initialize facets collection by fetching them. Start history right
        # after and save the initial open state (expand/fold).
        initFacets: () =>
            window.facets.fetch success: () =>
                @hideError()
                Backbone.history.start()
                @setFacetOpenState()
            , error: () =>
                @showError()

        # Set the extension settings and other properties like etiquettes and
        # a list of entities to the window object.
        setAppSettings: () ->
            settings = window.settings
            settings.etiquettes = window.etiquettes
            settings.entities = window.entities
            window.Settings = settings

        # Set collection settings like sort and rows.
        setColSettings: () ->
            window.collection.sort = @getSort()
            window.collection.rows = window.Settings.rows

        # Set the application's title on top left corner (top entities menu)
        setAppTitle: () =>
            # Apply application name to title label and window title
            $('#header #entityTitle h1').html window.Settings?.title
            if window.Settings.entities.length > 1
                $('#header #entityTitle').addClass 'selectable'

        # Set the view mode to either list or thumbnail
        setViewMode: () =>
            if window.Settings?.Schema.getPictures().length is 0
                $('span#view').hide()
            $('span#view').addClass 'list' if window.Settings?.view is 'list'

        # Set the facet state: hide if no facets or resize to appropriate value
        # if facets are present. Facet size is stored in localStorage.
        setAppFacetsState: () =>
            facets = window.Settings.Schema.getFacets()
            return @disableFacets() unless facets.length
            @setIndexResizable()

        # Set the application administrator state if the admin key is present.
        setAdminState: () =>
            if @isEditable() and @isAdmin()
                $('a#add.btn').css 'display', 'block'

        # Set the profile state, basically just keeps track of the state of
        # the additional info section (open/closed).
        setProfileState: () =>
            window.additionalOpen = no

        # Append html on #controls (icons top right corner) and initialize
        # the extended javascript code.
        # TODO Avoid this async call
        getExtensions: (cb) =>
            $.get 'extensions', (exthtml) ->
                $('#app > #extensions').html exthtml
                return cb() unless $("#app > #extensions #controls").length
                t = _.template $("#app > #extensions #controls").html()
                $('#controls #extensions').append t({})
                window.extensions?.init?()
                cb()

        # Get schema and attach it to our Settings object
        createSchema: ->
            window.Settings?.Schema = new window.Schema window.schema

        # Keep an array of the selected facet fields
        # TODO Implement backbone collection
        filterSelection: new window.FacetArray

        # Keep an array of the facets expanded/folded state
        # TODO Implement backbone collection
        facetOpenState: new window.FacetArray

        # Array to store the selected item ids
        itemSelection: new window.Collection

        # Switches between list view mode and thumbnail view mode
        toggleViewMode: () =>
            v = if window.Settings.view is 'list' then 'thumbnail' else 'list'
            window.Settings.view = v

            $('span#view').removeClass 'list'
            $('span#view').addClass 'list' if v is 'list'

            @filterByPage () =>
                @scrollToSelection $('#items .active'), yes
                @navigate()

        # Add one item to the items container. Either in thumnail mode
        # (picture and name) or in list mode (pic, full name, teams, etc.)
        addOne: (m) =>
            if window.Settings.view is 'thumbnail'
                return window.App.addOneThumbnail(m)
            window.App.addOneList m

        # Add one item to the table of items (list view mode)
        addOneList: (item) =>
            view = new ItemListView model: item
            @$("table tbody", "#items").append view.render().el

        # Add one item with a thumbnail view
        addOneThumbnail: (item) =>
            view = new ItemThumbnailView model: item
            cat = item.get window.Settings.Schema.getClassifier().id
            cat = cat[0] if typeof cat is typeof []
            cat = 'null' if cat is undefined
            cat = window.categories.indexOf cat
            return @$("li\#category-#{cat} ul", '#items')
                .append view.render().el

        # Render all items in the given collection
        addAll: (col, cb) =>
            columnsMenuIsOpen = $('#columnsMenu').hasClass 'active'
            view = window.Settings.view
            render = @renderTableView
            render = @renderCategoryView if view is 'thumbnail'
            render () =>
                col.each @addOne
                @hideEmptyCategories() if view is 'thumbnail'
                @setTotals()
                @updateSelection()
                @scrollToSelection $($('#items .active')[0]), yes
                $('#columnOptions').show() if columnsMenuIsOpen
                $('#columnsMenu').addClass 'active' if columnsMenuIsOpen
                cb() if cb

        # Create an empty profileView to add an item
        addNewItem: () =>
            @clearSelection()
            @showProfile new window.Item
            window.profileView.form()
            @navigate()

        # Select one item with a normal click. Delete previous selection if
        # present and save selected item as the firstActiveItem
        selectOne: ($e, attr) =>
            @clearSelection()
            @addToSelection $e
            @scrollToSelection $e
            @showProfile window.collection.get($e.attr('id')), attr

        # Add a item to the selection array
        addToSelection: ($e) =>
            id = $e.attr 'id'
            $e.addClass 'active'
            window.firstActiveItem = id if @itemSelection.length is 0
            @itemSelection.add window.collection.get id

        # On list mode, when selection is too close to top or bottom border,
        # do a page up/down respectively.
        scrollToSelection: ($e, center) =>
            return unless $e.length
            posY = $e.offset().top - 90
            $container = $('.fixed-table-container-inner, .thumbnailContainer')
            scrollTop = $container.scrollTop()
            height    = $container.height()
            eHeight   = if window.Settings.view is 'list' then 39 else 196
            if posY + eHeight > height
                top = scrollTop + eHeight - (height - posY)
                top += height/2 if center
                return $container.scrollTop top
            if posY < 0
                top = scrollTop + posY + 1
                return $container.scrollTop top

        # Add one facet field with a title name and a list of values
        addOneFacet: (facet) ->
            view = new FacetView model: facet
            @$('ul#facet').append view.render().el

        # Add all facets from the facet collection
        addAllFacets: () =>
            $('ul#facet').html ''
            window.facets.each @addOneFacet
            @resizeIndex()
            @setFacetWidth()

        # Propperly removes older item views, re-renders category
        # containers, fetches a new item collection with filters applied
        # and renders it.
        fetchItems: (attr) =>
            @showLoadingAnimation()
            #@removeItemViews()
            @unbindItemViews()
            #$('#items').html ''
            window.collection.fetch attr

        # Save states of the current facet field selections, fetches the
        # facets based on the selected fields and re-applies the selections
        fetchFacet: (cb) =>
            @showLoadingAnimation()
            window.facets.fetch
                data: @getFilterQS()
                success: () =>
                    @updateFacetState()
                    @hideError()
                    @setFacetState @filterSelection.get()
                    cb()
                error: () =>
                    @showError()

        filterByPage: (cb) =>
            @fetchFacet () =>
                @fetchItems
                    data: @getFilterQS()
                    success: (col) =>
                        @trigger 'filterByFacet'
                        @genPageIndex()
                        @hideError()
                        @showPaneView()
                        @navigate()
                        cb(col) if cb
                    error: () =>
                        @showError()

        filterByFacet: (cb) =>
            window.collection.page = 0
            @filterByPage cb

        # When a model or a collection changes, some facets will change too.
        # This function re-fetches the facet fields and redraws the facet view
        # then applies the selection to the facet and filters the items.
        updateFacets: (m) =>
            @fetchFacet () =>
                @fetchItems
                    data: @getFilterQS()
                    success: (col) =>
                        @genPageIndex()
                        @hideError()
                        @showPaneView()
                        return if col.length
                        $('#inputSearch').val ''
                        @resetAllFilters()
                    error: () =>
                        @showError()

        # Reset the facet state and update items after. It is important to
        # update the item collection to make sure it matches the empty
        # selection of the facet.
        resetAllFilters: () =>
            # Trigger a 'resetFilters' event that can be catched by extension
            # code in order to reset its state too.
            @trigger 'resetFilters'
            @setFacetState []
            $('#inputSearch').val ''
            window.collection.search = ''
            @fetchFacet () =>
                @fetchItems
                    data: @getFilterQS()
                    success: () =>
                        @genPageIndex()
                        @hideError()
                        @navigate()
                    error: () =>
                        @showError()

        # Reset only the facet fields and not any other filter
        resetFacets: (cb) =>
            @trigger 'resetFacets'
            @setFacetState []
            @fetchFacet () =>
                @fetchItems
                    data: @getFilterQS()
                    success: () =>
                        @genPageIndex()
                        @hideError()
                        cb() if cb
                    error: () =>
                        @showError()

        previousPage: () =>
            return if window.collection.page <= 0
            window.collection.page--
            @filterByPage () =>

        nextPage: () =>
            total = window.collection.total
            rows = window.collection.rows
            lastPage = Math.ceil(total/rows) - 1
            return if window.collection.page >= lastPage
            window.collection.page++
            @filterByPage () =>

        jumpToPage: (e) =>
            $e = $(e.currentTarget)
            window.collection.page = $e.attr 'id'
            @filterByPage () =>

        jumpToFirst: () =>
            window.collection.page = 0
            @filterByPage () =>

        jumpToLast: () =>
            total = window.collection.total
            rows = window.collection.rows
            lastPage = Math.ceil(total/rows) - 1
            window.collection.page = lastPage
            @filterByPage () =>

        genPageIndex: () =>
            template = _.template $('#pagination-index-template').html()
            total = parseFloat window.collection.total
            rows = parseFloat window.collection.rows
            page = parseFloat window.collection.page + 1
            first = parseFloat page * rows - rows + 1
            last = if page * rows > total then total else page * rows
            if total > rows
                $('#content').removeClass 'noPages'
                $('#footer').html template()
                return $('#footer').show()
            $('#content').addClass 'noPages'
            $('#footer').hide()

        # Handle a click on a facet field. Add facet to selection, filter
        # with new selection and activate field
        handleFacetClick: (e) =>
            $e    = $(e.currentTarget)
            cat   = $e.attr 'data-name'
            name  = $e.attr 'data-title'

            if e.ctrlKey or e.altKey
                @filterSelection.toggleMult cat: cat, field:name
            else
                @filterSelection.toggle cat:cat, field:name

            @showLoadingAnimation()

            @filterByFacet () =>
                window.paneView?.close() if @filterSelection.get().length != 1
                $e.toggleClass 'active'
                $('span.amount', $e).toggleClass 'active'
                $('span#reset')
                    .show() unless @filterSelection.get().length is 0
                @showPaneView()

            $('#inputSearch').focus() unless @isTablet()

        # Reset filters and navigate(). Useful when a user clicked on
        # the 'reset filters' link next to the search input field.
        onResetFilter: () =>
            @resetFilter () =>
                @navigate()

        # Activate facet fields from the facet selection array and show any
        # facet in a hidden subcategory by expanding the parent node
        setFacetState: (s) =>
            @filterSelection.set s
            _.each s, (c) =>
                $f = $(".field[data-title='#{c.field}']",
                  "ul#facet li ul\##{c.cat}")
                $f.addClass 'active'
                $('span.amount', $f).addClass 'active'

                $p = $f.parent()
                $('>span.fold', $p.parents()).addClass('open').html '–'
                $('>ul', $p.parents()).css('display', 'block')

            _.each @facetOpenState.get(), (c) =>
                $f = $("li[data-name='#{c.cat}'][data-title='#{c.field}']")
                $('>span.fold', $f).addClass('open').html '–'
                $('>ul', $f).css('display', 'block')

            @showPaneView()

        # Check if field in filterSelection array still exists on html facet. If
        # its not, removes it.
        updateFacetState: () =>
            $('#pane').hide() unless window.groupView or window.paneView
            @trigger 'updateFacetState'

            nf = []
            _.each @filterSelection.get(), (c) =>
                $e = $("span[data-type='#{c.cat}'][data-title='#{c.field}']")
                $f = $(".field[data-title='#{c.field}']",
                      "ul#facet li ul\##{c.cat}")
                nf.push cat: c.cat, field: c.field if $f.length or $e.length
            @filterSelection.set nf
            $('span#reset').hide() unless nf.length

        # Forms an array of facet field parameters to put in the querystring
        getFilterQS: (state) =>
            s = state || @filterSelection.get()
            data = {fs: [] }
            _.each s, (f) ->
                data.fs.push "#{f.cat}:#{f.field}"
            #@updateFacetState()
            data

        # Form a URL with the basic prefix (i.e. /collection) and appends all
        # filter parameters on the querystring.
        commonURL: (page, rows) =>
            url = "collection/"
            fs = []
            fs.push "page=#{page}" if page isnt undefined
            fs.push "rows=#{rows}" if rows isnt undefined
            fs.push "sort=#{window.collection.sort}"
            _.each window.Settings.Schema.getFacets(), (field) ->
                fs.push 'facet.field=' + field.id
            url += '?' + fs.join '&' if fs.length
            url

        # A user keyup'ed on the search input field. Disable some keys like
        # ctrl, alt, up/down arrow keys to avoid refetching the same
        onSearchInput: (e) =>
            disabledKeys =
                [ 18, 17, 16, 9, 20, 27, 33, 34, 35, 36, 37, 38, 39, 40 ]

            if e.keyCode
                return unless disabledKeys.indexOf(e.keyCode) is -1
            @search()
            @navigate()

        #### Search
        # * Filter the items collection given the 'letters' from search input
        # * Renders entire collection in case there are no 'letters'
        search: (attr) =>

            letters = $("#inputSearch").val().toLowerCase()

            return if window.collection.search is letters

            $('#search span#reset').show()
            $('#search span#reset').hide() unless letters or @filterSelection
                .get().length

            @unbindItemViews()
            window.collection.search = letters
            window.collection.page = 0
            @filterByFacet () =>

        sortTable: (e) =>
            $e = $(e.currentTarget)
            $h = $e.parent()

            _.each $h.siblings(), (s) ->
                $('.th-inner', s).removeClass('asc desc')

            if $e.hasClass 'asc'
                $e.removeClass('asc').addClass('desc')
            else
                $e.removeClass('desc').addClass('asc')

            id = $h.attr 'id'

            order = 'asc'
            order = 'desc' if $e.hasClass 'desc'
            window.collection.sort = "#{id}:#{order}"
            window.collection.page = 0
            @saveSort()
            @filterByFacet () =>

        saveSort: () ->
            entity = window.Settings.entity
            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}
            ls.sort = {} unless ls.sort
            ls.sort = window.collection.sort
            window.localStorage[entity] = JSON.stringify ls

        getSort: () =>
            entity = window.Settings.entity
            return window.Settings.sort unless window.localStorage[entity]
            ls = JSON.parse window.localStorage[entity]
            return window.Settings.sort unless ls.sort
            return ls.sort

        reset: (attr) =>
            letters = $("#inputSearch").val().toLowerCase()
            $('#search span#reset').show()
            $('#search span#reset').hide() unless letters or @filterSelection
                .get().length
            return @addAll window.collection

        toggleFacetNode: (e) =>
            $e = $(e.currentTarget)
            $e = $e.siblings('span') unless $e.hasClass 'fold'
            $ul = $e.siblings('ul')
            cat = $ul.attr 'id'
            if $e.hasClass 'open'
                $ul.hide()
                @facetOpenState.toggle cat: cat, field: 'facet'
                @saveFacetOpenState()
                return $e.removeClass('open').html '+'
            $ul.css('display', 'block')
            @facetOpenState.push cat: cat, field: 'facet'
            $e.addClass('open').html '–'
            @saveFacetOpenState()

        # Handles expansion and collapse of facet fields when clicking on '+'
        # or '-' symbols next to the facet field label.
        toggleFacetSubfields: (e) =>
            $e  = $(e.currentTarget)
            $p = $e.parent()
            cat = $p.attr 'data-name'
            field = $p.attr 'data-title'

            if $e.hasClass 'open'
                $("ul[data-name='#{cat}'][data-title='#{field}']", $p).hide()
                $e.removeClass 'open'
                @facetOpenState.toggle cat:cat, field:field
                return $e.removeClass('open').html '+'

            @facetOpenState.push cat: cat, field: field
            $("ul[data-name='#{cat}'][data-title='#{field}']", $p).show()
            $e.addClass('open').html '–'

        # Show a detailed view of an item in the rightmost pane
        showProfile: (item) =>
            window.groupView?.destroy()
            window.profileView = new ProfileView model: item
            $('#pane').html window.profileView.render().el
            $('#tableContainer, #thumbnailContainer').addClass 'onProfile'
            $('#footer, #columnsSelectWrapper').addClass 'onProfile'
            @addProfileExtensions item
            t = []
            _.each window.Settings.Schema.getThumbnails(), (l) ->
                t.push item.get l.id

        # Show a group view when many items have been selected
        showGroupView: () =>
            window.profileView?.destroy()
            window.groupView?.destroy()

            window.groupView = new GroupView unless window.groupView
            $('#pane').css('display', 'block').html window.groupView.render().el

            @navigate()

        # Show a customazible view on the right pane. Triggered when
        # clicking on facet fields. Template defined in extension templates.
        showPaneView: () =>
            return if window.profileView or window.groupView
            return if @filterSelection.get().length isnt 1

            { field, cat } = @filterSelection.get()[0]
            return window.paneView?.close() unless window.pdata[cat]?[field]

            template = _.template $("#app > #extensions #pane-template").html()

            window.paneView = new PaneView template, t: window.pdata[cat][field]
            $('#pane').css('display', 'block').html window.paneView.render().el

            # Close pane only after successfull reset of facets
            $(window.paneView.el).bind 'close', () =>
                $(window.paneView.el).unbind 'close'
                @resetFacets () =>
                    window.paneView?.close()

        profileClosed: () =>
            @trigger 'profileClosed'

        # Destroy all item views, propperly unbinding
        # and removing html elements
        removeItemViews: () ->
            window.collection.each (item) ->
                item.view?.destroy()

        unbindItemViews: () ->
            window.collection.each (item) ->
                item.view?.release()

        # Renders containers for each category.
        # Only useful in thumbnail view mode. The items will be rendered
        # inside each container according to its category. The category is
        # specified in the schema by using the classifier key.
        renderCategoryView: (cb) =>
            c = window.Settings.Schema.getClassifier()

            onProfile = ''
            onProfile = 'onProfile' if window.paneView
            onProfile = 'onProfile' if window.profileView

            html = "<ul class='thumbnailContainer #{onProfile}'></div>"
            $('#items').html html

            window.facets?.each (facet) =>
                return unless facet.get('name') is c.id

                window.categories = []
                template = _.template $('#category-template').html()
                presentCategories = _.extend {},
                    facet.get('fields').normal, facet.get('fields').special

                # Add the present categoriesin that have a predefined order
                _.each c.classifier, (cat) =>
                    if window.App.isCatInCats cat, presentCategories
                        if window.categories.indexOf(cat) is -1
                            window.categories.push(cat)
                        delete presentCategories[cat]

                # Add all other present categories
                _.each presentCategories, (amount, cat) =>
                    return if cat is 'null'
                    window.categories.push cat

                # Lastly, add 'not set' category
                window.categories.push 'null' if presentCategories['null']

                # Generate categories based on calculated order
                _.each window.categories, (category, index) =>
                    $('#items .thumbnailContainer').append template
                        cat: category
                        index: index
                cb()

        # Renders a table to show items in 'list' view.
        renderTableView: (cb) =>
            $('#items').html ''
            classes = "onProfile" if window.paneView or window.groupView
            $('#items').append _.template $('#table-template').html(),
              h: window.Settings.Columns
              classes: classes
            cb()

        # Runs after all items were added, remove all empty categories.
        hideEmptyCategories: () =>
            $("#items li ul").each (i, cat) ->
                $($(cat).parent()).show()
                $($(cat).parent()).hide() if $(cat).find('li').length is 0

        # Set the amount of items in the collection on the <em> next to the
        # inputSearch field and on each category title
        setTotals: (total) =>
            _.each $('#items ul'), (ul) =>
                amount = $(ul).find('li').length
                $('em', $(ul).siblings('label')).html amount

            return $('span#total').html total unless total is undefined
            $('span#total').html window.collection.total

            $('#search label').html @getItemType() + ' found'

        # Returns the tag of the items on the search label. i.e. people, items.
        getItemType: () =>
            itemType = window.Settings.itemType[1]
            if window.collection.length is 1
                itemType = window.Settings.itemType[0]
            return itemType

        # Utility to determine if the given category for a item is listed in
        # the predefined categories or not. It is not about felines!
        isCatInCats: (cat, cats) =>
            return yes unless cats[cat] is undefined or cats[cat] is null
            return no

        # After a change in the collection, re-selects items that remained
        updateSelection: () =>
            @hideLoadingAnimation()
            return unless @itemSelection.length
            return if window.profileView
            if @itemSelection.length and window.groupView
                return @showGroupView()
            window.groupView?.destroy()
            @clearSelection()

        # Deselect all items and clear selection array
        clearSelection: () =>
            $('.active', '#items').removeClass 'active'
            @itemSelection = new window.Collection
            @navigate()

        # Check if admin key is present in QS
        isAdmin: () =>
            return yes if window.Settings.editable is true
            qs = window.location.search.split('?')[1]
            new RegExp('admin=').test qs

        isEditable: () =>
            return yes if window.Settings.editable isnt false
            no

        # Set browsers URL to point to the current application state
        navigate: (attr) =>
            url =  'qs/?' + @navigateURL().join('&')
            @router.navigate url, attr

        # Form QS from current application state
        navigateURL: () =>
            page = window.collection.page
            rows = window.collection.rows
            sort = window.collection.sort
            nav = ["page=#{page}&rows=#{rows}&sort=#{sort}"]
            id = ''
            fs = ''
            search = ''

            @setWindowTitle()

            if @filterSelection.get().length
                f = []
                _.each @filterSelection.get(), (facet) ->
                    cat = encodeURIComponent facet.cat
                    field = encodeURIComponent facet.field
                    f.push "#{cat}:#{field}"
                fs = 'fs=' + f.join '|'

                @setWindowTitle "#{f.join()}"

            if window.profileView
                id = window.profileView.model.id || 'new'
                @setWindowTitle window.profileView.model?.getTitle()

            else if window.groupView
                id = []
                @itemSelection.each (m) =>
                    id.push m.get 'id'
                id = id.join '|'
                if @itemSelection.length is 1
                    id = '|' + @itemSelection.models[0].id
                @setWindowTitle "Group"

            search = $('#inputSearch').val().toLowerCase()

            nav.push "id=#{id}" if id
            nav.push fs if fs
            if window.Settings.view isnt "list"
                nav.push "view=#{window.Settings.view}"
            nav.push "s=#{encodeURI(search)}" if search

            nav

        addProfileExtensions: (item) =>
            return unless $('#app > #extensions #details-template').length
            template = _.template $('#app > #extensions #details-template')
                .html()
            $('#pane #extensions').append template t:item

        # Item selection by using arrow keys.
        setMoveKeybindings: () =>
            @unsetMoveKeybindings()
            $('body').keyup @arrowUp
            $('body').keydown  @arrowDown

        # Unbind to stop responding to keypress events for movement
        unsetMoveKeybindings: () =>
            $('body').unbind 'keyup', @arrowUp
            $('body').unbind 'keydown', @arrowDown

        # Select item above currently selected item
        arrowUp: (e) =>
            @app = window.App
            selectedId = @app.itemSelection?.models[0]?.id
            elem = $("##{selectedId}", '#items')
            if  (e.which is 37 or e.which is 38) and elem.prev().length
                @app.selectOne $("##{selectedId}", '#items')
                    .prev()
            if  (e.which is 39 or e.which is 40) and elem.next().length
                @app.selectOne $("##{selectedId}", '#items')
                    .next()
            @app.navigate()

        # Select item below currently selected item
        arrowDown: (e) =>
            @app = window.App
            return unless @app.itemSelection.length
            return false if e.which >= 37 && e.which <= 40

        # Show a loading wheel in the middle of the items container, if the
        # items havent been rendered after 1 second
        showLoadingAnimation: () =>
            return if @loadingAnimation
            @loadingAnimation = setTimeout () =>
                $('span#loading').show()
              ,
                1000

        showError: () =>
            @hideLoadingAnimation()
            $('span#error').show()

        hideError: () =>
            $('span#error').hide()

        # Hide the loading animation wheel
        hideLoadingAnimation: () =>
            clearTimeout @loadingAnimation
            @loadingAnimation = null
            $('span#loading').hide()

        # Parses a given Date into a readable formatted string (DD MMMM YYYY)
        formatDate: (date) =>
            if typeof date is typeof [] then date = date[0]
            return '' unless date
            monthNames = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
                "Aug", "Sep", "Oct", "Nov", "Dec" ]
            d = new Date date
            d = [
                d.getDate(), monthNames[d.getMonth()], d.getFullYear()
            ]
            d.join ' '

        # Show print view on a new window/ab
        print: () =>
            url = [ "page=#{window.collection.page}" ]
            url.push "rows=#{window.collection.total}"
            if window.profileView
                url.push "id=#{window.profileView.model.id}"
            if window.groupView
                ids = []
                window.App.itemSelection.each (m) =>
                    ids.push m.get 'id'
                url.push "id=#{ids.join('|')}"
            url = url.join '&'
            window.open 'print?' + url, '_blank'

        toJson: () =>
            url = "#{@commonURL(0, window.collection.total)}"

            if @getFilterQS().fs.length
                url += '?'
                _.each @getFilterQS().fs, (f) =>
                    url += "&fs=#{f}"

            url += "&json=true"

            if window.profileView
                url = "collection/#{window.profileView.model.id}"
            if window.groupView
                ids = []
                window.App.itemSelection.each (m) =>
                    ids.push m.get 'id'
                ids = ids.join('|')
                url = "collection/#{ids}"

            window.open url, '_blank'

        disableFacets: () ->
            $('#index').hide()
            $('#content').addClass 'noFacets'

        generateEntitiesMenu: () ->
            entities = window.Settings.entities
            _.each entities, (e) ->
                return if e is window.Settings.entity
                o = "<li id='#{e}'><span>#{e}</span></li>"
                $("#entities ul", "#header").append o
            $('#entityTitle span').hide() if entities.length is 1

        generateColumnsMenu: () ->
            template = _.template $('#columns-menu-template').html()
            _.each window.Settings.Schema.get(), (field) =>
                $('#columnOptions ul').append template field: field

        toggleEntitiesMenu: (e) ->
            e.stopPropagation()
            return unless window.Settings.entities.length > 1
            $('#entityTitle', '#header').toggleClass 'active'
            $("#entities", "#header").toggle()

        hideEntitiesMenu: (e) ->
            $('#entityTitle', '#header').removeClass 'active'
            $('#entities', '#header').hide()

        showColumnsBtn: (e) ->
            $('#columnsMenu').show()

        hideColumnsBtn: (e) ->
            return if $('#columnOptions').css('display') is 'block'
            $('#columnsMenu').hide()

        overColumnsMenu: (e) ->
            $('#columnsMenu').show()
            e.stopPropagation()

        toggleColumnsMenu: (e) ->
            e.stopPropagation()
            $('#columnOptions').toggle()
            $('#columnsMenu').toggleClass 'active'

        toggleColumnVisibility: (e) ->
            e.stopPropagation()
            $e = $(e.currentTarget)
            id = $e.attr 'id'
            if $e.hasClass 'active'
                _.each window.Settings.Schema.get(), (f) =>
                    if f.id is id then f.index = false
                $e.removeClass 'active'
                @saveColumnSelection()
                return @addAll window.collection
            _.each window.Settings.Schema.get(), (f) =>
                if f.id is id then f.index = true
            $e.addClass 'active'
            @saveColumnSelection()
            @addAll window.collection

        setWindowTitle: (t) ->
            title = window.Settings?.title
            title += " - #{t}" if t
            $('head title').html title

        redirectToEntity: (e) ->
            entity = $(e.currentTarget).attr 'id'
            adminKey = if @isAdmin() then "?admin=yes" else ''
            window.location = "/#{entity}/#{adminKey}"

        setIndexResizable: () =>
            $('#index').resizable
                handles: 'e'
                resize: @resizeIndex
                stop: @saveFacetWidth

        resizeIndex: (event, ui) =>
            width = $('#index').width()
            $('#content').css 'left', width + 21
            $('#footer').css 'left', width + 21
            $('#innerIndex').width $('#index').width() - 10

        saveColumnSelection: () =>
            entity = window.Settings.entity
            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}
            indexes = []
            _.each window.Settings.Schema.getIndexes(), (s) ->
                indexes.push s.id
            ls.columns = {} unless ls.columns
            ls.columns = indexes
            window.localStorage[entity] = JSON.stringify ls

        setColumnSelection: () =>
            entity = window.Settings.entity
            ls = window.localStorage[entity]
            return unless ls
            ls = JSON.parse ls
            columns = ls.columns
            return unless ls.columns
            _.each window.Settings.Schema.getIndexes(), (i) ->
                i.index = no
            _.each columns, (c) ->
                window.Settings.Schema.getField c, (f) ->
                    f.index = yes

        saveFacetWidth: (event, ui) =>
            entity = window.Settings.entity
            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}
            w = $('#index').width()
            ls.css = {} unless ls.css
            ls.css['facet_width'] = w
            window.localStorage[entity] = JSON.stringify ls

        setFacetWidth: () =>
            entity = window.Settings.entity
            return unless window.localStorage[entity]
            ls = JSON.parse window.localStorage[entity]
            w = parseFloat ls.css?.facet_width
            $('#index').width(w) if w
            @resizeIndex()

        getEtiquetteById: (id) =>
            etq = null
            _.each window.Settings.etiquettes, (e) ->
                return etq = e if e.id is id
            etq

        getMiniEtiquette: (etiquettes) =>
            etq = null
            _.each etiquettes, (e) =>
                e = @getEtiquetteById e
                etq = e unless etq or !e?.mini
            etq

        # Determine which etiquettes should an item have
        getItemEtiquettes: (model) =>
            return unless window.Settings.Schema.getTuples().length
            facet = window.App.filterSelection.get()[0]
            tuple = window.Settings.Schema.getTuples()[0].id
            [team, role] = tuple.split(':') #team
            etiquettes = []
            _.each model.get(tuple), (t) =>
                [ mteam, mrole ] = t.split(':')
                _.each mrole.split(','), (r) =>
                    return if etiquettes.indexOf($.trim(r)) isnt -1
                    etiquettes.push $.trim r
            etiquettes = @sortEtiquettes etiquettes
            etiquettes

        sortEtiquettes: (etiquettes) =>
            ordered = []
            _.each window.etiquettes, (e) =>
                ordered.push e.id if etiquettes.indexOf(e.id) isnt -1
            _.each etiquettes, (e) =>
                ordered.push e if ordered.indexOf(e) is -1
            ordered

        saveFacetOpenState: () =>
            entity = window.Settings.entity
            ls = window.localStorage[entity]
            ls = if ls then JSON.parse ls else {}
            ls.facetOpenState = @facetOpenState.get()
            window.localStorage[entity] = JSON.stringify ls

        setFacetOpenState: () =>
            entity = window.Settings.entity
            return @initFacetOpenState() unless window.localStorage[entity]
            ls = JSON.parse window.localStorage[entity]
            fs = ls.facetOpenState
            return @initFacetOpenState() unless fs
            @facetOpenState.arr = fs

        initFacetOpenState: () =>
            window.facets.each (f) =>
                @facetOpenState.push cat: f.get('name'), field: 'facet'

        documentClick: () =>
            @hideEntitiesMenu()
            $('#columnsMenu').hide().removeClass 'active'
            $('#columnOptions').hide()

        getThumbnailLabel: (m) =>
            thumbnails = window.Settings.Schema.getThumbnails()
            label = []
            _.each thumbnails, (f) =>
                label.push m[f.id]
            label.join ' '

        getPicKey: () =>
            pictures = window.Settings.Schema.getPictures()
            return pictures[0]['id'] if pictures[0]

        isTuple: (id) =>
            tuples = window.Settings.Schema.getTuples()
            allTuples = []
            _.each tuples, (t) =>
                allTuples.push t.id.split(':')[0]
                allTuples.push t.id.split(':')[1]
            return no if allTuples.indexOf(id) is -1
            return yes

        isTablet: () =>
            return navigator.userAgent.match(/iPad|Android/i) isnt null

    #Lets create our app!
    @App = new AppView
