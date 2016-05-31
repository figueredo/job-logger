redis = require 'fakeredis'
RedisNS = require '@octoblu/redis-ns'
UUID = require 'uuid'
JobLogger = require '../'

describe 'when called with a token', ->
  beforeEach (done) ->
    @clientId = UUID.v1()

    client = new RedisNS 'ns', redis.createClient(@clientId)
    @client = new RedisNS 'ns', redis.createClient(@clientId)

    @sut = new JobLogger {
      client
      jobLogQueue: 'mah-queue'
      indexPrefix: 'foo'
      type: 'thipeh'
    }

    record =
      error: null
      request:
        metadata:
          auth: {uuid: 'the-uuid', token: 'the-token'}
          jobLogs: ['sampled']
      response: {}
      elapsedTime: 0
    @sut.log record, done

  it 'should remove the token before logging the record', (done) ->
    @client.lpop 'mah-queue', (error, record) =>
      return done error if error?
      record = JSON.parse record
      expect(record.body.request.metadata.auth.token).not.to.exist
      done()
