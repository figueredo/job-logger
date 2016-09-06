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

    responseMetadata.jobLogs ?= []
    unless responseMetadata.success
      responseMetadata.jobLogs.push 'failed'

    requestRawDataSize = 0
    if request?.data?
      requestRawDataSize = JSON.stringify(request.data).length
    if request.rawData?
      requestRawDataSize = request.rawData.length

    responseRawDataSize = 0
    if response?.data?
      responseRawDataSize = JSON.stringify(response.data).length
    if response.rawData?
      responseRawDataSize = response.rawData.length

    _.map responseMetadata.jobLogs, (jobLog) =>
      index = "#{@indexPrefix}:#{jobLog}-#{todaySuffix}"

      {
        index: index
        type: @type
        body:
          index: index
          type: @type
          date: date
          elapsedTime: elapsedTime
          requestLagTime: requestLagTime
          responseLagTime: responseLagTime
          rawDataSize: responseRawDataSize
          request:
            lagTime: requestLagTime
            rawDataSize: requestRawDataSize
            metadata: requestMetadata
          response:
            lagTime: responseLagTime
            rawDataSize: responseRawDataSize
            metadata: responseMetadata
      }

module.exports = JobLogger
