// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class WinUIManifestTests: XCTestCase {
    /// A fragment as the Windows App SDK's packages write one: comments among the classes, a proxy stub with its
    /// interfaces.
    private let foundation = Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <Fragment xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10">
            <Extensions>
                <Extension Category="windows.activatableClass.inProcessServer">
                  <InProcessServer>
                    <Path>Microsoft.WindowsAppRuntime.dll</Path>
                    <!-- OAuth -->
                    <ActivatableClass ActivatableClassId="Microsoft.Security.Authentication.OAuth.AuthRequestParams" ThreadingModel="both" />
                    <ActivatableClass ActivatableClassId="Microsoft.Windows.ApplicationModel.Background.BackgroundTaskBuilder" ThreadingModel="both" />
                  </InProcessServer>
                </Extension>
                <Extension Category="windows.activatableClass.proxyStub">
                  <ProxyStub ClassId="71201C0F-21E1-4B80-945F-7B0A10F90883">
                    <Path>PushNotificationsLongRunningTask.ProxyStub.dll</Path>
                    <Interface Name="IWpnForegroundSink" InterfaceId="25604D55-9B17-426F-9D67-2B11B3A65598" />
                  </ProxyStub>
                </Extension>
                <Extension Category="windows.activatableClass.proxyStub">
                  <ProxyStub ClassId="11111111-2222-3333-4444-555555555555">
                    <Path>Microsoft.Windows.Stub.dll</Path>
                    <Interface Name="IFirst" InterfaceId="AAAAAAAA-0000-0000-0000-000000000001" />
                    <Interface Name="ISecond" InterfaceId="AAAAAAAA-0000-0000-0000-000000000002" />
                  </ProxyStub>
                </Extension>
            </Extensions>
        </Fragment>
        """.utf8)

    private let winUI = Data("""
        <?xml version="1.0" encoding="utf-8"?>
        <Fragment xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10">
          <Extensions>
            <Extension Category="windows.activatableClass.inProcessServer">
              <InProcessServer>
                <Path>Microsoft.UI.Xaml.dll</Path>
                <ActivatableClass ActivatableClassId="Microsoft.UI.Xaml.Application" ThreadingModel="both" />
              </InProcessServer>
            </Extension>
          </Extensions>
        </Fragment>
        """.utf8)

    /// Every class registers in the library holding it, the components in their order; a proxy stub registers its
    /// class and interfaces, but for the two a self-contained application has no singleton for.
    func testEveryClassRegistersInItsLibrary() throws {
        let manifest = try WinUIManifest.text(fragments: [winUI, foundation])
        let lines = manifest.components(separatedBy: "\r\n")
        XCTAssertEqual(lines[0], "<?xml version='1.0' encoding='utf-8' standalone='yes'?>")
        XCTAssertEqual(Array(lines[2...14]), [
            "  <asmv3:file name='Microsoft.UI.Xaml.dll'>",
            "    <winrtv1:activatableClass name='Microsoft.UI.Xaml.Application' threadingModel='both'/>",
            "  </asmv3:file>",
            "  <asmv3:file name='Microsoft.WindowsAppRuntime.dll'>",
            "    <winrtv1:activatableClass name='Microsoft.Security.Authentication.OAuth.AuthRequestParams' threadingModel='both'/>",
            "    <winrtv1:activatableClass name='Microsoft.Windows.ApplicationModel.Background.BackgroundTaskBuilder' threadingModel='both'/>",
            "  </asmv3:file>",
            "  <asmv3:file name='Microsoft.Windows.Stub.dll'>",
            "    <asmv3:comClass clsid='{11111111-2222-3333-4444-555555555555}'/>",
            "    <asmv3:comInterfaceProxyStub name='IFirst' iid='{AAAAAAAA-0000-0000-0000-000000000001}'/>",
            "    <asmv3:comInterfaceProxyStub name='ISecond' iid='{AAAAAAAA-0000-0000-0000-000000000002}'/>",
            "  </asmv3:file>",
            "  <asmv3:application>",
        ])
        XCTAssertFalse(manifest.contains("PushNotificationsLongRunningTask"))
        XCTAssertTrue(manifest.contains("<dpiAwareness xmlns='http://schemas.microsoft.com/SMI/2016/WindowsSettings'>PerMonitorV2</dpiAwareness>"))
        XCTAssertTrue(manifest.hasSuffix("</assembly>\r\n"))
    }

    /// A fragment that is not XML is said, not written as an empty registration.
    func testAFragmentThatIsNotXMLIsRefused() {
        XCTAssertThrowsError(try WinUIManifest.text(fragments: [Data("<Fragment><Extensions>".utf8)]))
    }
}
