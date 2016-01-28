_ = require 'lodash'
moment = require 'moment'

class JobLogger
  constructor: ({@client, @jobLogQueue, @indexPrefix, @type}) ->

  log: ({error,request,response,elapsedTime}, callback) =>
    job = @formatLogEntry {error,request,response,elapsedTime}
    @client.lpush @jobLogQueue, JSON.stringify(job), callback

  formatLogEntry: ({error,request,response,elapsedTime}) =>
    todaySuffix = moment.utc().format('YYYY-MM-DD')
    requestMetadata  = _.cloneDeep(request?.metadata  ? {})
    responseMetadata = _.cloneDeep(response?.metadata ? {})
    responseMetadata.success = (responseMetadata.code < 500)
    index = "#{@indexPrefix}-#{todaySuffix}"

    return {
      _index: index
      _type: @type
      body:
        elapsedTime: elapsedTime
        date: Date.now() - elapsedTime
        request:
          metadata = requestMetadata
        response:
          metadata: responseMetadata
    }

module.exports = JobLogger
