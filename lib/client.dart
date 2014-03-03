library restlib.client;

import "dart:async";
import "dart:convert";

import "package:restlib_common/collections.dart";
import "package:restlib_core/data.dart";
import "package:restlib_core/http.dart";
import "package:restlib_core/multipart.dart";

typedef Option<RequestWriter> RequestWriterProvider(Request request);
typedef Option<ResponseParser> ResponseParserProvider(ContentInfo contentInfo);
typedef Future<Response> ResponseParser(Response response, Stream<List<int>> msgStream);

abstract class RestClient<TReq, TRes> implements Function {
  Future<Response<TRes>> call(final Request<TReq> request);
}

abstract class RequestWriter<T> {
  Request withContentInfo(final Request request);
  Future write(final Request<T> request, StreamSink<List<int>> msgSink);
}

Future<Response<Multipart>> parseMultipart(
    final Response response,
    final Stream<List<int>> msgStream,
    Option<PartParser> partParserProvider(ContentInfo contentInfo)) =>
        first(response.contentInfo.mediaRange.value.parameters["boundary"])
          .map((final String boundary) =>
              parseMultipartStream(msgStream, boundary, partParserProvider)
                .then((final Option<Multipart> multipart) =>
                    response.with_(entity: multipart.nullableValue)))
          .orCompute(() =>
              new Future.value(response.with_(entity : null)));

Future<Response<Form>> parseForm(final Response response, final Stream<List<int>> msgStream) =>
    parseString(response, msgStream)
      .then((final Response<String> response) =>
          response.with_(entity: Form.parser.parse(response.entity.value).nullableValue));

Future<Response<String>> parseString(final Response response, final Stream<List<int>> msgStream) {
  final Charset charset =
      response.contentInfo.mediaRange
        .flatMap((final MediaRange mediaRange) =>
            mediaRange.charset)
        .orElse(Charset.UTF_8);

  return charset.codec
    .map((final Encoding codec) =>
        codec.decodeStream(msgStream)
          .then((final String requestBody) =>
              response.with_(entity: requestBody)))
    .orCompute(() => response.with_(entity: null));
}
