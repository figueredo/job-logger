_ = require 'lodash'
moment = require 'moment'

class JobLogger
  constructor: ({@client, @indexPrefix, @jobLogQueue, @sampleRate, @type}) ->
    throw new Error('client is required') unless @client?
    throw new Error('indexPrefix is required') unless @indexPrefix?
    throw new Error('jobLogQueue is required') unless @jobLogQueue?
    throw new Error('sampleRate is required') unless @sampleRate?
    throw new Error('type is required') unless @type?

  log: ({error,request,response,elapsedTime,date}, callback) =>
    return callback() if Math.random() > @sampleRate
    job = @formatLogEntry {error,request,response,elapsedTime,date}
    @client.lpush @jobLogQueue, JSON.stringify(job), (error) =>
      delete error.code if error?
      callback error

  formatLogEntry: ({request,response,elapsedTime,date}) =>
    todaySuffix = moment.utc().format('YYYY-MM-DD')
    requestMetadata  = _.cloneDeep(request?.metadata  ? {})
    responseMetadata = _.cloneDeep(response?.metadata ? {})
    delete requestMetadata.auth?.token
    responseMetadata.success = (responseMetadata.code < 500)
    index = "#{@indexPrefix}-#{todaySuffix}"
    date ?= Date.now() - elapsedTime

    return {
      index: index
      type: @type
      body:
        elapsedTime: elapsedTime
        date: date
        request:
          metadata: requestMetadata
        response:
          metadata: responseMetadata
    }

module.exports = JobLogger
