_ = require 'lodash'
moment = require 'moment'

class JobLogger
  constructor: ({@client, @jobLogQueue, @indexPrefix, @type}) ->

  log: ({error,request,response,elapsedTime}, callback) =>
    job = @formatLogEntry {error,request,response,elapsedTime}
    @client.lpush @jobLogQueue, JSON.stringify(job), (error) =>
      delete error.code if error?
      callback error

  formatLogEntry: ({error,request,response,elapsedTime}) =>
    todaySuffix = moment.utc().format('YYYY-MM-DD')
    requestMetadata  = _.cloneDeep(request?.metadata  ? {})
    responseMetadata = _.cloneDeep(response?.metadata ? {})
    delete requestMetadata.auth?.token
    responseMetadata.success = (responseMetadata.code < 500)
    index = "#{@indexPrefix}-#{todaySuffix}"

    return {
      index: index
      type: @type
      body:
        elapsedTime: elapsedTime
        date: Date.now() - elapsedTime
        request:
          metadata: requestMetadata
        response:
          metadata: responseMetadata
    }

module.exports = JobLogger
