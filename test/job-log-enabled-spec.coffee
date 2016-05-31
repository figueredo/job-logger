redis = require 'fakeredis'
moment = require 'moment'
RedisNS = require '@octoblu/redis-ns'
UUID = require 'uuid'
JobLogger = require '../'

describe 'logging', ->
  describe 'when jobLogs is blank', ->
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
        response:
          metadata:
            code: 200
        elapsedTime: 0
      @sut.log record, done

    it 'should not log the record', (done) ->
      @client.llen 'someQueueName', (error, count) =>
        return done error if error?
        expect(count).to.equal 0
        done()

  describe 'when jobLogs is blank, but the response code > 500', ->
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
        response:
          metadata:
            code: 999 # UH-OH!
        elapsedTime: 0
      @sut.log record, done

    it 'should log 1 entry', (done) ->
      @client.llen 'someQueueName', (error, count) =>
        return done error if error?
        expect(count).to.equal 1
        done()

    describe 'when popping the first record', ->
      it 'should log the record', (done) ->
        @client.brpop 'someQueueName', 1, (error, response) =>
          return done error if error?
          return done new Error 'no response' unless response?
          [channel,record] = response
          expect(JSON.parse record).to.containSubset
            index: "foo:failed-#{moment.utc().format('YYYY-MM-DD')}"
          done()

  describe 'when jobLogs is an array', ->
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
            jobLogs: [ 'sampled', 'foo' ]
        response:
          metadata:
            code: 200
            metrics:
              enqueueRequestAt: 1
              dequeueRequestAt: 5
              enqueueResponseAt: 10
              dequeueResponseAt: 11
          rawData: 'hello'

      @sut.log record, done

    it 'should log 2 entries', (done) ->
      @client.llen 'someQueueName', (error, count) =>
        return done error if error?
        expect(count).to.equal 2
        done()

    describe 'when popping the first record', ->
      it 'should log the record', (done) ->
        @client.brpop 'someQueueName', 1, (error, response) =>
          return done error if error?
          return done new Error 'no response' unless response?
          [channel,record] = response
          expect(JSON.parse record).to.containSubset
            index: "foo:sampled-#{moment.utc().format('YYYY-MM-DD')}"
            type: 'thipeh'
            body:
              type: 'thipeh'
              elapsedTime: 10
              requestLagTime: 4
              responseLagTime: 1
              rawDataSize: 5
          done()

      describe 'when popping the second record', ->
        it 'should log foo', (done) ->
          @client.brpop 'someQueueName', 1, (error, response) =>
            @client.brpop 'someQueueName', 1, (error, response) =>
              return done error if error?
              return done new Error 'no response' unless response?
              [channel,record] = response
              expect(JSON.parse record).to.containSubset
                index: "foo:foo-#{moment.utc().format('YYYY-MM-DD')}"
                type: 'thipeh'
                body:
                  type: 'thipeh'
                  elapsedTime: 10
                  requestLagTime: 4
                  responseLagTime: 1
                  rawDataSize: 5
              done()
