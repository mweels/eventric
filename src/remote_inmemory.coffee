customRemoteBridge = null

class InMemoryRemoteEndpoint
  constructor: (@_handleRPCRequest) ->
    customRemoteBridge = (rpcRequest) =>
      new Promise (resolve, reject) =>
        @_handleRPCRequest rpcRequest, (error, result) ->
          return reject error if error
          resolve result

module.exports.endpoint = InMemoryRemoteEndpoint


class InMemoryRemoteClient
  rpc: (rpcRequest) ->
    new Promise (resolve, reject) ->
      customRemoteBridge rpcRequest
      .then (result) ->
        resolve result
      .catch (error) ->
        reject error

module.exports.client = InMemoryRemoteClient