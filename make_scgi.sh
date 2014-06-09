#!/bin/sh

# poner -d y -unittest
# -m64 para 64 bits
dmd -m32 -d -unittest -w -wi -O -ofmain_scgi lib/httpstatus.d core/uploadedfile.d core/request_context.d\
             core/multipart.d user/settings.d user/urls.d core/middleware.d\
             core/bindselector.d handlers/main_scgi.d lib/sjsocket.d core/response.d core/request.d\
             handlers/passfd/passfd.o user/controllers.d lib/generic_controllers.d\
             core/render_view.d core/urlsupport.d user/fakeauthmiddleware.d user/views/main.d lib/htmlutils.d core/queryutils.d\
             core/cookie.d core/template_parser.d

