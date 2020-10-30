## libcoap wrapper
##
## Copyright 2020 Ken Bannister
## SPDX-License-Identifier: Apache-2.0

import nativesockets, posix

# only supports Linux at present
const libName = "libcoap-2.so"

type
  CProto* = uint8
  ## coap_proto_t

  CTxid* = cint

const
  COAP_PROTO_NONE* = 0.CProto
  COAP_PROTO_UDP* = 1.CProto
  COAP_PROTO_DTLS* = 2.CProto
  COAP_PROTO_TCP* = 3.CProto
  COAP_PROTO_TLS* = 4.CProto

  # Message types
  COAP_MESSAGE_CON* = 0'u8
  COAP_MESSAGE_NON* = 1'u8
  COAP_MESSAGE_ACK* = 2'u8
  COAP_MESSAGE_RST* = 3'u8

  COAP_RESPONSE_CODE_205* = ((2 shl 5) or 5).uint8

  COAP_OPTION_URI_PATH* = 11'u16

  COAP_INVALID_TXID* = -1.CTxid

type
  CRequestCode* = enum
    ## coap_request_t, and value is 'detail' portion of request method code
    COAP_REQUEST_GET = 1,
    COAP_REQUEST_POST,
    COAP_REQUEST_PUT,
    COAP_REQUEST_DELETE,
    COAP_REQUEST_PATCH,
    COAP_REQUEST_IPATCH

  CSockAddrUnion* {.union} = object
    ## Used only by CSockAddr
    sa*: SockAddr
    sin*: Sockaddr_in
    sin6*: Sockaddr_in6

  CSockAddr* {.importc: "struct coap_address_t",
              header: "<coap2/address.h>".} = object
    ## libcoap internal socket address
    size*: SockLen
    `addr`*: CSockAddrUnion

  CStringConst* {.importc: "struct coap_str_const_t",
                 header: "<coap2/str.h>"} = ptr object

  CContext* = ptr object
    ## libcoap top-level data object; libcoap always manages heap memory
    #response_handler*: pointer

  CEndpoint* = ptr object
    ## libcoap coap_endpoint_t; opaque

  CResource* = ptr object

  CSession* = ptr object

  CPdu* = ptr object
    ## coap_pdu_t
    `type`*: uint8
    code*: uint8

  COptlist* = ptr object

  CCoapBinary* = ptr object

  CCoapString* = ptr object

  CRequestHandler* = proc (context: CContext, resource: CResource,
                           session: CSession, req: CPdu, token: CCoapBinary,
                           query: CCoapString, resp: CPdu) {.noconv.}

  CResponseHandler* = proc (context: CContext, session: CSession, sent: CPdu,
                            received: CPdu, id: CTxid) {.noconv.}


{.push dynlib: libName.}
# net.h
proc freeContext*(context: CContext) {.importc: "coap_free_context".}

proc newContext*(listen_addr: ptr CSockAddr): CContext
     {.importc: "coap_new_context".}

# Must include header pragma because library function is 'static inline'.
proc registerResponseHandler*(context: CContext, handler: CResponseHandler)
                              {.header: "coap2/net.h",
                               importc: "coap_register_response_handler".}

proc send*(session: CSession, pdu: CPdu): CTxid {.importc: "coap_send".}

# coap_session.h
proc freeEndpoint*(ep: CEndpoint) {.importc: "coap_free_endpoint".}

proc maxSessionPduSize*(session: CSession): csize_t
                       {.importc: "coap_session_max_pdu_size".}

proc newClientSession*(context: CContext, local_addr: ptr CSockAddr,
                       server_addr: ptr CSockAddr, proto: CProto): CSession
                       {.importc: "coap_new_client_session".}

proc newEndpoint*(context: CContext, listen_addr: ptr CSockAddr,
                 proto: CProto): CEndpoint {.importc: "coap_new_endpoint".}

proc releaseSession*(session: CSession) {.importc: "coap_session_release".}

# resource.h
proc addResource*(context: CContext, resource: CResource)
                 {.importc: "coap_add_resource".}

proc initResource*(uri_path: CStringConst, flags: cint): CResource
                  {.importc: "coap_resource_init".}

proc registerHandler*(resource: CResource, `method`: CRequestCode,
                     handler: CRequestHandler)
                     {.importc: "coap_register_handler".}

# pdu.h
proc addData*(pdu: CPdu, len: csize_t, data: cstring): cint
             {.importc: "coap_add_data".}

proc deletePdu*(pdu: CPdu) {.importc: "coap_delete_pdu".}

proc initPdu*(`type`: uint8, code: uint8, txid: uint16 = 0, size: csize_t): CPdu
              {.importc: "coap_pdu_init".}
  ## 'type' is one of the COAP_MESSAGE... constants
  ## 'code' param value is CRequestCode for a request

# option.h
proc addOptlistPdu*(pdu: CPdu, chain: ptr COptlist): cint
                    {.importc: "coap_add_optlist_pdu".}

proc deleteOptlist*(list: COptlist) {.importc: "coap_delete_optlist".}
  ## Must delete optlist created by newOptlist

proc newOptlist*(number: uint16, length: csize_t, data: ptr uint8): COptlist
                 {.importc: "coap_new_optlist".}

# coap_io.h
proc processIo*(context: CContext, timeout: uint32): cint
               {.importc: "coap_io_process".}

# address.h
proc initAddress*(address: ptr CSockAddr) {.importc: "coap_address_init".}

# str.h
proc makeStringConst*(str: cstring): CStringConst
                     {.importc: "coap_make_str_const".}
{.pop.}
