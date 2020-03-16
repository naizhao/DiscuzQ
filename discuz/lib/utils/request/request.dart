import 'package:dio/dio.dart';
import 'package:discuzq/utils/request/requestFormer.dart';
import 'package:flutter/material.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
/// import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:discuzq/utils/StringHelper.dart';
import 'package:discuzq/widgets/common/discuzToast.dart';
import 'package:discuzq/utils/authorizationHelper.dart';
import 'package:discuzq/utils/device.dart';
import 'package:discuzq/utils/urls.dart';
import 'package:discuzq/utils/request/RequestCacheInterceptor.dart';

const _contentFormData = "multipart/form-data";

class Request {
  final Dio _dio = Dio();
  final BuildContext context;

  Request({this.context}) {
    /// http2支持，如果你开启了HTTP2，那么移除注释，默认情况下是不启用的
    // _dio.httpClientAdapter = Http2Adapter(
    //   ConnectionManager(
    //     idleTimeout: 10000,

    //     /// Ignore bad certificate
    //     onClientCreate: (_, clientSetting) =>
    //         clientSetting.onBadCertificate = (_) => true,
    //   ),
    // );

    ///
    /// automatically decode json to dynamic
    _dio.transformer = RequestFormer(); // replace dio default transformer
    
    ///
    /// dio interceptors ext
    ///
    _dio.interceptors
      /// logger
      ..add(PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 90))

      /// 请求时携带cookies
      ..add(CookieManager(CookieJar()))

      /// 请求缓存优化
      ..add(RequestCacheInterceptor())

