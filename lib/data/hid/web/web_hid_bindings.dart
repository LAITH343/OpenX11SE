import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

extension type NavigatorWithHid._(JSObject _) implements JSObject {
  external Hid? get hid;
}

Hid? get navigatorHid {
  final navigator = NavigatorWithHid._(web.window.navigator);
  return navigator.has('hid') ? navigator.hid : null;
}

extension type Hid._(JSObject _) implements web.EventTarget {
  external JSPromise<JSArray<HidDevice>> getDevices();
  external JSPromise<JSArray<HidDevice>> requestDevice(
    HidDeviceRequestOptions options,
  );
}

extension type HidDeviceRequestOptions._(JSObject _) implements JSObject {
  external factory HidDeviceRequestOptions({
    required JSArray<HidDeviceFilter> filters,
  });
}

extension type HidDeviceFilter._(JSObject _) implements JSObject {
  external factory HidDeviceFilter({
    required int vendorId,
    required int productId,
  });
}

extension type HidDevice._(JSObject _) implements web.EventTarget {
  external bool get opened;
  external int get vendorId;
  external int get productId;
  external String get productName;
  external JSArray<HidCollectionInfo> get collections;
  external JSPromise<JSAny?> open();
  external JSPromise<JSAny?> close();
  external JSPromise<JSAny?> sendFeatureReport(int reportId, JSUint8Array data);
  external JSPromise<JSDataView> receiveFeatureReport(int reportId);
}

extension type HidCollectionInfo._(JSObject _) implements JSObject {
  external int get usagePage;
  external int get usage;
  external JSArray<HidReportInfo>? get inputReports;
  external JSArray<HidReportInfo>? get featureReports;
}

extension type HidReportInfo._(JSObject _) implements JSObject {
  external int get reportId;
}

extension type HidInputReportEvent._(JSObject _) implements web.Event {
  external HidDevice get device;
  external int get reportId;
  external JSDataView get data;
}

extension type HidConnectionEvent._(JSObject _) implements web.Event {
  external HidDevice get device;
}
