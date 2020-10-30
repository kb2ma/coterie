## coterie main
##
## Runs libcoap server and client
##
## Copyright 2020 Ken Bannister
## SPDX-License-Identifier: Apache-2.0

import libcoap, posix, nativesockets
import threadpool
import logging

var
  log: FileLogger
  ctx: CContext
  address: ptr CSockAddr
  ep: CEndpoint

proc handleHi(context: CContext, resource: CResource, session: CSession,
              req: CPdu, token: CCoapBinary, query: CCoapString, resp: CPdu)
              {.exportc: "hnd_hi", noconv.} =
  ## server /hi GET handler; greeting
  resp.`type` = COAP_MESSAGE_ACK
  resp.code = COAP_RESPONSE_CODE_205
  discard addData(resp, 5, "Howdy")

proc handleResponse(context: CContext, session: CSession, sent: CPdu,
                    received: CPdu, id: CTxid) {.exportc: "hnd_response",
                    noconv.} =
  ## client response handler
  debug("Response received")

proc onQuit() {.noconv.} =
  ## Cleanup resources when exit
  if ep != nil:
    freeEndpoint(ep)
  if address != nil:
    dealloc(address)
  if ctx != nil:
    freeContext(ctx)
  info("Exiting gracefully")


proc sendMessage() =
  ## Send a message to exercise client flow

  # init server address/port
  address = create(CSockAddr)
  initAddress(address)
  try:
    let info = getAddrInfo("127.0.0.1", 5685.Port, Domain.AF_INET,
                           SockType.SOCK_DGRAM, Protocol.IPPROTO_UDP)
    address.`addr`.sin = cast[SockAddr_in](info.ai_addr[])
    freeaddrinfo(info)
  except OSError:
    error("Can't resolve server address")
    return

  #init session
  var session = newClientSession(ctx, nil, address, COAP_PROTO_UDP)
  if session == nil:
    error("Can't create client session")
    return

  # init PDU, including type and code
  var pdu = initPdu(COAP_MESSAGE_CON, COAP_REQUEST_GET.uint8, 1000'u16,
                    maxSessionPduSize(session))
  if pdu == nil:
    error("Can't create client PDU")
    releaseSession(session)
    return

  # add Uri-Path option
  var optlist = newOptlist(COAP_OPTION_URI_PATH, 4.csize_t, cast[ptr uint8]("time"))
  if optlist == nil:
    error("Can't create option list")
    return
  if addOptlistPdu(pdu, addr(optlist)) == 0:
    error("Can't create option list")
    deleteOptlist(optlist)
    releaseSession(session)
    deletePdu(pdu)
    return
  deleteOptlist(optlist)

  # send
  if send(session, pdu) == COAP_INVALID_TXID:
    deletePdu(pdu)

  # clean up
  #releaseSession(session)


# application setup
log = newFileLogger("ops.log", fmtStr="[$time] $levelname: ", bufSize=0)
addQuitProc(onQuit)

# init context, listen port/endpoint
ctx = newContext(nil)

# CoAP server setup
address = create(CSockAddr)
initAddress(address)
address.`addr`.sin.sin_family = Domain.AF_INET.cushort
address.`addr`.sin.sin_port = posix.htons(5683)

ep = newEndpoint(ctx, address, COAP_PROTO_UDP)

info("Coterie started on port ", posix.ntohs(address.`addr`.sin.sin_port))

# Establish server resources and request handlers, and also the client
# response handler.
var r = initResource(makeStringConst("hi"), 0)
registerHandler(r, COAP_REQUEST_GET, handleHi)
addResource(ctx, r)
#ctx.response_handler = handleResponse
registerResponseHandler(ctx, handleResponse)

# wait asynchronously for user input
var messageFlowVar = spawn stdin.readLine()

# Serve resources until quit
while true:
  discard processIo(ctx, 500'u32)

  if messageFlowVar.isReady():
    case ^messageFlowVar
    of "s":
      sendMessage()
    of "q":
      break
    messageFlowVar = spawn stdin.readLine()
