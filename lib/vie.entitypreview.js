// Generated by CoffeeScript 1.3.1
(function() {
  var vie;

  vie = new VIE();

  vie.use(new vie.StanbolService({
    url: "http://dev.iks-project.eu:8080",
    proxyDisabled: true
  }));

  jQuery.widget("IKS.entitypreview", {
    options: {
      vie: vie,
      services: "stanbol",
      debug: false,
      depictionProperties: ["foaf:depiction", "schema:thumbnail"],
      labelProperties: ["rdfs:label", "skos:prefLabel", "schema:name", "foaf:name"],
      descriptionProperties: [
        "rdfs:comment", "skos:note", "schema:description", "skos:definition", {
          property: "skos:broader",
          makeLabel: function(propertyValueArr) {
            var labels;
            labels = _(propertyValueArr).map(function(termUri) {
              return termUri.replace(/<.*[\/#](.*)>/, "$1").replace(/_/g, "&nbsp;");
            });
            return "Subcategory of " + (labels.join(', ')) + ".";
          }
        }, {
          property: "dcterms:subject",
          makeLabel: function(propertyValueArr) {
            var labels;
            labels = _(propertyValueArr).map(function(termUri) {
              return termUri.replace(/<.*[\/#](.*)>/, "$1").replace(/_/g, "&nbsp;");
            });
            return "Subject(s): " + (labels.join(', ')) + ".";
          }
        }
      ],
      fallbackLanguage: "en",
      styleClass: "vie-autocomplete",
      getTypes: function() {
        return [
          {
            uri: "" + this.ns.dbpedia + "Place",
            label: 'Place'
          }, {
            uri: "" + this.ns.dbpedia + "Person",
            label: 'Person'
          }, {
            uri: "" + this.ns.dbpedia + "Organisation",
            label: 'Organisation'
          }, {
            uri: "" + this.ns.skos + "Concept",
            label: 'Concept'
          }
        ];
      },
      getSources: function() {
        return [
          {
            uri: "http://dbpedia.org/resource/",
            label: "dbpedia"
          }, {
            uri: "http://sws.geonames.org/",
            label: "geonames"
          }
        ];
      }
    },
    _create: function() {
      this._logger = this.options.debug ? console : {
        info: function() {},
        warn: function() {},
        error: function() {},
        log: function() {}
      };
      this.uri = this.options.uri || $(this.element).attr('about') || $(this.element).attr('resource');
      return this._instantiateTooltip();
    },
    _destroy: function() {
      return this.menuContainer.remove();
    },
    _instantiateTooltip: function() {
      var widget;
      widget = this;
      return this.element.tooltip({
        items: "*",
        hide: {
          effect: "hide",
          delay: 50
        },
        show: {
          effect: "show",
          delay: 50
        },
        content: function(response) {
          var uri;
          uri = widget.uri;
          widget._createPreview(uri, response);
          return "loading...";
        }
      });
      /*
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
      */

    },
    _createPreview: function(uri, response) {
      var entity, fail, success,
        _this = this;
      success = function(cacheEntity) {
        var depictionUrl, descr, html, picSize;
        html = "";
        picSize = 100;
        depictionUrl = _this._getDepiction(cacheEntity, picSize);
        if (depictionUrl) {
          html += "<img style='float:left;padding: 5px;width: " + picSize + "px' src='" + (depictionUrl.substring(1, depictionUrl.length - 1)) + "'/>";
        }
        descr = _this._getDescription(cacheEntity);
        if (!descr) {
          _this._logger.warn("No description found for", cacheEntity);
          descr = "No description found.";
        }
        html += "<div style='padding 5px;width:250px;float:left;'><small>" + descr + "</small></div>";
        _this._logger.info("tooltip for " + uri + ": cacheEntry loaded", cacheEntity);
        return response(html);
      };
      fail = function(e) {
        _this._logger.error("error loading " + uri, e);
        return response("error loading entity for " + uri);
      };
      jQuery(".ui-tooltip").remove();
      entity = this.options.vie.entities.get(uri);
      this.options.vie.load({
        entity: uri
      }).using(this.options.services).execute().success(function(res) {
        var loadedEntity;
        loadedEntity = _.detect(res, function(entity) {
          return entity.fromReference(entity.getSubject()) === uri;
        });
        return success(loadedEntity);
      });
      if (entity) {
        return success(entity);
      } else {
        return fail();
      }
    },
    _getUserLang: function() {
      return window.navigator.language.split("-")[0];
    },
    _getDepiction: function(entity, picSize) {
      var depictionUrl, field, fieldValue, preferredFields;
      preferredFields = this.options.depictionProperties;
      field = _(preferredFields).detect(function(field) {
        if (entity.get(field)) {
          return true;
        }
      });
      if (field && (fieldValue = _([entity.get(field)]).flatten())) {
        depictionUrl = _(fieldValue).detect(function(uri) {
          if (uri.indexOf("thumb") !== -1) {
            return true;
          }
        }).replace(/[0-9]{2..3}px/, "" + picSize + "px");
        return depictionUrl;
      }
    },
    _getLabel: function(entity) {
      var preferredFields, preferredLanguages;
      preferredFields = this.options.labelProperties;
      preferredLanguages = [this._getUserLang(), this.options.fallbackLanguage];
      return VIE.Util.getPreferredLangForPreferredProperty(entity, preferredFields, preferredLanguages);
    },
    _getDescription: function(entity) {
      var preferredFields, preferredLanguages;
      preferredFields = this.options.descriptionProperties;
      preferredLanguages = [this._getUserLang(), this.options.fallbackLanguage];
      return VIE.Util.getPreferredLangForPreferredProperty(entity, preferredFields, preferredLanguages);
    }
  });

}).call(this);