# VIE entitypreview uses the VIE.load service method to show a preview for an entity.
# This demo goes to the default Apache Stanbol backend.
#
#     var vie = new VIE();
#     vie.use(new vie.StanbolService({
#         url : "http://dev.iks-project.eu:8081",
#         proxyDisabled: true
#     }));
#
#     $('.search')
#     .entitypreview({
#         vie: vie,
#         select: function(e, ui){
#             console.log(ui);
#         }
#     });

# default VIE instance with stanbol service
vie = new VIE()
vie.use(new vie.StanbolService({
  url : "http://dev.iks-project.eu:8080",
  proxyDisabled: true
}));

jQuery.widget "IKS.entitypreview",
  # The widget **options** are:
  options:
    # * VIE instance.
    vie: vie
    # * VIE service to use (right now only one service supported)
    services: "stanbol"
    debug: false
    # * Define Entity properties for finding depiction
    depictionProperties: [
        "foaf:depiction"
        "schema:thumbnail"
    ]
    # * Define Entity properties for finding the label
    labelProperties: [
        "rdfs:label"
        "skos:prefLabel"
        "schema:name"
        "foaf:name"
    ]
    # * Define Entity properties for finding the description
    descriptionProperties: [
      "rdfs:comment"
      "skos:note"
      "schema:description"
      "skos:definition"
        property: "skos:broader"
        makeLabel: (propertyValueArr) ->
          labels = _(propertyValueArr).map (termUri) ->
            # extract the last part of the uri
            termUri
            .replace(/<.*[\/#](.*)>/, "$1")
            .replace /_/g, "&nbsp;"
          "Subcategory of #{labels.join ', '}."
    ,
      property: "dcterms:subject"
      makeLabel: (propertyValueArr) ->
        labels = _(propertyValueArr).map (termUri) ->
          # extract the last part of the uri
          termUri
          .replace(/<.*[\/#](.*)>/, "$1")
          .replace /_/g, "&nbsp;"
        "Subject(s): #{labels.join ', '}."
    ]
    # * If label and description is not available in the user's language
    # look for a fallback.
    fallbackLanguage: "en"
    styleClass: "vie-autocomplete"
    # * type label definition
    getTypes: ->
      [
        uri:   "#{@ns.dbpedia}Place"
        label: 'Place'
      ,
        uri:   "#{@ns.dbpedia}Person"
        label: 'Person'
      ,
        uri:   "#{@ns.dbpedia}Organisation"
        label: 'Organisation'
      ,
        uri:   "#{@ns.skos}Concept"
        label: 'Concept'
      ]
    # * entity source label definition
    getSources: ->
      [
        uri: "http://dbpedia.org/resource/"
        label: "dbpedia"
      ,
        uri: "http://sws.geonames.org/"
        label: "geonames"
      ]
  _create: ->
    @_logger = if @options.debug then console else
      info: ->
      warn: ->
      error: ->
      log: ->
    @uri = @options.uri or $( @element ).attr('about') or $( @element ).attr('resource')
    @_instantiateTooltip()

  _destroy: ->
      @menuContainer.remove()
  _instantiateTooltip: ->
    widget = @
    @element.tooltip
      items: "*"
      hide:
        effect: "hide"
        delay: 50
      show:
        effect: "show"
        delay: 50
      content: (response) ->
        # fallbacks for different jquery ui versions
        uri = widget.uri
        widget._createPreview uri, response
        "loading..."
    ###
      widget = @
      @element
      .autocomplete
          # define where do suggestions come from
          source: (req, resp) =>
              widget._logger.info "req:", req
              properties = _.flatten [
                  widget.options.labelProperties
                  widget.options.descriptionProperties
                  widget.options.depictionProperties
              ]
              properties = _(properties).map (prop) ->
                  if typeof prop is "object"
                      prop.property
                  else
                      prop
              # call VIE.find
              # if @options.stanbolIncludeLocalSite TODO implement multiple find requests and result merging
              widget.options.vie
              .find({
                  term: "#{req.term}#{if req.term.length > 3 then '*'  else ''}"
                  field: widget.options.field
                  properties: properties
                  local: @options.stanbolIncludeLocalSite or false
              })
              .using(widget.options.services).execute()
              # error handling
              .fail (e) ->
                  widget._logger.error "Something wrong happened at stanbol find:", e
              .success (entityList, resp) ->
                _.defer =>
                  widget._logger.info "resp:", _(entityList).map (ent) ->
                      ent.id
                  limit = 10
                  # remove descriptive entity
                  # TODO move to VIE
                  entityList = _(entityList).filter (ent) ->
                      return false if ent.getSubject().replace(/^<|>$/g, "") is
                        "http://www.iks-project.eu/ontology/rick/query/QueryResultSet"
                      return true
                  res = _(entityList.slice(0, limit)).map (entity) ->
                      return {
                          key: entity.getSubject().replace /^<|>$/g, ""
                          label: "#{widget._getLabel entity} @ #{widget._sourceLabel entity.id}"
                          value: widget._getLabel entity
                          getUri: ->
                            @key
                      }
                  resp res
          # create tooltip on menu elements when menu opens
          open: (e, ui) ->
              widget._logger.info "autocomplete.open", e, ui
              if widget.options.showTooltip
                  $(this).data().autocomplete.menu.activeMenu
                  .tooltip
                      items: ".ui-menu-item"
                      hide:
                          effect: "hide"
                          delay: 50
                      show:
                          effect: "show"
                          delay: 50
                      content: (response) ->
                        # fallbacks for different jquery ui versions
                        item = $( @ ).data()["item.autocomplete"] or $( @ ).data()["uiAutocompleteItem"] or $( @ ).data()["ui-autocomplete-item"]
                        uri = item.getUri()
                        widget._createPreview uri, response
                        "loading..."
          # An entity selected, annotate
          select: (e, ui) =>
            _.defer =>
              @options.select e, ui
              @_logger.info "autocomplete.select", e.target, ui
              if widget.options.urifield
                widget.options.urifield.val ui.item.key
            true
          appendTo: @menuContainer
  ###
  _createPreview: (uri, response) ->
    success = (cacheEntity) =>
      html = ""
      picSize = 100
      depictionUrl = @_getDepiction cacheEntity, picSize
      if depictionUrl
        html += "<img style='float:left;padding: 5px;width: #{picSize}px' src='#{depictionUrl.substring 1, depictionUrl.length-1}'/>"
      descr = @_getDescription cacheEntity
      unless descr
        @_logger.warn "No description found for", cacheEntity
        descr = "No description found."
      html += "<div style='padding 5px;width:250px;float:left;'><small>#{descr}</small></div>"
      @_logger.info "tooltip for #{uri}: cacheEntry loaded", cacheEntity
      # workaround for a tooltip widget bug
      # setTimeout ->
      response html
      # , 200

    fail = (e) =>
      @_logger.error "error loading #{uri}", e
      response "error loading entity for #{uri}"
    jQuery(".ui-tooltip").remove()
    # @options.cache.get uri, @, success, fail
    entity = @options.vie.entities.get uri
    @options.vie.load(entity: uri).using(@options.services).execute()
    .success (res) ->
      loadedEntity = _.detect res, (entity) ->
        entity.fromReference(entity.getSubject()) is uri
      success loadedEntity
    if entity
      success entity
    else
      fail()

  _getUserLang: ->
      window.navigator.language.split("-")[0]

  _getDepiction: (entity, picSize) ->
    preferredFields = @options.depictionProperties
    # field is the first property name with a value
    field = _(preferredFields).detect (field) ->
      true if entity.get field
    # fieldValue is an array of at least one value
    if field && fieldValue = _([entity.get field]).flatten()
      depictionUrl = _(fieldValue).detect (uri) ->
          true if uri.indexOf("thumb") isnt -1
      .replace /[0-9]{2..3}px/, "#{picSize}px"
      depictionUrl

  _getLabel: (entity) ->
    preferredFields = @options.labelProperties
    preferredLanguages = [@_getUserLang(), @options.fallbackLanguage]
    VIE.Util.getPreferredLangForPreferredProperty entity, preferredFields, preferredLanguages

  _getDescription: (entity) ->
    preferredFields = @options.descriptionProperties
    preferredLanguages = [@_getUserLang(), @options.fallbackLanguage]
    VIE.Util.getPreferredLangForPreferredProperty entity, preferredFields, preferredLanguages

