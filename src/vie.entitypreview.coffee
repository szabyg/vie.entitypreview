###   VIE entitypreview uses the VIE.load service method to show a preview for an entity.
#     Author: Szaby Gruenwald, Salzburg Research (2012-2013)
#     This file may be freely distributed under the MIT license
###
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
    picSize: 150
    width: 350
    # * Define Entity properties for finding the description
    descriptionProperties: [
      "rdfs:comment"
      "skos:note"
      "schema:description"
      "rdfs:label"
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
      @element.tooltip?('destroy')
  _instantiateTooltip: ->
    widget = @
    if @element.tooltip
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
  # The getPreviewHtml method is for external call, it provides the HTML snippet for the 
  # widget instance in form of the callback argument's only parameter. 
  getPreviewHtml: (cb) ->
      @_createPreview @uri, cb
      return
  _createPreview: (uri, response) ->
    success = (cacheEntity) =>
      html = ""
      picSize = @options.picSize
      depictionUrl = @_getDepiction cacheEntity, picSize
      if depictionUrl
        html += "<img style='float:left;padding: 5px;width: #{picSize}px' src='#{depictionUrl.substring 1, depictionUrl.length-1}'/>"
      descr = @_getDescription cacheEntity
      unless descr
        @_logger.warn "No description found for", cacheEntity
        descr = "No description found."
      html += "<small>#{descr}</small>"
      html = "<div style='padding 5px;width:#{@options.width}px;'>#{html}</div>"
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
    unless entity
      @options.vie.load(entity: uri).using(@options.services).execute()
      .success (res) ->
        loadedEntity = _.detect res, (entity) ->
          entity.fromReference(entity.getSubject()) is uri
        success loadedEntity
      .fail fail
    else
      unless entity.get('@type')
        fail('Entity has no type')
      success entity

  _getUserLang: ->
    if window.navigator.appName is 'Netscape' # chrome && firefox
      window.navigator.language.split("-")[0]
    else
      window.navigator.browserLanguage.split("-")[0]

  _getDepiction: (entity, picSize) ->
    if ["gif","jpg"].indexOf(entity.getSubjectUri().slice(-3)) isnt -1
      return entity.getSubject()
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

