#!/usr/bin/env python3
"""
Final comprehensive script to add continuumWidget target with proper exception handling.
"""

import uuid

def generate_uuid():
    """Generate a unique 24-character hex ID matching Xcode's format."""
    return uuid.uuid4().hex[:24].upper()

def read_project():
    """Read the project.pbxproj file."""
    with open('/Users/ryanfrigo/dev/orion-labs/continuum/continuum.xcodeproj/project.pbxproj', 'r') as f:
        return f.readlines()

def write_project(lines):
    """Write the modified project.pbxproj file."""
    with open('/Users/ryanfrigo/dev/orion-labs/continuum/continuum.xcodeproj/project.pbxproj', 'w') as f:
        f.writelines(lines)

def find_line(lines, search_str):
    """Find the index of a line containing the search string."""
    for i, line in enumerate(lines):
        if search_str in line:
            return i
    return -1

def add_widget_target_complete(lines):
    """Add the widget extension target with all necessary components."""
    
    # Generate all UUIDs
    uuids = {
        'widget_appex': generate_uuid(),
        'widget_target': generate_uuid(),
        'widget_buildconfig_debug': generate_uuid(),
        'widget_buildconfig_release': generate_uuid(),
        'widget_buildconfig_list': generate_uuid(),
        'widget_sources_phase': generate_uuid(),
        'widget_frameworks_phase': generate_uuid(),
        'widget_resources_phase': generate_uuid(),
        'widget_filesystem_group': generate_uuid(),
        'widget_exception_set': generate_uuid(),
        'widgetkit_framework': generate_uuid(),
        'swiftui_framework': generate_uuid(),
        'frameworks_group': generate_uuid(),
        'embed_extension_phase': generate_uuid(),
        'embed_extension_buildfile': generate_uuid(),
        'widget_dependency': generate_uuid(),
        'widget_target_dependency': generate_uuid(),
        'widgetkit_buildfile': generate_uuid(),
        'swiftui_buildfile': generate_uuid(),
    }
    
    print("Generated UUIDs:")
    for key, value in uuids.items():
        print(f"  {key}: {value}")
    
    # 1. Add PBXBuildFile entries
    idx = find_line(lines, '/* Begin PBXBuildFile section */')
    if idx >= 0:
        lines.insert(idx + 1, f"\t\t{uuids['widgetkit_buildfile']} /* WidgetKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['widgetkit_framework']} /* WidgetKit.framework */; }};\n")
        lines.insert(idx + 2, f"\t\t{uuids['swiftui_buildfile']} /* SwiftUI.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['swiftui_framework']} /* SwiftUI.framework */; }};\n")
        lines.insert(idx + 3, f"\t\t{uuids['embed_extension_buildfile']} /* continuumWidget.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {uuids['widget_appex']} /* continuumWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n")
    
    # 2. Add PBXContainerItemProxy
    idx = find_line(lines, '/* End PBXContainerItemProxy section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_dependency']} /* PBXContainerItemProxy */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXContainerItemProxy;\n")
        lines.insert(idx + 2, "\t\t\tcontainerPortal = DA112F2C2E9464AB004FF4C9 /* Project object */;\n")
        lines.insert(idx + 3, "\t\t\tproxyType = 1;\n")
        lines.insert(idx + 4, f"\t\t\tremoteGlobalIDString = {uuids['widget_target']};\n")
        lines.insert(idx + 5, "\t\t\tremoteInfo = continuumWidget;\n")
        lines.insert(idx + 6, "\t\t};\n")
    
    # 3. Add PBXCopyFilesBuildPhase section
    idx = find_line(lines, '/* End PBXContainerItemProxy section */')
    if idx >= 0:
        lines.insert(idx + 1, "\n")
        lines.insert(idx + 2, "/* Begin PBXCopyFilesBuildPhase section */\n")
        lines.insert(idx + 3, f"\t\t{uuids['embed_extension_phase']} /* Embed Foundation Extensions */ = {{\n")
        lines.insert(idx + 4, "\t\t\tisa = PBXCopyFilesBuildPhase;\n")
        lines.insert(idx + 5, "\t\t\tbuildActionMask = 2147483647;\n")
        lines.insert(idx + 6, "\t\t\tdstPath = \"\";\n")
        lines.insert(idx + 7, "\t\t\tdstSubfolderSpec = 13;\n")
        lines.insert(idx + 8, "\t\t\tfiles = (\n")
        lines.insert(idx + 9, f"\t\t\t\t{uuids['embed_extension_buildfile']} /* continuumWidget.appex in Embed Foundation Extensions */,\n")
        lines.insert(idx + 10, "\t\t\t);\n")
        lines.insert(idx + 11, "\t\t\tname = \"Embed Foundation Extensions\";\n")
        lines.insert(idx + 12, "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n")
        lines.insert(idx + 13, "\t\t};\n")
        lines.insert(idx + 14, "/* End PBXCopyFilesBuildPhase section */\n")
    
    # 4. Add PBXFileReference entries
    idx = find_line(lines, '/* End PBXFileReference section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_appex']} /* continuumWidget.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = continuumWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n")
        lines.insert(idx + 1, f"\t\t{uuids['widgetkit_framework']} /* WidgetKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; }};\n")
        lines.insert(idx + 2, f"\t\t{uuids['swiftui_framework']} /* SwiftUI.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = SwiftUI.framework; path = System/Library/Frameworks/SwiftUI.framework; sourceTree = SDKROOT; }};\n")
    
    # 5. Add PBXFileSystemSynchronizedBuildFileExceptionSet section
    idx = find_line(lines, '/* End PBXFileReference section */')
    if idx >= 0:
        lines.insert(idx + 1, "\n")
        lines.insert(idx + 2, "/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */\n")
        lines.insert(idx + 3, f"\t\t{uuids['widget_exception_set']} /* Exceptions for \"continuumWidget\" */ = {{\n")
        lines.insert(idx + 4, "\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;\n")
        lines.insert(idx + 5, "\t\t\tmembershipExceptions = (\n")
        lines.insert(idx + 6, "\t\t\t\tInfo.plist,\n")
        lines.insert(idx + 7, "\t\t\t);\n")
        lines.insert(idx + 8, f"\t\t\ttarget = {uuids['widget_target']} /* continuumWidget */;\n")
        lines.insert(idx + 9, "\t\t};\n")
        lines.insert(idx + 10, "/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */\n")
    
    # 6. Add PBXFileSystemSynchronizedRootGroup
    idx = find_line(lines, '/* End PBXFileSystemSynchronizedRootGroup section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_filesystem_group']} /* continuumWidget */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n")
        lines.insert(idx + 2, "\t\t\texceptions = (\n")
        lines.insert(idx + 3, f"\t\t\t\t{uuids['widget_exception_set']},\n")
        lines.insert(idx + 4, "\t\t\t);\n")
        lines.insert(idx + 5, "\t\t\tpath = continuumWidget;\n")
        lines.insert(idx + 6, "\t\t\tsourceTree = \"<group>\";\n")
        lines.insert(idx + 7, "\t\t};\n")
    
    # 7. Add Frameworks PBXFrameworksBuildPhase
    idx = find_line(lines, '/* End PBXFrameworksBuildPhase section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_frameworks_phase']} /* Frameworks */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXFrameworksBuildPhase;\n")
        lines.insert(idx + 2, "\t\t\tbuildActionMask = 2147483647;\n")
        lines.insert(idx + 3, "\t\t\tfiles = (\n")
        lines.insert(idx + 4, f"\t\t\t\t{uuids['swiftui_buildfile']} /* SwiftUI.framework in Frameworks */,\n")
        lines.insert(idx + 5, f"\t\t\t\t{uuids['widgetkit_buildfile']} /* WidgetKit.framework in Frameworks */,\n")
        lines.insert(idx + 6, "\t\t\t);\n")
        lines.insert(idx + 7, "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n")
        lines.insert(idx + 8, "\t\t};\n")
    
    # 8. Add Frameworks group
    idx = find_line(lines, '/* End PBXGroup section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['frameworks_group']} /* Frameworks */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXGroup;\n")
        lines.insert(idx + 2, "\t\t\tchildren = (\n")
        lines.insert(idx + 3, f"\t\t\t\t{uuids['widgetkit_framework']} /* WidgetKit.framework */,\n")
        lines.insert(idx + 4, f"\t\t\t\t{uuids['swiftui_framework']} /* SwiftUI.framework */,\n")
        lines.insert(idx + 5, "\t\t\t);\n")
        lines.insert(idx + 6, "\t\t\tname = Frameworks;\n")
        lines.insert(idx + 7, "\t\t\tsourceTree = \"<group>\";\n")
        lines.insert(idx + 8, "\t\t};\n")
    
    # 9. Add to main group children
    idx = find_line(lines, 'DA112F2B2E9464AB004FF4C9 = {')
    if idx >= 0:
        for i in range(idx, idx + 20):
            if 'children = (' in lines[i]:
                for j in range(i, i + 20):
                    if ');' in lines[j]:
                        lines.insert(j, f"\t\t\t\t{uuids['widget_filesystem_group']} /* continuumWidget */,\n")
                        lines.insert(j + 1, f"\t\t\t\t{uuids['frameworks_group']} /* Frameworks */,\n")
                        break
                break
    
    # 10. Add to Products group
    idx = find_line(lines, 'DA112F352E9464AB004FF4C9 /* Products */ = {')
    if idx >= 0:
        for i in range(idx, idx + 20):
            if ');' in lines[i] and 'children' not in lines[i]:
                lines.insert(i, f"\t\t\t\t{uuids['widget_appex']} /* continuumWidget.appex */,\n")
                break
    
    # 11. Add widget target
    idx = find_line(lines, '/* End PBXNativeTarget section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_target']} /* continuumWidget */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXNativeTarget;\n")
        lines.insert(idx + 2, f"\t\t\tbuildConfigurationList = {uuids['widget_buildconfig_list']} /* Build configuration list for PBXNativeTarget \"continuumWidget\" */;\n")
        lines.insert(idx + 3, "\t\t\tbuildPhases = (\n")
        lines.insert(idx + 4, f"\t\t\t\t{uuids['widget_sources_phase']} /* Sources */,\n")
        lines.insert(idx + 5, f"\t\t\t\t{uuids['widget_frameworks_phase']} /* Frameworks */,\n")
        lines.insert(idx + 6, f"\t\t\t\t{uuids['widget_resources_phase']} /* Resources */,\n")
        lines.insert(idx + 7, "\t\t\t);\n")
        lines.insert(idx + 8, "\t\t\tbuildRules = (\n")
        lines.insert(idx + 9, "\t\t\t);\n")
        lines.insert(idx + 10, "\t\t\tdependencies = (\n")
        lines.insert(idx + 11, "\t\t\t);\n")
        lines.insert(idx + 12, "\t\t\tfileSystemSynchronizedGroups = (\n")
        lines.insert(idx + 13, f"\t\t\t\t{uuids['widget_filesystem_group']} /* continuumWidget */,\n")
        lines.insert(idx + 14, "\t\t\t);\n")
        lines.insert(idx + 15, "\t\t\tname = continuumWidget;\n")
        lines.insert(idx + 16, "\t\t\tpackageProductDependencies = (\n")
        lines.insert(idx + 17, "\t\t\t);\n")
        lines.insert(idx + 18, "\t\t\tproductName = continuumWidget;\n")
        lines.insert(idx + 19, f"\t\t\tproductReference = {uuids['widget_appex']} /* continuumWidget.appex */;\n")
        lines.insert(idx + 20, "\t\t\tproductType = \"com.apple.product-type.app-extension\";\n")
        lines.insert(idx + 21, "\t\t};\n")
    
    # 12. Add to targets list
    idx = find_line(lines, 'targets = (')
    if idx >= 0:
        for i in range(idx, idx + 20):
            if ');' in lines[i]:
                lines.insert(i, f"\t\t\t\t{uuids['widget_target']} /* continuumWidget */,\n")
                break
    
    # 13. Add to TargetAttributes
    idx = find_line(lines, 'TargetAttributes = {')
    if idx >= 0:
        for i in range(idx, idx + 50):
            if '};' in lines[i] and 'CreatedOnToolsVersion' in lines[i-1]:
                lines.insert(i, f"\t\t\t\t\t{uuids['widget_target']} = {{\n")
                lines.insert(i + 1, "\t\t\t\t\t\tCreatedOnToolsVersion = 16.4;\n")
                lines.insert(i + 2, "\t\t\t\t\t};\n")
                break
    
    # 14. Add to main target buildPhases and dependencies
    idx = find_line(lines, 'DA112F332E9464AB004FF4C9 /* continuum */ = {')
    if idx >= 0:
        for i in range(idx, idx + 30):
            if 'buildPhases = (' in lines[i]:
                for j in range(i, i + 10):
                    if ');' in lines[j]:
                        lines.insert(j, f"\t\t\t\t{uuids['embed_extension_phase']} /* Embed Foundation Extensions */,\n")
                        break
                break
        
        for i in range(idx, idx + 30):
            if 'dependencies = (' in lines[i]:
                for j in range(i, i + 5):
                    if ');' in lines[j]:
                        lines.insert(j, f"\t\t\t\t{uuids['widget_target_dependency']} /* PBXTargetDependency */,\n")
                        break
                break
    
    # 15. Add PBXResourcesBuildPhase
    idx = find_line(lines, '/* End PBXResourcesBuildPhase section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_resources_phase']} /* Resources */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXResourcesBuildPhase;\n")
        lines.insert(idx + 2, "\t\t\tbuildActionMask = 2147483647;\n")
        lines.insert(idx + 3, "\t\t\tfiles = (\n")
        lines.insert(idx + 4, "\t\t\t);\n")
        lines.insert(idx + 5, "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n")
        lines.insert(idx + 6, "\t\t};\n")
    
    # 16. Add PBXSourcesBuildPhase
    idx = find_line(lines, '/* End PBXSourcesBuildPhase section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_sources_phase']} /* Sources */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXSourcesBuildPhase;\n")
        lines.insert(idx + 2, "\t\t\tbuildActionMask = 2147483647;\n")
        lines.insert(idx + 3, "\t\t\tfiles = (\n")
        lines.insert(idx + 4, "\t\t\t);\n")
        lines.insert(idx + 5, "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n")
        lines.insert(idx + 6, "\t\t};\n")
    
    # 17. Add PBXTargetDependency
    idx = find_line(lines, '/* End PBXTargetDependency section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_target_dependency']} /* PBXTargetDependency */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXTargetDependency;\n")
        lines.insert(idx + 2, f"\t\t\ttarget = {uuids['widget_target']} /* continuumWidget */;\n")
        lines.insert(idx + 3, f"\t\t\ttargetProxy = {uuids['widget_dependency']} /* PBXContainerItemProxy */;\n")
        lines.insert(idx + 4, "\t\t};\n")
    
    # 18. Add build configurations
    idx = find_line(lines, '/* End XCBuildConfiguration section */')
    if idx >= 0:
        debug_config = f'''\t\t{uuids['widget_buildconfig_debug']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = continuumWidget/continuumWidget.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 2;
\t\t\t\tDEVELOPMENT_TEAM = NVN2NY8GZC;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = continuumWidget/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Continuum Widget";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 3.2;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "orion-labs.continuum.continuumWidget";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tREGISTER_APP_GROUPS = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
'''
        release_config = f'''\t\t{uuids['widget_buildconfig_release']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = continuumWidget/continuumWidget.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 2;
\t\t\t\tDEVELOPMENT_TEAM = NVN2NY8GZC;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = continuumWidget/Info.plist;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Continuum Widget";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 3.2;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "orion-labs.continuum.continuumWidget";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tREGISTER_APP_GROUPS = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
'''
        lines.insert(idx, debug_config)
        lines.insert(idx + 1, release_config)
    
    # 19. Add build configuration list
    idx = find_line(lines, '/* End XCConfigurationList section */')
    if idx >= 0:
        config_list = f'''\t\t{uuids['widget_buildconfig_list']} /* Build configuration list for PBXNativeTarget "continuumWidget" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{uuids['widget_buildconfig_debug']} /* Debug */,
\t\t\t\t{uuids['widget_buildconfig_release']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
'''
        lines.insert(idx, config_list)
    
    return lines

def main():
    """Main function."""
    print("Reading project.pbxproj...")
    lines = read_project()
    
    print("\nAdding widget extension target with proper exception handling...")
    modified_lines = add_widget_target_complete(lines)
    
    print("\nWriting modified project.pbxproj...")
    write_project(modified_lines)
    
    print("\n✅ Successfully added continuumWidget target with proper Info.plist handling!")
    print("\nNext steps:")
    print("1. Open the project in Xcode")
    print("2. Build the project")
    print("3. The widget should appear when long-pressing the app icon")

if __name__ == '__main__':
    main()
