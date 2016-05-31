redis = require 'fakeredis'
moment = require 'moment'
RedisNS = require '@octoblu/redis-ns'
UUID = require 'uuid'
JobLogger = require '../'

describe 'logging', ->
  describe 'when jobLog.enabled is not set', ->
    beforeEach (done) ->
      @clientId = UUID.v1()

      client = new RedisNS 'ns', redis.createClient(@clientId)
      @client = new RedisNS 'ns', redis.createClient(@clientId)

      @sut = new JobLogger {
        client
        jobLogQueue: 'someQueueName'
        indexPrefix: 'foo'
        type: 'thipeh'
      }

      record =
        error: null
        request:
          metadata:
            auth: {uuid: 'the-uuid', token: 'the-token'}
        response: {}
        elapsedTime: 0
      @sut.log record, done

    it 'should not log the record', (done) ->
      @client.llen 'someQueueName', (error, count) =>
        return done error if error?
        expect(count).to.equal 0
        done()

  describe 'when jobLog.enabled is true', ->
    beforeEach (done) ->
      @clientId = UUID.v1()

      client = new RedisNS 'ns', redis.createClient(@clientId)
      @client = new RedisNS 'ns', redis.createClient(@clientId)

      @sut = new JobLogger {
        client
        jobLogQueue: 'someQueueName'
        indexPrefix: 'foo'
        type: 'thipeh'
      }

      record =
        error: null
        request:
          metadata:
            auth: {uuid: 'the-uuid', token: 'the-token'}
            jobLog:
              enabled: true
              prefix: 'bamboo'
        response:
          metadata:
            metrics:
              enqueueRequestAt: 1
              dequeueRequestAt: 5
              enqueueResponseAt: 10
              dequeueResponseAt: 11
          rawData: 'hello'

      @sut.log record, done

    it 'should log the record', (done) ->
      @client.brpop 'someQueueName', 1, (error, response) =>
        return done error if error?
        return done new Error 'no response' unless response?
        [channel,record] = response
        expect(JSON.parse record).to.containSubset
          index: "foo:bamboo-#{moment.utc().format('YYYY-MM-DD')}"
          type: 'thipeh'
          body:
            type: 'thipeh'
            elapsedTime: 10
            requestLagTime: 4
            responseLagTime: 1
            rawDataSize: 5
        done()
