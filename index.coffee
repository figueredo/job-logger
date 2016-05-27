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

    {metrics} = responseMetadata
    delete requestMetadata.auth?.token

    if metrics
      date           ?= Math.floor(metrics.enqueueRequestAt)
      elapsedTime    ?= Math.floor(metrics.dequeueResponseAt - metrics.enqueueRequestAt)
      requestLagTime  = Math.floor(metrics.dequeueRequestAt - metrics.enqueueRequestAt)
      responseLagTime = Math.floor(metrics.dequeueResponseAt - metrics.enqueueResponseAt)

    date ?= Math.floor(Date.now() - elapsedTime) # remove this next time you see it

    responseMetadata.success = (responseMetadata.code < 500)

    index = "#{@indexPrefix}-#{todaySuffix}"

    return {
      index: index
      type: @type
      body:
        type: @type
        elapsedTime: elapsedTime
        requestLagTime: requestLagTime
        responseLagTime: responseLagTime
        date: date
        rawDataSize: response?.rawData?.length ? 0
        request:
          metadata: requestMetadata
        response:
          metadata: responseMetadata
    }

module.exports = JobLogger
