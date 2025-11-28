// Conditional export - automatically selects web or mobile implementation
export 'web_pdf_handler.dart'
    if (dart.library.js) 'web_pdf_handler.dart'
    if (dart.library.io) 'web_pdf_handler_stub.dart';
