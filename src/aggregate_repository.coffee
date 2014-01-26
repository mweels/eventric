_        = require 'underscore'
eventric = require 'eventric'

MixinRegisterAndGetClass = eventric 'MixinRegisterAndGetClass'


class AggregateRepository

  _.extend @prototype, MixinRegisterAndGetClass::

  constructor: (@_eventStore) ->

  findById: (aggregateName, aggregateId, callback) ->
    # find all domainEvents matching the given aggregateId
    @_eventStore.find aggregateName, { 'aggregate.id': aggregateId }, (err, domainEvents) =>
      return callback err, null if err

      if domainEvents.length == 0
        # nothing found, return null
        callback null, null
        return

      # construct the Aggregate
      AggregateClass = @getClass aggregateName
      if not AggregateClass
        err = new Error "Tried to command not registered Aggregate '#{aggregateName}'"
        callback err, null
        return

      aggregate = new AggregateClass
      aggregate.id = aggregateId

      # apply the domainevents on the ReadAggregate
      for domainEvent in domainEvents
        if domainEvent.aggregate.changed
          aggregate.applyChanges domainEvent.aggregate.changed

      # return the aggregate
      callback null, aggregate


module.exports = AggregateRepository