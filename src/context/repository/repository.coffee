eventric  = require 'eventric'
Aggregate = require 'eventric/src/context/aggregate'

class Repository

  constructor: (params) ->
    @_aggregateName  = params.aggregateName
    @_AggregateRoot  = params.AggregateRoot
    @_context        = params.context

    @_command = {}
    @_aggregateInstances = {}
    @_store = @_context.getDomainEventsStore()


  ###*
  * @name findById
  *
  * @module Repository
  ###
  findById: (aggregateId, callback = ->) =>
    new Promise (resolve, reject) =>
      @_findDomainEventsForAggregate aggregateId, (err, domainEvents) =>
        if err
          callback err, null
          reject err
          return

        if not domainEvents.length
          err = "No domainEvents for #{@_aggregateName} Aggregate with #{aggregateId} available"
          eventric.log.error err
          callback err, null
          reject err
          return

        aggregate = new Aggregate @_context, @_aggregateName, @_AggregateRoot
        aggregate.applyDomainEvents domainEvents
        aggregate.id = aggregateId

        commandId = @_command.id ? 'nocommand'
        @_aggregateInstances[commandId] ?= {}
        @_aggregateInstances[commandId][aggregateId] = aggregate

        callback null, aggregate.root
        resolve aggregate.root


  _findDomainEventsForAggregate: (aggregateId, callback) ->
    @_store.findDomainEventsByAggregateId aggregateId, (err, domainEvents) =>
      return callback err, null if err
      return callback null, [] if domainEvents.length == 0
      callback null, domainEvents


  ###*
  * @name create
  *
  * @module Repository
  ###
  create: =>
    params = arguments
    if typeof params[params.length-1] is 'function'
      callback = params.pop()

    new Promise (resolve, reject) =>
      aggregate = new Aggregate @_context, @_aggregateName, @_AggregateRoot
      aggregate.create params...
      .then (aggregate) =>
        commandId = @_command.id ? 'nocommand'
        @_aggregateInstances[commandId] ?= {}
        @_aggregateInstances[commandId][aggregate.id] = aggregate
        callback? null, aggregate.id
        resolve aggregate.id


  ###*
  * @name save
  *
  * @module Repository
  ###
  save: (aggregateId, callback=->) =>
    new Promise (resolve, reject) =>
      commandId = @_command.id ? 'nocommand'
      aggregate = @_aggregateInstances[commandId][aggregateId]
      if not aggregate
        err = "Tried to save unknown aggregate #{@_aggregateName}"
        eventric.log.error err
        err = new Error err
        callback? err, null
        reject err
        return

      domainEvents   = aggregate.getDomainEvents()
      if domainEvents.length < 1
        err = "Tried to save 0 DomainEvents from Aggregate #{@_aggregateName}"
        eventric.log.debug err, @_command
        err = new Error err
        callback? err, null
        reject err
        return

      eventric.log.debug "Going to Save and Publish #{domainEvents.length} DomainEvents from Aggregate #{@_aggregateName}"

      # TODO: this should be an transaction to guarantee consistency
      eventric.eachSeries domainEvents, (domainEvent, next) =>
        domainEvent.command = @_command
        @_store.saveDomainEvent domainEvent, =>
          eventric.log.debug "Saved DomainEvent", domainEvent
          next null
      , (err) =>
        if err
          callback err, null
          reject err
        else
          if not @_context.isWaitingModeEnabled()
            for domainEvent in domainEvents
              eventric.log.debug "Publishing DomainEvent", domainEvent
              @_context.getEventBus().publishDomainEvent domainEvent, ->
            resolve aggregate.id
            callback null, aggregate.id
          else
            eventric.eachSeries domainEvents, (domainEvent, next) =>
              eventric.log.debug "Publishing DomainEvent in waiting mode", domainEvent
              @_context.getEventBus().publishDomainEventAndWait domainEvent, next
            , (err) =>
              if err
                callback err, null
                reject err
              else
                resolve aggregate.id
                callback null, aggregate.id



  ###*
  * @name setCommand
  *
  * @module Repository
  ###
  setCommand: (command) ->
    @_command = command


module.exports = Repository