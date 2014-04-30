eventric              = require 'eventric'

AggregateRepository   = eventric 'AggregateRepository'
CommandService        = eventric 'CommandService'
DomainEventService    = eventric 'DomainEventService'

class BoundedContext
  aggregates: {}

  readAggregateRepositories: {}
  _readAggregateRepositoriesInstances: {}

  applicationServices: []

  _applicationServiceCommands: {}
  _applicationServiceQueries: {}

  initialize: (eventStore) ->
    @_initializeEventStore eventStore, =>
      @_aggregateRepository  = new AggregateRepository @_eventStore
      @_domainEventService   = new DomainEventService @_eventStore
      @_commandService       = new CommandService @_domainEventService, @_aggregateRepository

      @_initializeAggregates()
      @_initializeReadAggregateRepositories()
      @_initializeApplicationServices()


  _initializeEventStore: (eventStore, next) ->
    if eventStore
      @_eventStore = eventStore
      next()
    else
      MongoDBEventStore = require 'eventric-store-mongodb'
      @_eventStore = new MongoDBEventStore
      @_eventStore.initialize (err) =>
        next()

  _initializeAggregates: ->
    for aggregateName, aggregateClass of @aggregates
      @_aggregateRepository.registerClass aggregateName, aggregateClass


  _initializeReadAggregateRepositories: ->
    for repositoryName, ReadRepository of @readAggregateRepositories
      @_readAggregateRepositoriesInstances[repositoryName] = new ReadRepository repositoryName, @_eventStore


  _initializeApplicationServices: ->
    for applicationService in @applicationServices
      applicationService.commandService = @_commandService
      applicationService.getReadAggregateRepository = => @getReadAggregateRepository.apply @, arguments

      for commandName, commandMethodName of applicationService.commands
        # TODO check duplicates, warn and do some logging
        @_applicationServiceCommands[commandName] = ->
          applicationService[commandMethodName].apply applicationService, arguments

      for queryName, queryMethodName of applicationService.queries
        # TODO check duplicates, warn and do some logging
        @_applicationServiceQueries[queryName] = ->
         applicationService[queryMethodName].apply applicationService, arguments


  getReadAggregateRepository: (repositoryName) ->
    @_readAggregateRepositoriesInstances[repositoryName]


  # TODO emit error if command is not registered and not valid for default call
  command: (command) ->
    if @_applicationServiceCommands[command.name]
      @_applicationServiceCommands[command.name] command.params
    else
      [aggregateName, methodName] = @_splitAggregateAndMethod command.name
      @_commandService.commandAggregate aggregateName, command.id, methodName, command.params


  # TODO emit error if query is not registered and not valid for default call
  query: (query) ->
    if @_applicationServiceQueries[query.name]
      @_applicationServiceQueries[query.name] query.params
    else
      [aggregateName, methodName] = @_splitAggregateAndMethod query.name
      @getReadAggregateRepository(aggregateName)[methodName] query.id, query.params


  _splitAggregateAndMethod: (input) ->
    input.split ':'


  onDomainEvent: (eventName, eventHandler) ->
    @_domainEventService.on eventName, eventHandler


module.exports = BoundedContext