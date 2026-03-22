import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oauth2/oauth2.dart';
import 'package:oauth_webauth/oauth_webauth.dart';
import 'package:oauth_webauth/src/utils/custom_pop_scope.dart';

class OAuthWebScreen extends StatelessWidget {
  static OAuthWebScreen? oAuthWebScreen;
  static Future? start({
    Key? key,
    GlobalKey<OAuthWebViewState>? globalKey,
    required BuildContext context,
    required OAuthConfiguration configuration,
  }) {
    assert(
        !kIsWeb ||
            (kIsWeb &&
                configuration.onSuccessAuth != null &&
                configuration.onError != null &&
                configuration.onCancel != null),
        'You must set onSuccessAuth, onError and onCancel function when running on Web otherwise you will not get any result.');
    if (kIsWeb) {
      final oauthFlow = BaseOAuthFlow()
        ..initOAuth(
          configuration: configuration,
        );
      oauthFlow.onNavigateTo(OAuthWebAuth.instance.appBaseUrl);
      return null;
    }
    
    if (configuration.enablePKCE == false) {
      final completer = Completer<String?>();
      final configWithRedirect = configuration.copyWith(
        onSuccessRedirect: (url) {
          debugPrint("# OAuthWebScreen -> onSuccessRedirect: $url");
          if (!completer.isCompleted) {
            completer.complete(url);
            Navigator.of(context).pop();
          }
        },
        onError: (error) {
          debugPrint("# OAuthWebScreen -> onError: $error");
          if (!completer.isCompleted) {
            completer.complete(null);
            Navigator.of(context).pop();
          }
        },
        onCancel: () {
          debugPrint("# OAuthWebScreen -> onCancel");
          if (!completer.isCompleted) {
            completer.complete(null);
            Navigator.of(context).pop();
          }
        },
      );
      
      oAuthWebScreen = OAuthWebScreen(
        key: key,
        globalKey: globalKey,
        configuration: configWithRedirect,
      );
      
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => oAuthWebScreen!));
      
      return completer.future;
    }
    
    oAuthWebScreen = OAuthWebScreen(
      key: key,
      globalKey: globalKey,
      configuration: configuration,
    );
    return Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => oAuthWebScreen!));
  }

  late final BuildContext context;
  final GlobalKey<OAuthWebViewState> globalKey;
  final OAuthConfiguration configuration;

  OAuthWebScreen({
    super.key,
    GlobalKey<OAuthWebViewState>? globalKey,
    required this.configuration,
  }) : globalKey = globalKey ?? GlobalKey<OAuthWebViewState>();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        this.context = context;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            left: false,
            right: false,
            child: CustomPopScope(
              canGoBack: onBackPressed,
              child: OAuthWebView(
                key: globalKey,
                configuration: configuration.copyWith(
                  onSuccessAuth: _onSuccess,
                  onError: _onError,
                  onCancel: _onCancel,
                  onSuccessRedirect: configuration.onSuccessRedirect,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSuccess(Credentials credentials) {
    if (configuration.enablePKCE ?? true) {
      Navigator.pop(context, credentials);
    }
    configuration.onSuccessAuth?.call(credentials);
  }

  void _onSuccessRedirect(String redirectUrl) {
    configuration.onSuccessRedirect?.call(redirectUrl);
  }

  void _onError(dynamic error) {
    Navigator.pop(context, error);
    configuration.onError?.call(error);
  }

  void _onCancel() {
    Navigator.pop(context);
    configuration.onCancel?.call();
  }

  Future<bool> onBackPressed() async {
    if (!((await globalKey.currentState?.onBackPressed()) ?? false)) {
      return false;
    }
    configuration.onCancel?.call();
    return true;
  }
}
