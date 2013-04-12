# Cube's nodejs basic server settings

ServerSettings = ->

    #### Web server settings
    Web:

        # Default hostname of your project, please edit.
        defaultHost: 'cube.zalando.net'

        # Port to run your nodejs service, i.e. 3000.
        defaultPort: 3000


    #### Nodejs Paths
    Paths:

        # Path to the Jade templates directory
        viewsDir: __dirname + "/views/"

        # Path to the public static folder
        publicDir: __dirname + "/public/"

        # Path to the coffee files
        coffeeDir: __dirname + "/coffee/"


    #### Entities json file
    EntitiesFile: 'entities.json'


    #### Default settings. Mainly used when creating an extension.
    Default:

        # Default database settings.
        Database:

            production:
                host: '10.58.26.49'
                port: '34220'
                path: '/solr'
                method: 'GET'
                dataRoot: "p4220"

            development:
                host: '127.0.0.1'
                port: '38730'
                path: '/cube-solr'
                method: 'GET'
                dataRoot: "default"


        # Default application settings
        Application:

            description: "Dynamically generated entity"
            itemType: [ "item", "items"]
            separator: "/"
            view: "list"
            sort: "name:asc"
            rows: 50


        # Default parameters of a field for solr's schema
        SchemaField:

            index       : yes
            search      : yes
            thumbnail   : yes
            multivalue  : yes


        # Type of fields on a suffix. i.e. team-f from a csv or json file
        Suffix:

            f: 'facet'
            i: 'img'
            e: 'email'
            s: 'skype'
            d: 'date'


#### Singleton implementation
ServerSettings.getInstance = ->
    @instance = new ServerSettings() if not @instance?
    return @instance

module.exports = ServerSettings.getInstance()