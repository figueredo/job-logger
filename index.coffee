_ = require 'lodash'
async = require 'async'
moment = require 'moment'

class JobLogger
  constructor: ({@client, @indexPrefix, @jobLogQueue, @type}) ->
    throw new Error('client is required') unless @client?
    throw new Error('indexPrefix is required') unless @indexPrefix?
    throw new Error('jobLogQueue is required') unless @jobLogQueue?
    throw new Error('type is required') unless @type?

  log: ({error,request,response,elapsedTime,date}, callback) =>
    entries = @formatLogEntries {error, request, response, elapsedTime, date}
    async.each entries, @logEntry, callback

  logEntry: (entry, callback) =>
    @client.lpush @jobLogQueue, JSON.stringify(entry), (error) =>
      delete error.code if error?
      callback error

  formatLogEntries: ({request,response,elapsedTime,date}) =>
    todaySuffix = moment.utc().format('YYYY-MM-DD')
    requestMetadata  = _.cloneDeep(request?.metadata  ? {})
    responseMetadata = _.cloneDeep(response?.metadata ? {})

    {metrics} = responseMetadata
    delete requestMetadata.auth?.token

    if metrics?
      date           ?= Math.floor(metrics.enqueueRequestAt)
      elapsedTime    ?= Math.floor(metrics.dequeueResponseAt - metrics.enqueueRequestAt)
      requestLagTime  = Math.floor(metrics.dequeueRequestAt - metrics.enqueueRequestAt)
      responseLagTime = Math.floor(metrics.dequeueResponseAt - metrics.enqueueResponseAt)

    date ?= Math.floor(Date.now() - elapsedTime) # remove this next time you see it

    responseMetadata.success = (responseMetadata.code < 500)

    requestMetadata.jobLogs ?= []
    unless responseMetadata.success
      requestMetadata.jobLogs.push 'failed'

    _.map requestMetadata.jobLogs, (jobLog) =>
      index = "#{@indexPrefix}:#{jobLog}-#{todaySuffix}"

      {
        index: index
        type: @type
        body:
          type: @type
          date: date
          elapsedTime: elapsedTime
          requestLagTime: requestLagTime
          responseLagTime: responseLagTime
          rawDataSize: response?.rawData?.length ? 0
          request:
            metadata: requestMetadata
          response:
            metadata: responseMetadata
      }

module.exports = JobLogger