      /// interceptor procedure
      ..add(InterceptorsWrapper(onRequest: (RequestOptions options) async {
        final String userAgent = await Device.getWebviewUserAgent();
        final String deviceAgent = await Device.getDeviceAgentString();
        final String authorization = await AuthorizationHelper().getToken();

        // more devices
        options.connectTimeout = (1000 * 20);
        options.receiveTimeout = (1000 * 20);
        options.headers['User-Agent'] = userAgent;
        options.headers['Client-Type'] = 'app';
        options.headers['User-Device'] = deviceAgent.split(';')[0];
        if (authorization != null) {
          options.headers['Authorization'] = "Barear $authorization";
        }
        return options;
      }, onResponse: (Response response) {
        /// on dio response
        return response;
      }, onError: (DioError e) async {
        if (e.type == DioErrorType.DEFAULT) {
          DiscuzToast.failed(context: context, message: "连接失败，请检查互联网");
          return Future.value(e);
        }

        if (e.type == DioErrorType.CONNECT_TIMEOUT) {
          DiscuzToast.failed(context: context, message: '请求超时');
          return Future.value(e);
        }

        if (e.type == DioErrorType.RECEIVE_TIMEOUT) {
          DiscuzToast.failed(context: context, message: '响应超时');
          return Future.value(e);
        }

        ///
        /// 处理http status code非正常错误
        ///
        if (e.response != null && e.response.data != null) {
          if (e.response.data['code'] == 200) {
            return Future.value(e);
          }

          if (e.response.data['code'] == 401) {
            /// 尝试自动刷新token，如果刷新token成功，继续上次请求
            debugPrint("------------Token 自动刷新开始-----------");
            try {
              final bool refreshResult = await _refreshToken();
              if (refreshResult == true) {
                /// 继续上次请求 Get
                if (e.request.method == "GET") {
                  return await getUrl(
                      url: e.request.uri.toString(),
                      queryParameters: e.request.queryParameters);
                }

                /// 继续上次请求 Post Json
                if (e.request.method == "POST" &&
                    e.request.contentType == Headers.jsonContentType) {
                  return await postJson(
                      url: e.request.uri.toString(),
                      data: e.request.data,
                      queryParameters: e.request.queryParameters);
                }

                /// 继续上次文件上传
                if (e.request.method == "POST" &&
                    e.request.contentType == _contentFormData) {
                  return await uploadFile(
                      url: e.request.uri.toString(),
                      data: e.request.data,
                      queryParameters: e.request.queryParameters);
                }

                debugPrint("------------Token 自动刷新继续请求完成----------");
                return Future.value(e);
              }

              debugPrint("------------Token 自动刷新失败----------");
            } catch (e) {
              debugPrint(e);
            }

            /// 弹出登录
            _popLogin();

            DiscuzToast.failed(context: context, message: '登录过期，请重新登录');
            return Future.value(e);
          }

          ///
          /// 提示用户接口返回的错误信息
          ///
          String errMessage = e.response.data['data'] == null
              ? '未知错误'
              : e.response.data['data']['error'];

          ///
          /// 没有传入context,使用原生的toast组件进行提示
          ///
          DiscuzToast.failed(context: context, message: errMessage);
          return Future.value(e);
        }

        return Future.value(e);
      }));
  }

  ///
  /// automaitically refreshToken
  /// token刷新失败，如果有context则提示用户重新登录并弹出登录框
  ///
  Future<bool> _refreshToken() async {
    final String refreshToken = await AuthorizationHelper()
        .getToken(key: AuthorizationHelper.refreshTokenKey);

    /// 检测 refreshToken 不能为空，如果是空的，则返回失败并提示用户登录
    if (StringHelper.isEmpty(string: refreshToken)) {
      return Future.value(false);
    }

    /// 开始交换Token，如果token交换失败，也要提醒用户重新登录
    /// 请求时自动补全 RefreshToken
    try {
      final Dio dio = Dio()
        ..options.headers['RefreshToken'] = "Barear $refreshToken";
      Response resp = await dio.post(Urls.usersRefreshToken);

      if (resp.data['code'] == 200) {
        /// Toke 刷新成功，进行本地存储更新
        final String accessToken =
            resp.data['data']['attributes']['access_token'];
        if (StringHelper.isEmpty(string: accessToken) == true) {
          return Future.value(false);
        }
        await AuthorizationHelper()
            .clear(key: AuthorizationHelper.authorizationKey);
        await AuthorizationHelper()
            .save(data: accessToken, key: AuthorizationHelper.authorizationKey);
        return Future.value(true);
      }
    } catch (e) {
      final DioError err = e;
      print(err.response.data);
    }

    return Future.value(false);
  }

  ///
  /// pop login
  ///
  void _popLogin() {
    try {
      if (context != null) {
        // AuthHelper.staticLogin(context: context);
      }
    } catch (e) {
      debugPrint(e);
    }
  }

  ///
  /// GET 获��
  ///
  Future<Response> getUrl(
      {@required String url, dynamic queryParameters}) async {
    Response resp;
    try {
      resp = await _dio.get(url, queryParameters: queryParameters);
    } catch (e) {
      return Future.value(null);
    }

    return Future.value(resp);
  }

  ///
  /// POST JSON
  ///
  Future<Response> postJson(
      {@required String url,
      dynamic data,
      dynamic queryParameters,
      Function onReceiveProgress,
      Function onSendProgress}) async {
    Response resp;

    try {
      resp = await _dio.post(url,
          data: data,
          queryParameters: queryParameters,
          options: Options(contentType: Headers.jsonContentType),
          onReceiveProgress: onReceiveProgress,
          onSendProgress: onSendProgress);
    } catch (e) {
      return Future.value(null);
    }

    return Future.value(resp);
  }

  ///
  /// upload files
  /// MultipartFile.fromFileSync("./example/upload.txt",
  ///        filename: "upload.txt"),
  ///
  Future<Response> uploadFile(
      {@required String url,
      dynamic data,
      String name = 'file',
      MultipartFile file,
      dynamic queryParameters,
      Function onReceiveProgress,
      Function onSendProgress}) async {
    Response resp;

    final FormData formData = FormData.fromMap({name: file});

    try {
      resp = await _dio.post(url,
          data: data ?? formData,
          options: Options(contentType: _contentFormData),
          queryParameters: queryParameters,
          onReceiveProgress: onReceiveProgress,
          onSendProgress: onSendProgress);
    } catch (e) {
      print(e);
      return Future.value(null);
    }

    return Future.value(resp);
  }
}