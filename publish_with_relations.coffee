Meteor.publishWithRelations = (params) ->
  pub = params.handle
  collection = params.collection
  associations = {}
  publishAssoc = (collection, filter, options) ->
    collection.find(filter, options).observeChanges
      added: (id, fields) =>
        pub.added(collection._name, id, fields)
      changed: (id, fields) =>
        pub.changed(collection._name, id, fields)
      removed: (id) =>
        pub.removed(collection._name, id)
  doMapping = (id, obj, mappings) ->
    for mapping in mappings
      mapFilter = {}
      mapOptions = {}
      if mapping.reverse
        objKey = mapping.collection._name
        mapFilter[mapping.key] = id
      else
        objKey = mapping.key
        mapFilter._id = obj[mapping.key]
      _.extend(mapFilter, mapping.filter)
      _.extend(mapOptions, mapping.options)
      if mapping.mappings
        Meteor.publishWithRelations
          handle: pub
          collection: mapping.collection
          filter: mapFilter
          options: mapOptions
          mappings: mapping.mappings
      else
        associations[id][objKey]?.stop()
        associations[id][objKey] =
          publishAssoc(mapping.collection, mapFilter, mapOptions)

  filter = params.filter
  options = params.options
  collectionHandle = collection.find(filter, options).observeChanges
    added: (id, fields) ->
      pub.added(collection._name, id, fields)
      associations[id] ?= {}
      doMapping(id, fields, params.mappings)
    changed: (id, fields) ->
      _.each fields, (value, key) ->
        changedMappings = _.where(params.mappings, {key: key, reverse: false})
        doMapping(id, fields, changedMappings)
      pub.changed(collection._name, id, fields)
    removed: (id) ->
      handle.stop() for handle in associations[id]
      pub.removed(collection._name, id)
  pub.ready()

  pub.onStop ->
    for association in associations
      handle.stop() for handle in association
    collectionHandle.stop()
