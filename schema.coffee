# Schema example
#
# This schema is the one provided in the team example.

[
    {
      # Field identifier.
      # type: string.
      id: "pic",
      # Label for picture. Appears on column header on list view.
      # type: string.
      label: "Pic",
      # True shows field as a column in list view by default.
      # type: boolean.
      index: true,
      # Defines the type of the field. Image in this case. Holds an image and
      # its rendered with a fileupload handler to upload pictures.
      # type: String( "integer", "float", "facet", etc..)
      type: "img"
    }, {
      id: "name",
      label: "Firstname",
      # This field must have a value for validation to be successful.
      # type: boolean
      mandatory: true,
      index: true,
      # This field's content will be used during search.
      # type: boolean.
      search: true,
      # This field will be rendered on the footer of images in thumbnail mode.
      # type: boolean
      thumbnail: true
    }, {
      id: "lastname",
      label: "Lastname",
      mandatory: true,
      index: true,
      search: true,
      thumbnail: true
    }, {
      id: "email",
      label: "Email",
      type: "email",
      mandatory: true,
      search: true
    }, {
      id: "startDate",
      label: "Start date",
      mandatory: true,
      type: "date"
    }, {
      id: "team",
      label: "Team",
      index: true,
      type: "facet",
      # This field will be modifiable for many items at once.
      # type: boolean
      multiedit: true,
      # Special values for this facet will be rendered below a gray line on the
      # facet pane.
      # type: array
      specials: ["Management", "System", "Software Procurement", "Platform", "Database", "24x7", "BI", "MIS", "PMO", "RQM", "ZEOS Support"]
    }, {
      id: "role",
      label: "Role",
      index: true,
      type: "facet",
      multiedit: true,
      # Classifiers are used in thumbnail mode to create containers where to
      # append items based on their field value.
      # type: array
      classifier: ["dev", "pm", "qa", "sys", "dba", "pcm", "bi"]
    },
    {
      id: "team:role",
      label: "Team:Role",
      type: "tuple",
      # Field contains multiple values. Stored as an array of strings in DB and
      # rendered as a comma separated list on the frontend.
      # type: booloean.
      multivalue: true,
      multiedit: true
    },
    {
      id: "position",
      label: "Position",
      index: true,
      type: "facet",
      multiedit: true
    }, {
      id: "expertise",
      label: "Expertise",
      index: true,
      type: "facet",
      multiedit: true,
      search: true
    }, {
      id: "location",
      label: "Location",
      index: true,
      type: "facet",
      multiedit: true
    }, {
      id: "gender",
      label: "Gender",
      type: "dropdown",
      # Options in the dropdown menu
      # type: array
      options: ["", "Male", "Female"],
      # Renders field inside an "additional information" section in the profile
      # type: boolean
      additional: true
    }, {
      id: "skype",
      label: "Skype",
      additional: true,
      type: "skype"
    }, {
      id: "mobile",
      label: "Mobile",
      additional: true,
      search: true
    }, {
      id: "bday",
      label: "Birthday",
      additional: true,
      type: "date"
    }, {
      id: "about",
      label: "About Me",
      additional: true,
      type: "multiline"
    }
]
