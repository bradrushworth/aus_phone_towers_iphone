import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/networking/response/elevation_response.dart';
import 'package:phonetowers/networking/response/site_response.dart';
import 'package:phonetowers/utils/app_constants.dart';

class Api {
  final String STAGING_BASE_URL = "https://api.bitbot.com.au/api";
  final String PRODUCTION_BASE_URL = "https://api.bitbot.com.au/api";
  //String url = '';
  Dio dio;
  Logger logger;

  Api.initialize() {
    //url = AppConstants.isDebug ? STAGING_BASE_URL : PRODUCTION_BASE_URL;
    dio = Dio()
      ..options.baseUrl =
          AppConstants.isDebug ? STAGING_BASE_URL : PRODUCTION_BASE_URL
      ..options.connectTimeout = 60000
      ..options.receiveTimeout = 60000;

    if (AppConstants.isDebug) {
      dio.interceptors
          .add(LogInterceptor(requestBody: true, responseBody: true));
    }

    logger = Logger();
  }

  // A function that will convert a response body into a SiteReponse
  static SiteReponse parseSiteResponse(var responseData) {
    return SiteReponse.fromJson(responseData);
  }

  // A function that will convert a response body into a ElevationReponse
  static ElevationResponse parseElevationResponse(var responseData) {
    return ElevationResponse.fromJson(responseData);
  }

  ///get Data
  Future<Object> getMarkerData(String path) async {
    try {
      Response response = await dio.get(path, options: Options());
      //print("marker data: ${response.data.toString()}");
      //final int statusCode = response.statusCode;
//      logger.i(
//          "raw site response ${jsonEncode(SiteReponse.fromJson(response.data))}");
      //return SiteReponse.fromJson(response.data);
      return compute(parseSiteResponse, response.data);
    } on DioError catch (e) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      /// Response info, it may be `null` if the request can't reach to
      /// the http server, for example, occurring a dns error, network is not available.
      logger.e('''Error message is ${e.message}
                  Error type is ${e.type}
                  Error is ${e.error}
                  For request ${e.requestOptions.path}
                  And Response ${e.response != null ? 'request => ${e.response.requestOptions.path} and data => ${e.response.data} headers => ${e.response.headers}' : 'request is ${e.requestOptions.path}'}''');
    }
  }

  ///get Data
  Future<Object> getDevicesData(String path) async {
    try {
      Response response = await dio.get(path, options: Options());
      //print("marker data: ${response.data.toString()}");
      final int statusCode = response.statusCode;
      //logger.i("raw device response ${response.data.toString()}");
      return compute(parseSiteResponse, response.data);
    } on DioError catch (e) {
      logger.e('''Error message is ${e.message}
                  Error type is ${e.type}
                  Error is ${e.error}
                  For request ${e.requestOptions.path}
                  And Response ${e.response != null ? 'request => ${e.response.requestOptions.path} and data => ${e.response.data} headers => ${e.response.headers}' : 'request is ${e.requestOptions.path}'}''');
    }
  }

  ///get Data
  Future<Object> getLicenceHRPData(String path,
      {CancelToken cancelToken}) async {
    try {
      Response response =
          await dio.get(path, options: Options(), cancelToken: cancelToken);
      //print("marker data: ${response.data.toString()}");
      final int statusCode = response.statusCode;
      //logger.i("raw licenceHRP response ${response.data.toString()}");
      return compute(parseSiteResponse, response.data);
    } on DioError catch (e) {
      if (CancelToken.isCancel(e)) {
        print('Cancelled $path: $e');
      }
    }
  }

  ///get Data
  Future<Object> getSearchedData(String path) async {
    try {
      Response response = await dio.get(path, options: Options());
      //print("marker data: ${response.data.toString()}");
      final int statusCode = response.statusCode;
      //logger.i("raw search response ${response.data.toString()}");
      return compute(parseSiteResponse, response.data);
    } on DioError catch (e) {
      logger.e('''Error message is ${e.message}
                  Error type is ${e.type}
                  Error is ${e.error}
                  For request ${e.requestOptions.path}
                  And Response ${e.response != null ? 'request => ${e.response.requestOptions.path} and data => ${e.response.data} headers => ${e.response.headers}' : 'request is ${e.requestOptions.path}'}''');
    }
  }

  ///Get Antenna data
  Future<Object> getAntennaDataApi(String path) async {
    try {
      Response response = await dio.get(path, options: Options());
      //print("marker data: ${response.data.toString()}");
      final int statusCode = response.statusCode;
      //logger.i("raw antenna response ${response.data.toString()}");
      return compute(parseSiteResponse, response.data);
    } on DioError catch (e) {
      logger.e('''Error message is ${e.message}
                  Error type is ${e.type}
                  Error is ${e.error}
                  For request ${e.requestOptions.path}
                  And Response ${e.response != null ? 'request => ${e.response.requestOptions.path} and data => ${e.response.data} headers => ${e.response.headers}' : 'request is ${e.requestOptions.path}'}''');
    }
  }

  ///Get Antenna data
  Future<Object> getElevationDataApi(String path) async {
    try {
      Response response = await dio.get(path, options: Options());
      //print("marker data: ${response.data.toString()}");
      final int statusCode = response.statusCode;
      //logger.i("raw antenna response ${response.data.toString()}");
      return compute(parseElevationResponse, response.data);
    } on DioError catch (e) {
      logger.e('''Error message is ${e.message}
                  Error type is ${e.type}
                  Error is ${e.error}
                  For request ${e.requestOptions.path}
                  And Response ${e.response != null ? 'request => ${e.response.requestOptions.path} and data => ${e.response.data} headers => ${e.response.headers}' : 'request is ${e.requestOptions.path}'}''');
    }
  }
}
