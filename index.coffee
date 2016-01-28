_ = require 'lodash'

class JobLogger
  constructor: ({@client, @jobLogQueue}) ->

  log: ({error,request,response,elapsedTime}, callback) =>
    job = @formatLogEntry {error,request,response,elapsedTime}
    @client.lpush @jobLogQueue, job, callback

  formatLogEntry: ({error,request,response,elapsedTime}) =>
    requestMetadata  = _.cloneDeep(request?.metadata  ? {})
    responseMetadata = _.cloneDeep(response?.metadata ? {})
    responseMetadata.success = (responseMetadata.code < 500)

    return {
      elapsedTime: elapsedTime
      date: Date.now() - elapsedTime
      request:
        metadata = requestMetadata
      response:
        metadata: responseMetadata
    }

module.exports = JobLogger
