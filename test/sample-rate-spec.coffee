redis = require 'fakeredis'
RedisNS = require '@octoblu/redis-ns'
UUID = require 'uuid'
JobLogger = require '../'

describe 'sampleRate', ->
  describe 'when instantiated with sampleRate of 0.00', ->
    beforeEach (done) ->
      @clientId = UUID.v1()

      client = new RedisNS 'ns', redis.createClient(@clientId)
      @client = new RedisNS 'ns', redis.createClient(@clientId)

      @sut = new JobLogger {
        client
        jobLogQueue: 'someQueueName'
        sampleRate: 0.00
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

  describe 'when instantiated with sampleRate of 1.00', ->
    beforeEach (done) ->
      @clientId = UUID.v1()

      client = new RedisNS 'ns', redis.createClient(@clientId)
      @client = new RedisNS 'ns', redis.createClient(@clientId)

      @sut = new JobLogger {
        client
        jobLogQueue: 'someQueueName'
        sampleRate: 1.00
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

    it 'should log the record', (done) ->
      @client.llen 'someQueueName', (error, count) =>
        return done error if error?
        expect(count).to.equal 1
        done()
