# this should go into its own module: eventric-mongodb-eventstore so we can test with mongodb
# TODO actually this should not know anything about aggregates and events, we need a `DomainEventRepository` for that, dont we?
MongoClient = require('mongodb').MongoClient

class MongoDBEventStore

  initialize: (callback) ->

    MongoClient.connect 'mongodb://127.0.0.1:27017/events', (err, db) =>

      if err
        console.log 'MongoDB connection failed'
        callback? err, null
        return

      console.log 'MongoDB connected'
      @db = db
      callback? null



  save: (domainEvent, callback) ->

    @db.collection domainEvent.aggregate.name, (err, collection) ->

      collection.insert domainEvent, (err, doc) ->
        return callback err if err

        callback null



  findByAggregateId: (aggregateName, aggregateId, callback) ->


    @db.collection aggregateName, (err, collection) =>

      collection.find { 'aggregate.id': aggregateId }, (err, cursor) =>
        return callback err, null if err

        cursor.toArray (err, items) =>
          return callback err, null if err

          callback null, items


  find: ([aggregateName, query, projection]..., callback) =>

    @db.collection aggregateName, (err, collection) =>

      collection.find query, projection, (err, cursor) =>
        return callback err, null if err

        cursor.toArray (err, items) =>
          return callback err, null if err

          callback null, items


module.exports = MongoDBEventStore