#!/usr/bin/env python3
"""
Script to add continuumWidget as a proper target to the Xcode project.
Based on the WakeEarly widget target structure.
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

def find_section_end(lines, start_idx, end_marker):
    """Find the end of a section."""
    for i in range(start_idx, len(lines)):
        if end_marker in lines[i]:
            return i
    return -1

def add_widget_target(lines):
    """Add the widget extension target to the project."""
    
    # Generate UUIDs for all the objects we need to create
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
    
    print(f"Generated UUIDs:")
    for key, value in uuids.items():
        print(f"  {key}: {value}")
    
    # 1. Add PBXBuildFile section entries (at the beginning, after section start)
    idx = find_line(lines, '/* Begin PBXBuildFile section */')
    if idx >= 0:
        lines.insert(idx + 1, f"\t\t{uuids['widgetkit_buildfile']} /* WidgetKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['widgetkit_framework']} /* WidgetKit.framework */; }};\n")
        lines.insert(idx + 2, f"\t\t{uuids['swiftui_buildfile']} /* SwiftUI.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {uuids['swiftui_framework']} /* SwiftUI.framework */; }};\n")
        lines.insert(idx + 3, f"\t\t{uuids['embed_extension_buildfile']} /* continuumWidget.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {uuids['widget_appex']} /* continuumWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n")
    
    # 2. Add PBXContainerItemProxy (before End)
    idx = find_line(lines, '/* End PBXContainerItemProxy section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_dependency']} /* PBXContainerItemProxy */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXContainerItemProxy;\n")
        lines.insert(idx + 2, "\t\t\tcontainerPortal = DA112F2C2E9464AB004FF4C9 /* Project object */;\n")
        lines.insert(idx + 3, "\t\t\tproxyType = 1;\n")
        lines.insert(idx + 4, f"\t\t\tremoteGlobalIDString = {uuids['widget_target']};\n")
        lines.insert(idx + 5, "\t\t\tremoteInfo = continuumWidget;\n")
        lines.insert(idx + 6, "\t\t};\n")
    
    # 3. Add PBXCopyFilesBuildPhase section (add new section after PBXContainerItemProxy)
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
    
    # 4. Add PBXFileReference section entries (before End)
    idx = find_line(lines, '/* End PBXFileReference section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_appex']} /* continuumWidget.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = continuumWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n")
        lines.insert(idx + 1, f"\t\t{uuids['widgetkit_framework']} /* WidgetKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; }};\n")
        lines.insert(idx + 2, f"\t\t{uuids['swiftui_framework']} /* SwiftUI.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = SwiftUI.framework; path = System/Library/Frameworks/SwiftUI.framework; sourceTree = SDKROOT; }};\n")
    
    # 5. Add PBXFileSystemSynchronizedRootGroup (before End)
    idx = find_line(lines, '/* End PBXFileSystemSynchronizedRootGroup section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_filesystem_group']} /* continuumWidget */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n")
        lines.insert(idx + 2, "\t\t\tpath = continuumWidget;\n")
        lines.insert(idx + 3, "\t\t\tsourceTree = \"<group>\";\n")
        lines.insert(idx + 4, "\t\t};\n")
    
    # 6. Add Frameworks PBXFrameworksBuildPhase (before End)
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
    
    # 7. Add Frameworks group in PBXGroup section (before End)
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
    
    # 8. Add continuumWidget and Frameworks to main group children
    idx = find_line(lines, 'DA112F2B2E9464AB004FF4C9 = {')
    if idx >= 0:
        # Find the children array
        for i in range(idx, idx + 20):
            if 'children = (' in lines[i]:
                # Find the closing of children array
                for j in range(i, i + 20):
                    if ');' in lines[j]:
                        lines.insert(j, f"\t\t\t\t{uuids['widget_filesystem_group']} /* continuumWidget */,\n")
                        lines.insert(j + 1, f"\t\t\t\t{uuids['frameworks_group']} /* Frameworks */,\n")
                        break
                break
    
    # 9. Add widget.appex to Products group
    idx = find_line(lines, 'DA112F352E9464AB004FF4C9 /* Products */ = {')
    if idx >= 0:
        for i in range(idx, idx + 20):
            if ');' in lines[i] and 'children' not in lines[i]:
                lines.insert(i, f"\t\t\t\t{uuids['widget_appex']} /* continuumWidget.appex */,\n")
                break
    
    # 10. Add widget target PBXNativeTarget (before End)
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
    
    # 11. Add widget to targets list in PBXProject
    idx = find_line(lines, 'targets = (')
    if idx >= 0:
        for i in range(idx, idx + 20):
            if ');' in lines[i]:
                lines.insert(i, f"\t\t\t\t{uuids['widget_target']} /* continuumWidget */,\n")
                break
    
    # 12. Add widget to TargetAttributes
    idx = find_line(lines, 'TargetAttributes = {')
    if idx >= 0:
        for i in range(idx, idx + 50):
            if '};' in lines[i] and 'CreatedOnToolsVersion' in lines[i-1]:
                # This is the closing of TargetAttributes
                lines.insert(i, f"\t\t\t\t\t{uuids['widget_target']} = {{\n")
                lines.insert(i + 1, "\t\t\t\t\t\tCreatedOnToolsVersion = 16.4;\n")
                lines.insert(i + 2, "\t\t\t\t\t};\n")
                break
    
    # 13. Add copy files build phase to main target
    idx = find_line(lines, 'DA112F332E9464AB004FF4C9 /* continuum */ = {')
    if idx >= 0:
        # Find buildPhases
        for i in range(idx, idx + 30):
            if 'buildPhases = (' in lines[i]:
                # Find the closing
                for j in range(i, i + 10):
                    if ');' in lines[j]:
                        lines.insert(j, f"\t\t\t\t{uuids['embed_extension_phase']} /* Embed Foundation Extensions */,\n")
                        break
                break
    
    # 14. Add dependency to main target
    idx = find_line(lines, 'DA112F332E9464AB004FF4C9 /* continuum */ = {')
    if idx >= 0:
        for i in range(idx, idx + 30):
            if 'dependencies = (' in lines[i]:
                # Find the closing
                for j in range(i, i + 5):
                    if ');' in lines[j]:
                        lines.insert(j, f"\t\t\t\t{uuids['widget_target_dependency']} /* PBXTargetDependency */,\n")
                        break
                break
    
    # 15. Add PBXResourcesBuildPhase (before End)
    idx = find_line(lines, '/* End PBXResourcesBuildPhase section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_resources_phase']} /* Resources */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXResourcesBuildPhase;\n")
        lines.insert(idx + 2, "\t\t\tbuildActionMask = 2147483647;\n")
        lines.insert(idx + 3, "\t\t\tfiles = (\n")
        lines.insert(idx + 4, "\t\t\t);\n")
        lines.insert(idx + 5, "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n")
        lines.insert(idx + 6, "\t\t};\n")
    
    # 16. Add PBXSourcesBuildPhase (before End)
    idx = find_line(lines, '/* End PBXSourcesBuildPhase section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_sources_phase']} /* Sources */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXSourcesBuildPhase;\n")
        lines.insert(idx + 2, "\t\t\tbuildActionMask = 2147483647;\n")
        lines.insert(idx + 3, "\t\t\tfiles = (\n")
        lines.insert(idx + 4, "\t\t\t);\n")
        lines.insert(idx + 5, "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n")
        lines.insert(idx + 6, "\t\t};\n")
    
    # 17. Add PBXTargetDependency (before End)
    idx = find_line(lines, '/* End PBXTargetDependency section */')
    if idx >= 0:
        lines.insert(idx, f"\t\t{uuids['widget_target_dependency']} /* PBXTargetDependency */ = {{\n")
        lines.insert(idx + 1, "\t\t\tisa = PBXTargetDependency;\n")
        lines.insert(idx + 2, f"\t\t\ttarget = {uuids['widget_target']} /* continuumWidget */;\n")
        lines.insert(idx + 3, f"\t\t\ttargetProxy = {uuids['widget_dependency']} /* PBXContainerItemProxy */;\n")
        lines.insert(idx + 4, "\t\t};\n")
    
    # 18. Add build configurations (before End)
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
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
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
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
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
    
    # 19. Add build configuration list (before End)
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
    
    print("\nAdding widget extension target...")
    modified_lines = add_widget_target(lines)
    
    print("\nWriting modified project.pbxproj...")
    write_project(modified_lines)
    
    print("\n✅ Successfully added continuumWidget target!")
    print("\nNext steps:")
    print("1. Open the project in Xcode")
    print("2. Clean the build folder (Product > Clean Build Folder)")
    print("3. Build the project")
    print("4. The widget should now appear when long-pressing the app icon")

if __name__ == '__main__':
    main()
