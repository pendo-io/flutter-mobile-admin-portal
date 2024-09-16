import 'dart:io';
import 'package:pendo_sdk/pendo_sdk.dart';

enum PendoAppEnvironment { prod, staging, dev_hummus }

class PendoInstance {
  static void initPendo() {
    String? key;
    PendoSDK.setDebugMode();
    final PendoAppEnvironment env = PendoAppEnvironment.prod;

    switch (env) {
      case PendoAppEnvironment.prod:
        key = '';
        PendoFlutterPlugin.setup(key);
        break;
      case PendoAppEnvironment.staging:
        print("Environment not defined for staging");
        break;
      case PendoAppEnvironment.dev_hummus:
        final dynamic pendoOptions = {
          'environmentName': 'mobile-hummus',
          'IntegrationType': 'Observable',
          // 'DisabledPlatform' : 'Android',
          'ShouldScanFeatures' : true,
          'DebounceTimeMS' : 110,
          'PageScanTimeMS' : 350,
        };


        const key = '';

        PendoFlutterPlugin.setup(key, pendoOptions: pendoOptions);
        break;
    }

    startPendo();
  }

  static void startPendo() {
    final String visitorId = 'Max_flutter_visitor';
    final String accountId = 'Max_flutter_account';
    final dynamic visitorData = {
      'Age': 2,
      'Country': 'USA',
      'bool_check': true,
      "os": Platform.operatingSystem,
      "osVersion": Platform.operatingSystemVersion
    };
    final dynamic accountData = {'Tier': 1, 'Size': 'Enterprise'};

    PendoFlutterPlugin.startSession(visitorId, accountId, visitorData, accountData);
  }

  static void addViditorData() {
    PendoFlutterPlugin.setVisitorData({'key':'value'});
  }

  static void track() {
    // PendoFlutterPlugin.track('event', {'track': 'props'});
    PendoFlutterPlugin.track('HomePage', {'screen': 'DashboardPage', 'home_item_clicked': 'My Parcels'});
  }
}
