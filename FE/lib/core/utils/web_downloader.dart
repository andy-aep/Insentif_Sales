import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:universal_html/html.dart' as html;
import '../network/dio_client.dart';

class WebDownloader {
  static Future<void> downloadExcel(
    String urlPath,
    String filename, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await DioClient.instance.get(
      urlPath,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );

    downloadBytes(
      response.data is List<int>
          ? Uint8List.fromList(response.data as List<int>)
          : response.data as Uint8List,
      filename,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static void downloadBytes(
    Uint8List bytes,
    String filename, {
    String mimeType = 'application/octet-stream',
  }) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}
