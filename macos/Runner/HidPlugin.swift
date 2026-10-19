import Cocoa
import FlutterMacOS
import IOKit.hid

private func ioError(_ code: UInt32) -> IOReturn {
  IOReturn(bitPattern: 0xE000_0000 | code)
}

private let disconnectedCodes: Set<IOReturn> = [
  ioError(0x2C0),
  ioError(0x2CD),
  ioError(0x2D7),
  ioError(0x2D9),
  ioError(0x2EB),
]

private let notPermitted = ioError(0x2E2)

private final class HidHandle {
  let id: Int
  let device: IOHIDDevice
  weak var plugin: HidPlugin?
  var buffer: UnsafeMutablePointer<UInt8>?
  var bufferLength = 0
  var removed = false

  init(id: Int, device: IOHIDDevice, plugin: HidPlugin) {
    self.id = id
    self.device = device
    self.plugin = plugin
  }

  var context: UnsafeMutableRawPointer {
    Unmanaged.passUnretained(self).toOpaque()
  }

  static func from(_ context: UnsafeMutableRawPointer?) -> HidHandle? {
    guard let context else { return nil }
    return Unmanaged<HidHandle>.fromOpaque(context).takeUnretainedValue()
  }
}

final class HidPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let vendorId = 0x1D57

  private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
  private let queue = DispatchQueue(label: "openx11se.hid")
  private var devices: [String: IOHIDDevice] = [:]
  private var handles: [Int: HidHandle] = [:]
  private var nextHandle = 1
  private var sink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = HidPlugin()
    let methods = FlutterMethodChannel(name: "openx11se/hid", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: "openx11se/hid/events", binaryMessenger: registrar.messenger)
    events.setStreamHandler(instance)
  }

  override init() {
    super.init()
    IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: Self.vendorId] as CFDictionary)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "enumerate":
      result(enumerate())
    case "open":
      open(args["id"] as? String, result: result)
    case "listen":
      listen(handle(args), length: args["length"] as? Int ?? 0, result: result)
    case "setFeature":
      setFeature(handle(args), data: args["data"] as? FlutterStandardTypedData, result: result)
    case "getFeature":
      getFeature(
        handle(args),
        reportId: args["reportId"] as? Int ?? 0,
        length: args["length"] as? Int ?? 0,
        result: result
      )
    case "close":
      close(handle(args), result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handle(_ args: [String: Any]) -> HidHandle? {
    guard let id = args["handle"] as? Int else { return nil }
    return handles[id]
  }

  private func enumerate() -> [[String: Any]] {
    let found = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
    var next: [String: IOHIDDevice] = [:]
    var list: [[String: Any]] = []
    for device in found {
      var entryId: UInt64 = 0
      guard IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &entryId) == KERN_SUCCESS
      else { continue }
      let id = String(entryId)
      next[id] = device
      let pairs = property(device, kIOHIDDeviceUsagePairsKey) as? [[String: Any]] ?? []
      var usages: [[Int]] = pairs.compactMap { pair in
        guard let page = pair[kIOHIDDeviceUsagePageKey] as? Int,
          let usage = pair[kIOHIDDeviceUsageKey] as? Int
        else { return nil }
        return [page, usage]
      }
      if usages.isEmpty {
        usages = [[intProperty(device, kIOHIDPrimaryUsagePageKey), intProperty(device, kIOHIDPrimaryUsageKey)]]
      }
      list.append([
        "id": id,
        "vendorId": intProperty(device, kIOHIDVendorIDKey),
        "productId": intProperty(device, kIOHIDProductIDKey),
        "locationId": intProperty(device, kIOHIDLocationIDKey),
        "product": property(device, kIOHIDProductKey) as? String ?? NSNull(),
        "usages": usages,
        "featureLength": intProperty(device, kIOHIDMaxFeatureReportSizeKey),
        "inputLength": intProperty(device, kIOHIDMaxInputReportSizeKey),
      ])
    }
    devices = next
    return list
  }

  private func property(_ device: IOHIDDevice, _ key: String) -> Any? {
    IOHIDDeviceGetProperty(device, key as CFString)
  }

  private func intProperty(_ device: IOHIDDevice, _ key: String) -> Int {
    (property(device, key) as? NSNumber)?.intValue ?? 0
  }

  private func open(_ id: String?, result: @escaping FlutterResult) {
    guard let id, let device = devices[id] else {
      result(FlutterError(code: "disconnected", message: "Device not found", details: nil))
      return
    }
    let status = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    if status == notPermitted {
      if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
      }
      result(FlutterError(code: "permission", message: "Input Monitoring access is required", details: nil))
      return
    }
    guard status == kIOReturnSuccess else {
      result(failure("IOHIDDeviceOpen", status))
      return
    }
    let entry = HidHandle(id: nextHandle, device: device, plugin: self)
    nextHandle += 1
    handles[entry.id] = entry
    IOHIDDeviceRegisterRemovalCallback(device, { context, _, _ in
      guard let entry = HidHandle.from(context) else { return }
      entry.removed = true
      entry.plugin?.send(["handle": entry.id, "event": "removed"])
    }, entry.context)
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    result(entry.id)
  }

  private func listen(_ entry: HidHandle?, length: Int, result: @escaping FlutterResult) {
    guard let entry, !entry.removed else {
      result(FlutterError(code: "disconnected", message: "Device closed", details: nil))
      return
    }
    guard length > 0, entry.buffer == nil else {
      result(nil)
      return
    }
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
    entry.buffer = buffer
    entry.bufferLength = length
    IOHIDDeviceRegisterInputReportCallback(entry.device, buffer, length, { context, _, _, _, _, report, count in
      guard let entry = HidHandle.from(context) else { return }
      let data = Data(bytes: report, count: count)
      entry.plugin?.send([
        "handle": entry.id,
        "event": "report",
        "data": FlutterStandardTypedData(bytes: data),
      ])
    }, entry.context)
    result(nil)
  }

  private func setFeature(_ entry: HidHandle?, data: FlutterStandardTypedData?, result: @escaping FlutterResult) {
    guard let entry, !entry.removed else {
      result(FlutterError(code: "disconnected", message: "Device closed", details: nil))
      return
    }
    guard let bytes = data?.data, !bytes.isEmpty else {
      result(FlutterError(code: "failed", message: "Empty report", details: nil))
      return
    }
    let device = entry.device
    queue.async {
      let reportId = Int(bytes[bytes.startIndex])
      let payload = reportId == 0 ? bytes.dropFirst() : bytes
      let status = payload.withUnsafeBytes { raw -> IOReturn in
        guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return kIOReturnSuccess }
        return IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(reportId), base, raw.count)
      }
      DispatchQueue.main.async {
        result(status == kIOReturnSuccess ? nil : self.failure("IOHIDDeviceSetReport", status))
      }
    }
  }

  private func getFeature(_ entry: HidHandle?, reportId: Int, length: Int, result: @escaping FlutterResult) {
    guard let entry, !entry.removed else {
      result(FlutterError(code: "disconnected", message: "Device closed", details: nil))
      return
    }
    guard length > 0 else {
      result(FlutterError(code: "failed", message: "Invalid length", details: nil))
      return
    }
    let device = entry.device
    queue.async {
      var buffer = [UInt8](repeating: 0, count: length)
      buffer[0] = UInt8(truncatingIfNeeded: reportId)
      let offset = reportId == 0 ? 1 : 0
      var size = CFIndex(length - offset)
      let status = buffer.withUnsafeMutableBufferPointer { raw -> IOReturn in
        guard size > 0, let base = raw.baseAddress else { return kIOReturnSuccess }
        return IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(reportId), base + offset, &size)
      }
      DispatchQueue.main.async {
        if status == kIOReturnSuccess {
          result(FlutterStandardTypedData(bytes: Data(buffer)))
        } else {
          result(self.failure("IOHIDDeviceGetReport", status))
        }
      }
    }
  }

  private func close(_ entry: HidHandle?, result: @escaping FlutterResult) {
    guard let entry, handles.removeValue(forKey: entry.id) != nil else {
      result(nil)
      return
    }
    let device = entry.device
    IOHIDDeviceRegisterRemovalCallback(device, nil, nil)
    if entry.buffer != nil {
      IOHIDDeviceRegisterInputReportCallback(device, entry.buffer!, entry.bufferLength, nil, nil)
    }
    IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    queue.async {
      IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
      DispatchQueue.main.async {
        entry.buffer?.deallocate()
        entry.buffer = nil
        result(nil)
      }
    }
  }

  private func send(_ event: [String: Any]) {
    sink?(event)
  }

  private func failure(_ operation: String, _ status: IOReturn) -> FlutterError {
    let code = disconnectedCodes.contains(status) ? "disconnected" : "failed"
    let hex = String(UInt32(bitPattern: status), radix: 16)
    return FlutterError(code: code, message: "\(operation) failed (0x\(hex))", details: nil)
  }
}
