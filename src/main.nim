## coterie main
##
## Runs libcoap server
##
## Copyright 2020 Ken Bannister
## SPDX-License-Identifier: Apache-2.0

import libcoap, posix, nativesockets
import logging

proc hndHi(context: CContext, resource: CResource, session: CSession,
           req: CPdu, token: CCoapBinary, query: CCoapString, resp: CPdu)
           {.exportc: "hnd_hi", noconv.} =
  ## /hi GET handler; greeting
  resp.`type` = COAP_MESSAGE_ACK
  resp.code = COAP_RESPONSE_CODE_205
  discard addData(resp, 5, "Howdy")

var
  oplog: FileLogger
  ctx: CContext
  address: ptr CSockAddr
  ep: CEndpoint

proc onQuit() {.noconv.} =
  ## Cleanup resources when exit
  if ep != nil:
    freeEndpoint(ep)
  if address != nil:
    dealloc(address)
  if ctx != nil:
    freeContext(ctx)
  oplog.log(lvlInfo, "Exiting gracefully")

# application setup
oplog = newFileLogger("ops.log", fmtStr="[$time] $levelname: ", bufSize=0)
addQuitProc(onQuit)

# init context, listen port/endpoint
ctx = newContext(nil)

address = create(CSockAddr)
initAddress(address)
address.`addr`.sin.sin_family = Domain.AF_INET.cushort
address.`addr`.sin.sin_port = posix.htons(5683)

ep = newEndpoint(ctx, address, COAP_PROTO_UDP)

oplog.log(lvlInfo, "Coterie started on port ",
          posix.ntohs(address.`addr`.sin.sin_port))

var r = initResource(makeStringConst("hi"), 0.cint)
registerHandler(r, COAP_REQUEST_GET, hndHi)
addResource(ctx, r)

# serve forever
while true:
    discard processIo(ctx, 0'u32)
