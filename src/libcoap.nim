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

const
  COAP_PROTO_NONE* = 0.CProto
  COAP_PROTO_UDP* = 1.CProto
  COAP_PROTO_DTLS* = 2.CProto
  COAP_PROTO_TCP* = 3.CProto
  COAP_PROTO_TLS* = 4.CProto

  COAP_MESSAGE_CON* = 0'u8
  COAP_MESSAGE_NON* = 1'u8
  COAP_MESSAGE_ACK* = 2'u8
  COAP_MESSAGE_RST* = 3'u8

  COAP_RESPONSE_CODE_205* = ((2 shl 5) or 5).uint8

type
  CRequestType* = enum
    ## coap_request_t
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

  CEndpoint* = ptr object
    ## libcoap coap_endpoint_t; opaque

  CResource* = ptr object

  CSession* = ptr object

  CPdu* = ptr object
    ## coap_pdu_t
    `type`*: uint8
    code*: uint8

  CCoapBinary* = ptr object

  CCoapString* = ptr object

  CMethodHandler* = proc (context: CContext, resource: CResource,
                             session: CSession, req: CPdu, token: CCoapBinary,
                             query: CCoapString, resp: CPdu) {.noconv.}


{.push dynlib: libName.}
# net.h
proc freeContext*(context: CContext) {.importc: "coap_free_context".}

proc newContext*(listen_addr: ptr CSockAddr): CContext
     {.importc: "coap_new_context".}

# session.h
proc freeEndpoint*(ep: CEndpoint) {.importc: "coap_free_endpoint".}

proc newEndpoint*(context: CContext, listen_addr: ptr CSockAddr,
                 proto: CProto): CEndpoint {.importc: "coap_new_endpoint"}

# resource.h
proc addResource*(context: CContext, resource: CResource)
                 {.importc: "coap_add_resource"}

proc initResource*(uri_path: CStringConst, flags: cint): CResource
                  {.importc: "coap_resource_init".}

proc registerHandler*(resource: CResource, mthd: CRequestType,
                     handler: CMethodHandler)
                     {.importc: "coap_register_handler".}

# pdu.h
proc addData*(pdu: CPdu, len: csize_t, data: cstring): cint
             {.importc: "coap_add_data"}

# coap_io.h
proc processIo*(context: CContext, timeout: uint32): cint
               {.importc: "coap_io_process"}

# address.h
proc initAddress*(address: ptr CSockAddr) {.importc: "coap_address_init".}

# str.h
proc makeStringConst*(str: cstring): CStringConst
                     {.importc: "coap_make_str_const".}
{.pop.}
