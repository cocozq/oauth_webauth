import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:oauth_webauth/oauth_webauth.dart';

mixin BaseOAuthFlowMixin on BaseFlowMixin {
  late oauth2.AuthorizationCodeGrant authorizationCodeGrant;
  String? codeVerifier;
  bool? _enablePKCE;
  String? _tokenEndpointUrl;
  String? _authorizationEndpointUrl;
  String? _clientId;
  String? _clientSecret;
  String? _redirectUrl;
  bool _useCustomAuthUrl = false;

  /// This function will be called when user successfully authenticates.
  /// It will receive the OAuth Credentials
  ValueChanged<oauth2.Credentials>? onSuccessAuth;
  String? baseUrl;
  
  /// Custom token exchange function for non-PKCE flows
  Future<oauth2.Credentials> Function(Map<String, String>)? customTokenExchange;

  void initOAuth({
    required OAuthConfiguration configuration,
  }) {
    final redirectUrl =
        originUrl() != null ? originUrl()! : configuration.redirectUrl;
    baseUrl = configuration.baseUrl;
    onSuccessAuth = configuration.onSuccessAuth;
    customTokenExchange = configuration.customTokenExchange;
    _enablePKCE = configuration.enablePKCE ?? true;
    super.init(
      redirectUrls: baseUrl != null ? [redirectUrl, baseUrl!] : [redirectUrl],
      onSuccessRedirect: configuration.onSuccessRedirect,
      onError: configuration.onError,
      onCancel: configuration.onCancel,
    );

    if (kIsWeb) {
      codeVerifier = OAuthWebAuth.instance.restoreCodeVerifier() ??
          OAuthWebAuth.instance.generateCodeVerifier();
    }

    if (!_enablePKCE!) {
      codeVerifier = null;
    } else {
      codeVerifier ??= OAuthWebAuth.instance.generateCodeVerifier();
    }

    if (configuration.customAuthUrl != null) {
      initialUri = Uri.parse(configuration.customAuthUrl!);
      _useCustomAuthUrl = true;
    } else {
      authorizationCodeGrant = oauth2.AuthorizationCodeGrant(
        configuration.clientId,
        Uri.parse(configuration.authorizationEndpointUrl),
        Uri.parse(configuration.tokenEndpointUrl),
        secret: configuration.clientSecret,
        codeVerifier: codeVerifier,
        delimiter: configuration.delimiter,
        basicAuth: configuration.basicAuth ?? true,
        httpClient: configuration.httpClient,
      );
      initialUri = authorizationCodeGrant.getAuthorizationUrl(
        Uri.parse(redirectUrl),
        scopes: configuration.scopes,
      );
      initialUri = initialUri.replace(
          queryParameters: Map.from(initialUri.queryParameters)
            ..addAll({
              'state': const Base64Encoder.urlSafe()
                  .convert(DateTime.now().toIso8601String().codeUnits),
              'nonce': const Base64Encoder.urlSafe().convert(
                  DateTime.now().millisecondsSinceEpoch.toString().codeUnits),
              if (configuration.loginHint != null)
                'login_hint': configuration.loginHint,
              if (configuration.promptValues?.isNotEmpty ?? false)
                'prompt': configuration.promptValues!.join(' '),
            }));
    }
    
    _tokenEndpointUrl = configuration.tokenEndpointUrl;
    _authorizationEndpointUrl = configuration.authorizationEndpointUrl;
    _clientId = configuration.clientId;
    _clientSecret = configuration.clientSecret;
    _redirectUrl = redirectUrl;
  }

  @override
  void onSuccess(String responseRedirect) async {
    try {
      responseRedirect = responseRedirect.trim();
      final int ignoreStartIndex = responseRedirect.indexOf('#');
      if (ignoreStartIndex > -1) {
        responseRedirect = responseRedirect.substring(0, ignoreStartIndex);
      }
      final parameters = Uri.parse(responseRedirect).queryParameters;
      
      debugPrint("# BaseOAuthFlowMixin -> onSuccess: responseRedirect = $responseRedirect");
      debugPrint("# BaseOAuthFlowMixin -> onSuccess: parameters = $parameters");

      if (parameters.isEmpty &&
          (baseUrl?.isNotEmpty ?? false) &&
          responseRedirect.startsWith(baseUrl!)) {
        return onCancel();
      }

      if (_useCustomAuthUrl) {
        if (_tokenEndpointUrl != null && _clientId != null && _clientSecret != null && customTokenExchange != null) {
          final client = await customTokenExchange!(parameters);
          clearState();
          onSuccessAuth?.call(client);
          super.onSuccess(responseRedirect);
        } else {
          super.onSuccess(responseRedirect);
        }
      } else if (_enablePKCE!) {
        final client = await authorizationCodeGrant.handleAuthorizationResponse(parameters);
        clearState();
        onSuccessAuth?.call(client.credentials);
        super.onSuccess(responseRedirect);
      } else {
        super.onSuccess(responseRedirect);
      }
    } catch (e) {
      debugPrint("# BaseOAuthFlowMixin -> onSuccess error: $e");
      debugPrint("# BaseOAuthFlowMixin -> onSuccess error type: ${e.runtimeType}");
      onError(e);
    }
  }

  @override
  void saveState() {
    super.saveState();
    if (kIsWeb) OAuthWebAuth.instance.saveCodeVerifier(codeVerifier ?? '');
  }
}
